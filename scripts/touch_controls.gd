class_name TouchControls
extends CanvasLayer
## On-screen controls for phones and tablets (multitouch: steer and pedal at the same time).
## Each button presses the same input action as the keyboard, so the car code doesn't care.

const CREAM := Color("#fff8f0")


static func wanted() -> bool:
	return OS.has_feature("mobile") or GameState.shot_args.has("touch")


func _ready() -> void:
	layer = 4
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# Left thumb: steering, handbrake above it.
	_button(root, "left", "<", Vector2(30, -230), Vector2(170, 190), false, 60)
	_button(root, "right", ">", Vector2(215, -230), Vector2(170, 190), false, 60)
	_button(root, "handbrake", "HAND", Vector2(30, -340), Vector2(355, 90), false, 26)
	# Right thumb: pedals, gears above them.
	_button(root, "gas", "GAS", Vector2(-200, -280), Vector2(170, 250), true, 32)
	_button(root, "brake", "BRAKE", Vector2(-385, -230), Vector2(170, 200), true, 28)
	_button(root, "shift_up", "+", Vector2(-200, -400), Vector2(170, 100), true, 44)
	_button(root, "shift_down", "-", Vector2(-385, -350), Vector2(170, 100), true, 44)
	# Small utility row, top left under the car card.
	var x := 30.0
	for b in [["pause", "II"], ["camera", "CAM"], ["reset", "RESET"], ["low_range", "LOW"]]:
		_button(root, b[0], b[1], Vector2(x, 150), Vector2(96, 70), false, 22, true)
		x += 106.0


func _button(root: Control, action: String, text: String, pos: Vector2, size: Vector2,
		from_right: bool, font_size: int, from_top := false) -> void:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.anchor_left = 1.0 if from_right else 0.0
	holder.anchor_right = holder.anchor_left
	holder.anchor_top = 0.0 if from_top else 1.0
	holder.anchor_bottom = holder.anchor_top
	holder.offset_left = pos.x
	holder.offset_top = pos.y
	holder.offset_right = pos.x + size.x
	holder.offset_bottom = pos.y + size.y
	root.add_child(holder)
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.16, 0.24, 0.45)
	sb.set_corner_radius_all(22)
	sb.set_border_width_all(3)
	sb.border_color = Color(CREAM, 0.5)
	panel.add_theme_stylebox_override("panel", sb)
	holder.add_child(panel)
	var l := Label.new()
	l.text = text
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var ls := LabelSettings.new()
	ls.font_size = font_size
	ls.font_color = CREAM
	l.label_settings = ls
	holder.add_child(l)
	var tsb := TouchScreenButton.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	tsb.shape = shape
	tsb.position = size * 0.5
	tsb.action = action
	tsb.passby_press = action in ["left", "right", "gas", "brake"]
	tsb.pressed.connect(func() -> void: sb.bg_color = Color(0.62, 0.85, 0.77, 0.55))
	tsb.released.connect(func() -> void: sb.bg_color = Color(0.16, 0.16, 0.24, 0.45))
	holder.add_child(tsb)
