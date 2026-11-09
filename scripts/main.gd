extends Node3D
## The drive: builds the island, the car and the UI.

const MENU := "res://scenes/menu.tscn"
const GRAIN_SHADER := """
shader_type canvas_item;
uniform float grain = 0.045;
uniform float vignette = 0.32;
float rnd(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	float n = rnd(floor(FRAGCOORD.xy * 0.5) + fract(TIME * 7.0) * 113.0);
	float d = distance(UV, vec2(0.5));
	float v = smoothstep(0.42, 0.9, d) * vignette;
	float a = grain + v;
	vec3 col = mix(vec3(n), vec3(0.22, 0.16, 0.32), v / max(a, 0.001));
	COLOR = vec4(col, a);
}
"""

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
var _odo_last := 0.0
var _save_t := 0.0
# Test mode
var _shot_t := 0.0
var _shot_times: Array = [3.0, 10.0, 20.0]
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

	terrain = Terrain.new()
	add_child(terrain)
	terrain.generate()
	_add_water()
	feats = Collectibles.new()
	add_child(feats)
	feats.build(terrain, terrain.spawn_transform)
	var props := Props.new()
	add_child(props)
	props.build(terrain, feats.avoid_points() + [terrain.spawn_transform.origin])

	car = CarBuilder.build_vehicle(spec)
	car.terrain = terrain
	add_child(car)
	car.global_transform = terrain.spawn_transform
	car.setup_wheels()

	cam = ChaseCamera.new()
	cam.target = car
	cam.terrain = terrain
	add_child(cam)
	cam.current = true
	cam.snap()

	hud = Hud.new()
	hud.car = car
	hud.feats = feats
	hud.cam = cam
	add_child(hud)
	pause = PauseMenu.new()
	add_child(pause)
	pause.change_car.connect(_to_menu)
	grain = _grain_layer()
	engine = EngineSound.new()
	add_child(engine)
	engine.setup(car)

	feats.coin_collected.connect(func(_n: int) -> void: Sfx.play("coin", 0.7))
	feats.trail_completed.connect(func() -> void:
		Sfx.play("trail")
		hud.toast("Coin trail complete"))
	feats.discovered.connect(func(n: String, c: int) -> void:
		Sfx.play("discover")
		hud.toast("Discovered: %s   (%d / %d)" % [n, c, feats.landmarks.size()]))
	car.message.connect(func(t: String) -> void: hud.toast(t))
	car.was_reset.connect(func() -> void:
		Sfx.play("reset", 0.6)
		hud.flash())
	GameState.settings_changed.connect(_apply_settings)
	if GameState.shot_mode:
		_setup_shot()


func _add_water() -> void:
	var water := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(5000, 5000)
	water.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#9fd6e8", 0.82)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.15
	m.metallic_specular = 0.6
	water.material_override = m
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


func _grain_layer() -> ColorRect:
	var layer := CanvasLayer.new()
	layer.layer = 3
	add_child(layer)
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = GRAIN_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
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
	engine.apply_volume()


func _process(delta: float) -> void:
	if not _built:
		return
	car.set_night(day.darkness)
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


func _to_menu() -> void:
	get_tree().paused = false
	GameState.save_game()
	get_tree().change_scene_to_file(MENU)


# --- test mode: autopilot + screenshots + stats ---------------------------------

func _setup_shot() -> void:
	car.autopilot = true
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
		print("[shot] t=%.0f gear=%s low=%s rpm=%.0f fps=%d kmh=%.0f fwd=%.1f pos=(%.0f, %.0f, %.0f) up=%.2f trip=%.0f resets=%d ground=%s" % [
			_shot_t, car.gear_text(), car.low_range, car.engine_rpm, Engine.get_frames_per_second(), car.linear_velocity.length() * 3.6, car.fwd_speed,
			car.global_position.x, car.global_position.y, car.global_position.z,
			car.global_transform.basis.y.y, car.trip, car.resets, car.grounded])
	if not _shot_times.is_empty() and _shot_t >= float(_shot_times[0]):
		GameState.screenshot("%s_%02d.png" % [spec["id"], int(_shot_times[0])])
		_shot_times.pop_front()
	if _shot_times.is_empty():
		print("[shot] done car=%s avg_fps=%.1f trip=%.0f resets=%d coins=%d found=%d" % [
			spec["id"], _fps_sum / maxf(_fps_n, 1), car.trip, car.resets, GameState.coins.size(), feats.found_count()])
		get_tree().quit()
