class_name PauseMenu
extends CanvasLayer
## Esc menu: resume, change car, settings, quit.

signal change_car

var _first: Button


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.17, 0.16, 0.26, 0.55)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.theme = GameState.ui_theme()
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.custom_minimum_size = Vector2(460, 0)
	panel.add_child(v)
	var title := Label.new()
	title.text = "Paused"
	title.label_settings = GameState.label_settings(40, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	_first = _button(v, "Resume", toggle)
	_button(v, "Change car", func() -> void: change_car.emit())
	_check(v, "Automatic gearbox", "auto_gearbox")
	_check(v, "Fullscreen", "fullscreen")
	_check(v, "Shadows", "shadows")
	_check(v, "Film grain", "grain")
	_slider(v, "Music", "music")
	_slider(v, "Engine", "engine")
	_slider(v, "Sounds", "sfx")
	_button(v, "Quit game", func() -> void:
		GameState.save_game()
		get_tree().quit())


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 54)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _check(parent: Control, text: String, key: String) -> void:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = bool(GameState.settings[key])
	c.toggled.connect(func(on: bool) -> void: GameState.set_setting(key, on))
	parent.add_child(c)


func _slider(parent: Control, text: String, key: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(130, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = float(GameState.settings[key])
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(0, 32)
	s.value_changed.connect(func(val: float) -> void: GameState.set_setting(key, val))
	row.add_child(s)
	parent.add_child(row)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	visible = not visible
	get_tree().paused = visible
	if visible:
		_first.grab_focus()
	else:
		GameState.save_game()
