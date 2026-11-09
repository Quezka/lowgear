extends Node3D
## Title screen: pick a car on a turntable at golden hour.

const MAIN := "res://scenes/main.tscn"

var _ids: Array = CarSpecs.ORDER
var _index := 0
var _turntable: Node3D
var _car_vis: Node3D
var _name_lbl: Label
var _blurb: Label
var _stats_box: VBoxContainer
var _odo: Label
var _drive_btn: Button


func _ready() -> void:
	_index = maxi(_ids.find(GameState.car_id), 0)
	_build_scene()
	_build_ui()
	_show_car()
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
	ground.mesh = LowPoly.flat(LowPoly.cyl(9.0, 9.6, 0.4, 20))
	ground.material_override = LowPoly.mat(Color("#b9dfa8"))
	ground.position.y = -0.2
	add_child(ground)
	var field := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(600, 600)
	field.mesh = plane
	field.material_override = LowPoly.mat(Color("#a6d6a0"))
	field.position.y = -0.4
	add_child(field)
	var trunk_mesh := Props.trunk()
	var pine := Props.pine_crown()
	var round_mesh := Props.round_crown()
	var spots := [
		[Vector3(-6, 0, -9), true, "#93c4a6"], [Vector3(-11, 0, -4), false, "#f7c6d9"],
		[Vector3(-2, 0, -13), true, "#84b59f"], [Vector3(5, 0, -12), false, "#ffd6a5"],
		[Vector3(-16, 0, -14), true, "#a0cbb0"], [Vector3(10, 0, -18), true, "#7aa995"],
		[Vector3(-9, 0, 6), false, "#cfe8a9"],
	]
	for s in spots:
		var t := MeshInstance3D.new()
		t.mesh = trunk_mesh
		t.material_override = LowPoly.mat(Props.TRUNK_COL)
		t.position = s[0]
		add_child(t)
		var c := MeshInstance3D.new()
		c.mesh = pine if s[1] else round_mesh
		c.material_override = LowPoly.mat(Color(str(s[2])))
		c.position = s[0]
		add_child(c)

	_turntable = Node3D.new()
	add_child(_turntable)
	var cam := Camera3D.new()
	cam.fov = 50.0
	cam.position = Vector3(4.6, 2.1, 6.2)
	add_child(cam)
	cam.look_at(Vector3(-1.9, 0.55, 0.2), Vector3.UP)
	cam.current = true


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = GameState.ui_theme()
	ui.add_child(root)
	var panel := PanelContainer.new()
	panel.position = Vector2(40, 36)
	panel.custom_minimum_size = Vector2(580, 0)
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	var title := Label.new()
	title.text = "lowgear"
	title.label_settings = GameState.label_settings(64, true)
	v.add_child(title)
	var sub := Label.new()
	sub.text = "a lofi off-road drive"
	sub.label_settings = GameState.label_settings(24, true, GameState.MUTED)
	v.add_child(sub)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var prev := Button.new()
	prev.text = "<"
	prev.custom_minimum_size = Vector2(64, 56)
	prev.pressed.connect(_cycle.bind(-1))
	row.add_child(prev)
	_name_lbl = Label.new()
	_name_lbl.label_settings = GameState.label_settings(40, true)
	_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_name_lbl)
	var nxt := Button.new()
	nxt.text = ">"
	nxt.custom_minimum_size = Vector2(64, 56)
	nxt.pressed.connect(_cycle.bind(1))
	row.add_child(nxt)

	_blurb = Label.new()
	_blurb.label_settings = GameState.label_settings(24, true)
	_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_blurb.custom_minimum_size = Vector2(520, 96)
	v.add_child(_blurb)
	_stats_box = VBoxContainer.new()
	_stats_box.add_theme_constant_override("separation", 6)
	v.add_child(_stats_box)
	_odo = Label.new()
	_odo.label_settings = GameState.label_settings(22, true, GameState.MUTED)
	v.add_child(_odo)

	_drive_btn = Button.new()
	_drive_btn.text = "Drive"
	_drive_btn.custom_minimum_size = Vector2(0, 64)
	_drive_btn.add_theme_font_size_override("font_size", 34)
	_drive_btn.pressed.connect(_drive)
	v.add_child(_drive_btn)
	var hint := Label.new()
	hint.text = "Left / Right: choose     Enter: drive     Esc: quit"
	hint.label_settings = GameState.label_settings(20, true, GameState.MUTED)
	v.add_child(hint)
	_drive_btn.grab_focus.call_deferred()


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
	var km := float(GameState.odometer.get(id, 0.0)) / 1000.0
	_odo.text = "Driven %.1f km     Coins %d     Viewpoints %d / 8" % [km, GameState.coins.size(), GameState.viewpoints.size()]


func _cycle(dir: int) -> void:
	_index = posmod(_index + dir, _ids.size())
	_show_car()


func _input(event: InputEvent) -> void:
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
	_turntable.rotate_y(delta * 0.35)


func _drive() -> void:
	GameState.save_game()
	get_tree().change_scene_to_file(MAIN)


func _shot() -> void:
	if GameState.shot_args.has("menu"):
		await get_tree().create_timer(2.0).timeout
		GameState.screenshot("menu_%s.png" % GameState.car_id)
	_drive.call_deferred()
