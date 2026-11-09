extends Node3D
## The drive: builds the island, the car and the UI.

const MENU := "res://scenes/menu.tscn"
var spec: Dictionary
var terrain: Terrain
var feats: Collectibles
var car: Car
var cam: ChaseCamera
var day: DayCycle
var hud: Hud
var pause: PauseMenu
var sun: DirectionalLight3D
var grain: ColorRect
var engine: EngineSound

var _built := false
var _lights_hint := false
var _remotes: Dictionary = {}  ## peer id -> RemoteCar
var _net_tick := 0
var _time_send := 0.0
var _odo_last := 0.0
var _save_t := 0.0
# Test mode
var _shot_t := 0.0
var _shot_times: Array = [3.0, 10.0, 20.0]  # extended with --long
var _shot_targets: Array = []
var _stat_t := 0.0
var _fps_sum := 0.0
var _fps_n := 0


func _ready() -> void:
	spec = CarSpecs.get_spec(GameState.car_id)
	var loading := _loading_layer()
	await get_tree().process_frame
	await get_tree().process_frame
	var t0 := Time.get_ticks_msec()
	_build()
	print("[lowgear] world built in %d ms" % (Time.get_ticks_msec() - t0))
	loading.queue_free()
	_built = true


func _build() -> void:
	var we := WorldEnvironment.new()
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = bool(GameState.settings["shadows"])
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)
	day = DayCycle.new()
	add_child(day)
	day.setup(we, sun, float(GameState.shot_args.get("tod", 0.34)))

	var q := GameState.quality()
	terrain = Terrain.new()
	add_child(terrain)
	terrain.generate_heights()
	feats = Collectibles.new()
	add_child(feats)
	feats.build(terrain, terrain.spawn_transform)
	terrain.add_tracks(feats.avoid_points())
	terrain.build(q)
	_add_water()
	var props := Props.new()
	add_child(props)
	props.build(terrain, feats.avoid_points() + [terrain.spawn_transform.origin], q)

	car = CarBuilder.build_vehicle(spec, GameState.garage_for(GameState.car_id))
	car.terrain = terrain
	var tracks := TyreTracks.new()
	add_child(tracks)
	car.tracks = tracks
	car.anchors = func() -> Array:
		return props.anchors + feats.anchors
	add_child(car)
	# In multiplayer each player starts a few metres to the side of the others.
	var spawn := terrain.spawn_transform
	if Net.active:
		spawn.origin += spawn.basis.x * (Net.my_slot() * 5.0)
		spawn.origin.y = terrain.get_height(spawn.origin.x, spawn.origin.z) + 1.2
	car.global_transform = spawn
	car.setup_wheels()

	cam = ChaseCamera.new()
	cam.target = car
	cam.terrain = terrain
	add_child(cam)
	cam.current = true
	cam.snap()
	cam.far = [500.0, 700.0, 900.0][q]
	var grass := GrassField.new()
	add_child(grass)
	grass.setup(terrain, cam, q)
	day.env.fog_density = [0.0045, 0.003, 0.0024][q]
	sun.directional_shadow_max_distance = [0.0, 55.0, 90.0][q]
	sun.shadow_enabled = sun.shadow_enabled and q > 0

	hud = Hud.new()
	hud.car = car
	hud.feats = feats
	hud.cam = cam
	add_child(hud)
	pause = PauseMenu.new()
	add_child(pause)
	pause.change_car.connect(_to_menu)
	grain = _grain_layer()
	if TouchControls.wanted():
		add_child(TouchControls.new())
	engine = EngineSound.new()
	add_child(engine)
	engine.setup(car)

	feats.refuelling.connect(func(r: float) -> void:
		if r < 0.995:
			hud.toast("Refuelling and repairing  %d%%" % int(r * 100.0))
		else:
			hud.toast("Fuelled up and repaired"))
	feats.coin_collected.connect(func(_n: int) -> void: Sfx.play("coin", 0.7))
	feats.trail_completed.connect(func() -> void:
		Sfx.play("trail")
		hud.toast("Coin trail complete"))
	feats.discovered.connect(func(n: String, c: int) -> void:
		Sfx.play("discover")
		hud.toast("Discovered: %s   (%d / %d)" % [n, c, feats.landmarks.size()])
		if Net.active:
			Net.announce("%s found the %s" % [GameState.settings["name"], n]))
	car.message.connect(func(t: String) -> void: hud.toast(t))
	car.was_reset.connect(func() -> void:
		Sfx.play("reset", 0.6)
		hud.flash())
	GameState.settings_changed.connect(_apply_settings)
	Net.announced.connect(func(t: String) -> void:
		if not t.begins_with(str(GameState.settings["name"]) + " found"):
			hud.toast(t))
	Net.car_state.connect(_on_car_state)
	Net.roster_changed.connect(_sync_remotes)
	Net.time_synced.connect(func(t: float) -> void:
		if absf(wrapf(t - day.t, -0.5, 0.5)) > 0.002:
			day.t = t)
	_sync_remotes()
	if GameState.shot_mode:
		_setup_shot()


func _add_water() -> void:
	var water := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(5000, 5000)
	water.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/water.gdshader")
	m.set_shader_parameter("heights", terrain.height_texture())
	m.set_shader_parameter("map_half", Terrain.HALF)
	water.material_override = m
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


func _grain_layer() -> ColorRect:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/grade.gdshader")
	r.material = m
	r.visible = bool(GameState.settings["grain"])
	layer.add_child(r)
	return r


func _loading_layer() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("#fde2e4")
	layer.add_child(bg)
	var l := Label.new()
	l.text = "growing the hills..."
	l.label_settings = GameState.label_settings(40, true)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	layer.add_child(l)
	return layer


func _apply_settings() -> void:
	sun.shadow_enabled = bool(GameState.settings["shadows"])
	grain.visible = bool(GameState.settings["grain"])


func _process(delta: float) -> void:
	if not _built:
		return
	car.set_night(day.darkness)
	if day.darkness > 0.6 and car.lights_mode == 0 and not _lights_hint:
		_lights_hint = true
		hud.toast("Getting dark: press F (or the lamp button) for headlights")
	var d := car.trip - _odo_last
	if d > 0.0:
		GameState.add_distance(str(spec["id"]), d)
		_odo_last = car.trip
	_save_t += delta
	if _save_t > 15.0:
		_save_t = 0.0
		GameState.save_game()
	if GameState.shot_mode:
		_shot_tick(delta)


func _physics_process(delta: float) -> void:
	if not _built or not Net.active:
		return
	_net_tick += 1
	if _net_tick % 3 == 0:
		Net.send_state(car.net_state())
	_time_send += delta
	if _time_send > 5.0:
		_time_send = 0.0
		Net.send_time(day.t)


func _sync_remotes() -> void:
	for id in _remotes.keys():
		if not Net.players.has(id):
			(_remotes[id] as Node).queue_free()
			_remotes.erase(id)
	for id in Net.players:
		if id == Net.my_id() or _remotes.has(id):
			continue
		var rc := RemoteCar.new()
		rc.setup(id, Net.players[id], Net.player_color(id))
		add_child(rc)
		_remotes[id] = rc


func _on_car_state(id: int, data: Array) -> void:
	if _remotes.has(id):
		(_remotes[id] as RemoteCar).push(data)


func _to_menu() -> void:
	get_tree().paused = false
	GameState.ui_open = false
	Net.leave()
	GameState.save_game()
	get_tree().change_scene_to_file(MENU)


# --- test mode: autopilot + screenshots + stats ---------------------------------

func _setup_shot() -> void:
	car.autopilot = true
	car.awd_on = true
	car._apply_traction()
	if str(GameState.shot_args.get("scenario", "")) == "mud" and terrain.mud_pit != Vector3.INF:
		# Line up 14 m before the mud pit, pointing through it.
		var pts: PackedVector3Array = terrain.tracks[0]
		var k := int(pts.size() * 0.35)
		var dir := (pts[mini(k + 3, pts.size() - 1)] - pts[maxi(k - 3, 0)])
		dir.y = 0.0
		dir = dir.normalized()
		var start := terrain.mud_pit - dir * 14.0
		start.y = terrain.get_height(start.x, start.z) + 1.0 + float(car.spec["wheel"]["y"])
		car.global_transform = Transform3D(Basis.looking_at(-dir, Vector3.UP), start)
		_shot_targets = [terrain.mud_pit + dir * 40.0]
		car.auto_target = _shot_targets[0]
		print("[shot] mud scenario at ", terrain.mud_pit)
		return
	var sp := car.global_position
	var lms: Array = feats.landmarks.duplicate()
	lms.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["pos"] as Vector3).distance_to(sp) < (b["pos"] as Vector3).distance_to(sp))
	for l in lms:
		_shot_targets.append(l["pos"])
	if _shot_targets.is_empty():
		_shot_targets.append(Vector3.ZERO)
	car.auto_target = _shot_targets[0]
	print("[shot] car=%s spawn=%s landmarks=%d coins=%d" % [spec["id"], sp, feats.landmarks.size(), feats.total_coins])


func _remote_summary() -> String:
	var parts: Array = []
	for id in _remotes:
		var rc: RemoteCar = _remotes[id]
		parts.append("%d@%.0fm" % [id, rc.global_position.distance_to(car.global_position)])
	return ", ".join(parts)


func _shot_tick(delta: float) -> void:
	_shot_t += delta
	_fps_sum += Engine.get_frames_per_second()
	_fps_n += 1
	if _shot_targets.size() > 1 and car.global_position.distance_to(_shot_targets[0]) < 18.0:
		_shot_targets.pop_front()
		car.auto_target = _shot_targets[0]
	_stat_t += delta
	if _stat_t >= 2.0:
		_stat_t = 0.0
		print("[shot] sink=%.2f surface=%d fuel=%.1f awd=%s diff=%s winch=%s" % [car.sink, car.surface, car.fuel, car.awd_on, car.diff_locked, car.winch_anchor != Vector3.INF])
		print("[shot] t=%.0f gear=%s low=%s rpm=%.0f fps=%d kmh=%.0f fwd=%.1f pos=(%.0f, %.0f, %.0f) up=%.2f trip=%.0f resets=%d ground=%s" % [
			_shot_t, car.gear_text(), car.low_range, car.engine_rpm, Engine.get_frames_per_second(), car.linear_velocity.length() * 3.6, car.fwd_speed,
			car.global_position.x, car.global_position.y, car.global_position.z,
			car.global_transform.basis.y.y, car.trip, car.resets, car.grounded])
		print("[perf] process=%.1fms physics=%.1fms draws=%d prims=%dk objects=%d" % [
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
	if GameState.shot_args.has("pause") and _shot_t > 2.0 and not pause.visible:
		pause.visible = true
		pause._scroll.custom_minimum_size.y = clampf(get_viewport().get_visible_rect().size.y - 140.0, 240.0, 600.0)
	if not _shot_times.is_empty() and _shot_t >= float(_shot_times[0]):
		GameState.screenshot("%s_%02d.png" % [spec["id"], int(_shot_times[0])])
		_shot_times.pop_front()
	if _shot_times.is_empty():
		print("[shot] net=%s players=%d remotes=%s" % [Net.active, Net.players.size(), _remote_summary()])
		print("[shot] done car=%s avg_fps=%.1f trip=%.0f resets=%d coins=%d found=%d" % [
			spec["id"], _fps_sum / maxf(_fps_n, 1), car.trip, car.resets, GameState.coins.size(), feats.found_count()])
		get_tree().quit()
