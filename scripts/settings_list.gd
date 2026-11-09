class_name SettingsList
extends VBoxContainer
## The settings controls, shared by the title screen and the pause menu.


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	_check("Automatic gearbox", "auto_gearbox")
	_check("Fullscreen", "fullscreen")
	_check("Shadows", "shadows")
	_check("Film grain", "grain")
	_slider("Music", "music")
	_slider("Engine", "engine")
	_slider("Sounds", "sfx")


func _check(text: String, key: String) -> void:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = bool(GameState.settings[key])
	c.toggled.connect(func(on: bool) -> void: GameState.set_setting(key, on))
	add_child(c)


func _slider(text: String, key: String) -> void:
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
	s.custom_minimum_size = Vector2(200, 32)
	s.value_changed.connect(func(val: float) -> void: GameState.set_setting(key, val))
	row.add_child(s)
	add_child(row)
