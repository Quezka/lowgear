extends Node3D
## Title screen: pick a car on a turntable at golden hour, then drive solo, host or join.

const MAIN := "res://scenes/main.tscn"

var _ids: Array = CarSpecs.ORDER
var _index := 0
var _turntable: Node3D
var _car_vis: Node3D
var _name_lbl: Label
var _blurb: Label
var _stats_box: VBoxContainer
var _odo: Label
var _solo_btn: Button
var _name_edit: LineEdit
var _ip_edit: LineEdit
var _status: Label
var _settings: Control
var _busy := false


func _ready() -> void:
	if GameState.server_mode:
		Net.host(true)
		return
	Net.leave()
	_index = maxi(_ids.find(GameState.car_id), 0)
	_build_scene()
	_build_ui()
	_show_car()
	Net.status.connect(_on_status)
	Updater.update_available.connect(_on_update)
	Updater.progress.connect(_on_status)
	if not Updater.latest.is_empty():
		_on_update(Updater.latest)
	Updater.check()
	Net.joined.connect(_on_joined)
	if GameState.shot_mode:
		_shot()


func _build_scene() -> void:
	var we := WorldEnvironment.new()
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)
	var day := DayCycle.new()
	add_child(day)
	day.setup(we, sun, 0.69)
	day.set_process(false)
	day.env.fog_density = 0.012

	var ground := MeshInstance3D.new()
	ground.mesh = LowPoly.cyl(9.0, 9.6, 0.4, 48)
	var gm := StandardMaterial3D.new()
	gm.albedo_texture = load("res://assets/cc0/terrain/meadow_color.jpg")
	gm.uv1_triplanar = true
	gm.uv1_scale = Vector3(0.3, 0.3, 0.3)
	gm.roughness = 0.95
	gm.albedo_color = Color(1.2, 1.25, 1.05)
	ground.material_override = gm
	ground.position.y = -0.2
	add_child(ground)
	var field := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(600, 600)
	field.mesh = plane
	field.material_override = gm
	field.position.y = -0.4
	add_child(field)
	var pine := Props.conifer_mesh()
	var round_mesh := Props.broadleaf_mesh()
	var spots := [
		[Vector3(-10, 0, -18), true], [Vector3(-20, 0, -10), false], [Vector3(-2, 0, -26), true],
		[Vector3(9, 0, -24), false], [Vector3(-26, 0, -28), true], [Vector3(18, 0, -34), true],
		[Vector3(-16, 0, 10), false], [Vector3(24, 0, -14), false],
	]
	for s in spots:
		var c := MeshInstance3D.new()
		c.mesh = pine if s[1] else round_mesh
		c.position = s[0]
		add_child(c)

	_turntable = Node3D.new()
	add_child(_turntable)
	var cam := Camera3D.new()
	cam.fov = 48.0
	cam.position = Vector3(5.2, 2.4, 6.6)
	add_child(cam)
	cam.look_at(Vector3(-0.9, 0.2, 0.0), Vector3.UP)
	cam.current = true


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = GameState.ui_theme()
	ui.add_child(root)

	# Left: the car.
	var panel := PanelContainer.new()
	panel.position = Vector2(32, 28)
	panel.custom_minimum_size = Vector2(540, 0)
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	v.add_child(head)
	var icon := TextureRect.new()
	icon.texture = load("res://assets/lowgear_icon.png")
	icon.custom_minimum_size = Vector2(84, 84)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(icon)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tv)
	var title := Label.new()
	title.text = "lowgear"
	title.label_settings = GameState.label_settings(60, true)
	tv.add_child(title)
	var sub := Label.new()
	sub.text = "a lofi off-road drive"
	sub.label_settings = GameState.label_settings(22, true, GameState.MUTED)
	tv.add_child(sub)
	var logo := TextureRect.new()
	logo.texture = load("res://assets/logo.png")
	logo.custom_minimum_size = Vector2(40, 40)
	logo.tooltip_text = "by Quezka"
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(logo)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	row.add_child(_small_button("<", _cycle.bind(-1)))
	_name_lbl = Label.new()
	_name_lbl.label_settings = GameState.label_settings(38, true)
	_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_name_lbl)
	row.add_child(_small_button(">", _cycle.bind(1)))
	_blurb = Label.new()
	_blurb.label_settings = GameState.label_settings(23, true)
	_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_blurb.custom_minimum_size = Vector2(480, 92)
	v.add_child(_blurb)
	_stats_box = VBoxContainer.new()
	_stats_box.add_theme_constant_override("separation", 6)
	v.add_child(_stats_box)
	_odo = Label.new()
	_odo.label_settings = GameState.label_settings(21, true, GameState.MUTED)
	_odo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_odo)

	# Right: play.
	var play := PanelContainer.new()
	play.anchor_left = 1.0
	play.anchor_right = 1.0
	play.anchor_top = 1.0
	play.anchor_bottom = 1.0
	play.offset_right = -32
	play.offset_bottom = -28
	play.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	play.grow_vertical = Control.GROW_DIRECTION_BEGIN
	play.custom_minimum_size = Vector2(470, 0)
	root.add_child(play)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 10)
	play.add_child(pv)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 12)
	pv.add_child(name_row)
	var nl := Label.new()
	nl.text = "Name"
	name_row.add_child(nl)
	_name_edit = LineEdit.new()
	_name_edit.text = str(GameState.settings["name"])
	_name_edit.max_length = 16
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text_changed.connect(func(t: String) -> void: GameState.settings["name"] = t)
	name_row.add_child(_name_edit)
	_solo_btn = Button.new()
	_solo_btn.text = "Drive solo"
	_solo_btn.theme_type_variation = "PrimaryButton"
	_solo_btn.custom_minimum_size = Vector2(0, 64)
	_solo_btn.pressed.connect(_drive)
	pv.add_child(_solo_btn)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	pv.add_child(row2)
	var host_btn := Button.new()
	host_btn.text = "Host game"
	host_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host_btn.pressed.connect(_host)
	row2.add_child(host_btn)
	var set_btn := Button.new()
	set_btn.text = "Settings"
	set_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	set_btn.pressed.connect(func() -> void: _settings.visible = true)
	row2.add_child(set_btn)
	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 10)
	pv.add_child(row3)
	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "address to join"
	_ip_edit.text = str(GameState.settings["last_ip"])
	_ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ip_edit.text_submitted.connect(func(_t: String) -> void: _join())
	row3.add_child(_ip_edit)
	var join_btn := Button.new()
	join_btn.text = "Join"
	join_btn.pressed.connect(_join)
	row3.add_child(join_btn)
	_status = Label.new()
	_status.label_settings = GameState.label_settings(21, true, GameState.MUTED)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(420, 0)
	_status.text = "Enter: drive     Left / Right: car     Esc: quit"
	pv.add_child(_status)

	# Settings popup.
	_settings = CenterContainer.new()
	_settings.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings.visible = false
	root.add_child(_settings)
	var sp := PanelContainer.new()
	_settings.add_child(sp)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 12)
	sv.custom_minimum_size = Vector2(460, 0)
	sp.add_child(sv)
	var st := Label.new()
	st.text = "Settings"
	st.label_settings = GameState.label_settings(36, true)
	sv.add_child(st)
	sv.add_child(SettingsList.new())
	var close := Button.new()
	close.text = "Done"
	close.pressed.connect(func() -> void:
		_settings.visible = false
		GameState.save_game()
		_solo_btn.grab_focus())
	sv.add_child(close)
	_solo_btn.grab_focus.call_deferred()


func _small_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(64, 56)
	b.pressed.connect(cb)
	return b


func _show_car() -> void:
	var id: String = _ids[_index]
	var spec := CarSpecs.get_spec(id)
	GameState.car_id = id
	if _car_vis:
		_car_vis.queue_free()
	_car_vis = CarBuilder.build_display(spec)
	_turntable.add_child(_car_vis)
	_name_lbl.text = str(spec["name"])
	_blurb.text = str(spec["blurb"])
	for c in _stats_box.get_children():
		c.queue_free()
	var stats: Dictionary = spec["stats"]
	for k in stats:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 8)
		var l := Label.new()
		l.text = str(k)
		l.label_settings = GameState.label_settings(22, true)
		l.custom_minimum_size = Vector2(150, 0)
		r.add_child(l)
		for i in 5:
			var pip := ColorRect.new()
			pip.custom_minimum_size = Vector2(46, 20)
			pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			pip.color = Color("#7f9c96") if i < int(stats[k]) else Color("#e3d9d2")
			r.add_child(pip)
		_stats_box.add_child(r)
	var dt: Dictionary = spec["drivetrain"]
	var gb := "%d-speed manual%s" % [(dt["gears"] as Array).size(), ", low range" if float(dt["low"]) > 0.0 else ""]
	var km := float(GameState.odometer.get(id, 0.0)) / 1000.0
	_odo.text = "%s, %s\nDriven %.1f km     Coins %d     Viewpoints %d / 8" % [
		"4x4" if spec["drive"] == "awd" else "front-wheel drive", gb, km,
		GameState.coins.size(), GameState.viewpoints.size()]


func _cycle(dir: int) -> void:
	_index = posmod(_index + dir, _ids.size())
	_show_car()


func _input(event: InputEvent) -> void:
	if _busy:
		return
	if get_viewport().gui_get_focus_owner() is LineEdit:
		if event.is_action_pressed("ui_cancel"):
			_solo_btn.grab_focus()
			get_viewport().set_input_as_handled()
		return
	if _settings.visible:
		if event.is_action_pressed("pause"):
			_settings.visible = false
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_left") or event.is_action_pressed("left"):
		_cycle(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("right"):
		_cycle(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		GameState.save_game()
		get_tree().quit()


func _process(delta: float) -> void:
	if _turntable:
		_turntable.rotate_y(delta * 0.35)


func _drive() -> void:
	_busy = true
	GameState.save_game()
	get_tree().change_scene_to_file(MAIN)


func _host() -> void:
	if Net.host():
		_drive()


func _join() -> void:
	var ip := _ip_edit.text.strip_edges()
	GameState.settings["last_ip"] = ip
	GameState.save_game()
	Net.join(ip)


func _on_status(text: String) -> void:
	if _status:
		_status.text = text


func _on_update(v: String) -> void:
	var b := Button.new()
	b.text = "Update to %s" % v
	b.theme_type_variation = "PrimaryButton"
	b.pressed.connect(func() -> void:
		b.disabled = true
		Updater.install())
	_status.get_parent().add_child(b)
	_status.get_parent().move_child(b, 0)
	_status.text = "A new version is out: %s (you have %s)" % [v, Net.version()]


func _on_joined() -> void:
	_drive()


func _shot() -> void:
	var a := GameState.shot_args
	if a.has("name"):
		GameState.settings["name"] = str(a["name"])
	if a.has("menu"):
		await get_tree().create_timer(2.0).timeout
		GameState.screenshot("menu_%s.png" % GameState.car_id)
	if a.has("host"):
		_host.call_deferred()
	elif a.has("join"):
		Net.join(str(a["join"]))
	else:
		_drive.call_deferred()
