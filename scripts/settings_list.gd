class_name SettingsList
extends VBoxContainer
## The settings controls, shared by the title screen and the pause menu.


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	_quality()
	_check("Automatic gearbox", "auto_gearbox")
	_check("Manual clutch (Shift)", "manual_clutch")
	if not OS.has_feature("mobile"):
		_check("Fullscreen", "fullscreen")
	_check("Shadows", "shadows")
	_check("Soft film look", "grain")
	_slider("Interface size", "ui_scale", 0.75, 1.5)
	_slider("Music", "music")
	_slider("Engine", "engine")
	_slider("Sounds", "sfx")
	if not OS.has_feature("editor"):
		var up := Button.new()
		up.text = "Check for updates"
		up.icon = Icons.tex("refresh", 48)
		up.pressed.connect(func() -> void:
			up.text = "Checking..."
			Updater.checked.connect(func(found: bool) -> void:
				up.text = "Update %s found: see the main menu" % Updater.latest if found else "You have the latest version (%s)" % Net.version(),
				CONNECT_ONE_SHOT)
			Updater.check_now())
		add_child(up)


func _quality() -> void:
	var names := ["Low", "Medium", "High"]
	var b := Button.new()
	var refresh := func() -> void:
		var auto := int(GameState.settings["quality"]) < 0
		b.text = "Graphics: %s%s" % [names[GameState.quality()], " (auto)" if auto else ""]
	refresh.call()
	b.tooltip_text = "Applies the next time you start driving"
	b.pressed.connect(func() -> void:
		GameState.set_setting("quality", (GameState.quality() + 1) % 3)
		refresh.call())
	add_child(b)


func _check(text: String, key: String) -> void:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = bool(GameState.settings[key])
	c.toggled.connect(func(on: bool) -> void: GameState.set_setting(key, on))
	add_child(c)


func _slider(text: String, key: String, lo := 0.0, hi := 1.0) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(130, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = float(GameState.settings[key])
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(200, 32)
	s.value_changed.connect(func(val: float) -> void: GameState.set_setting(key, val))
	row.add_child(s)
	add_child(row)
