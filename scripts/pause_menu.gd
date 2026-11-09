class_name PauseMenu
extends CanvasLayer
## Esc menu. In multiplayer the world keeps running (others are still driving).

signal change_car

var _first: Button
var _scroll: ScrollContainer


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
	# Two columns so it fits short (phone) screens; settings scroll if needed.
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 28)
	panel.add_child(cols)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.custom_minimum_size = Vector2(320, 0)
	cols.add_child(v)
	var title := Label.new()
	title.text = "Paused"
	title.label_settings = GameState.label_settings(40, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	_first = _button(v, "Resume", toggle)
	_first.icon = Icons.tex("play_arrow", 64)
	_first.theme_type_variation = "PrimaryButton"
	_button(v, "Main menu", func() -> void: change_car.emit()).icon = Icons.tex("home", 64)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(440, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_child(scroll)
	var settings := SettingsList.new()
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(settings)
	_scroll = scroll
	var quit := _button(v, "Quit game", func() -> void:
		GameState.save_game()
		Net.leave()
		get_tree().quit())
	quit.icon = Icons.tex("exit_to_app", 64)


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 52)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	visible = not visible
	GameState.ui_open = visible
	if visible:
		# Fit the settings column to the screen height (phones are short).
		var h := get_viewport().get_visible_rect().size.y
		_scroll.custom_minimum_size.y = clampf(h - 140.0, 240.0, 600.0)
	if not Net.active:
		get_tree().paused = visible
	if visible:
		_first.grab_focus()
	else:
		GameState.save_game()
