class_name TouchControls
extends CanvasLayer
## On-screen controls for phones and tablets (multitouch: steer and pedal at the same time).
## Each button presses the same input action as the keyboard, so the car code doesn't care.

const CREAM := Color("#fff8f0")


func _process(_delta: float) -> void:
	visible = not GameState.ui_open


static func wanted() -> bool:
	return OS.has_feature("mobile") or GameState.shot_args.has("touch")


func _ready() -> void:
	layer = 4
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# Left thumb: steering, handbrake above it.
	_button(root, "left", "chevron_left", Vector2(30, -230), Vector2(170, 190), false)
	_button(root, "right", "chevron_right", Vector2(215, -230), Vector2(170, 190), false)
	_button(root, "handbrake", "local_parking", Vector2(30, -340), Vector2(355, 90), false)
	# Right thumb: pedals, gears and winch above them.
	_button(root, "gas", "GAS", Vector2(-200, -280), Vector2(170, 250), true)
	_button(root, "brake", "BRAKE", Vector2(-385, -230), Vector2(170, 200), true)
	_button(root, "shift_up", "keyboard_arrow_up", Vector2(-200, -400), Vector2(170, 100), true)
	_button(root, "shift_down", "keyboard_arrow_down", Vector2(-385, -350), Vector2(170, 100), true)
	_button(root, "winch", "anchor", Vector2(-385, -470), Vector2(170, 100), true)
	_button(root, "winch_in", "swap_vert", Vector2(-200, -520), Vector2(170, 100), true)
	# Utility row, top left under the car card.
	var x := 30.0
	for b in [["pause", "pause"], ["camera", "videocam"], ["reset", "restart_alt"], ["low_range", "landscape"],
			["awd", "AWD"], ["diff", "lock"], ["lights", "highlight"], ["hazards", "warning"], ["ignition", "power_settings_new"]]:
		_button(root, b[0], b[1], Vector2(x, 168), Vector2(88, 70), false, true)
		x += 96.0


## label: an icon name from assets/icons, or plain text.
func _button(root: Control, action: String, label: String, pos: Vector2, size: Vector2,
		from_right: bool, from_top := false) -> void:
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
	if ResourceLoader.exists("res://assets/icons/%s.svg" % label):
		var ic := Icons.rect(label, int(minf(size.x, size.y) * 0.55), CREAM)
		ic.set_anchors_preset(Control.PRESET_FULL_RECT)
		holder.add_child(ic)
	else:
		var l := Label.new()
		l.text = label
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var ls := LabelSettings.new()
		ls.font_size = 26 if label.length() > 3 else 24
		ls.font_color = CREAM
		l.label_settings = ls
		holder.add_child(l)
	var tsb := TouchScreenButton.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	tsb.shape = shape
	tsb.position = size * 0.5
	tsb.action = action
	tsb.passby_press = action in ["left", "right", "gas", "brake", "winch_in"]
	tsb.pressed.connect(func() -> void: sb.bg_color = Color(0.62, 0.85, 0.77, 0.55))
	tsb.released.connect(func() -> void: sb.bg_color = Color(0.16, 0.16, 0.24, 0.45))
	holder.add_child(tsb)
