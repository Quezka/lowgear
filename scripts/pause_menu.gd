class_name PauseMenu
extends CanvasLayer
## Esc menu. In multiplayer the world keeps running (others are still driving).

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
	_first.theme_type_variation = "PrimaryButton"
	_button(v, "Leave to menu" if Net.active else "Change car", func() -> void: change_car.emit())
	v.add_child(SettingsList.new())
	_button(v, "Quit game", func() -> void:
		GameState.save_game()
		Net.leave()
		get_tree().quit())


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
	if not Net.active:
		get_tree().paused = visible
	if visible:
		_first.grab_focus()
	else:
		GameState.save_game()
