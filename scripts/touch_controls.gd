class_name TouchControls
extends CanvasLayer
## On-screen controls for phones and tablets (multitouch: steer and pedal at the same time).
## Only the essentials are always visible; the rest sits in a drawer behind the "more" button,
## and buttons that only make sense sometimes (action, winch, reel, clutch) appear when needed.

const CREAM := Color("#fff8f0")

var car: Car
var sites: Sites

var _drawer: Control
var _drawer_t := 0.0
var _interact: Control
var _winch: Control
var _reel: Control
var _clutch: Control


static func wanted() -> bool:
	return OS.has_feature("mobile") or GameState.shot_args.has("touch")


func _ready() -> void:
	layer = 4
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# Left thumb.
	_button(root, "left", "chevron_left", Vector2(30, -220), Vector2(165, 180), false)
	_button(root, "right", "chevron_right", Vector2(210, -220), Vector2(165, 180), false)
	_button(root, "handbrake", "local_parking", Vector2(30, -320), Vector2(110, 84), false)
	_clutch = _button(root, "clutch", "CLUTCH", Vector2(155, -320), Vector2(220, 84), false)
	# Right thumb.
	_button(root, "gas", "GAS", Vector2(-195, -270), Vector2(165, 240), true)
	_button(root, "brake", "BRAKE", Vector2(-375, -220), Vector2(165, 190), true)
	_button(root, "shift_up", "keyboard_arrow_up", Vector2(-195, -380), Vector2(165, 96), true)
	_button(root, "shift_down", "keyboard_arrow_down", Vector2(-375, -330), Vector2(165, 96), true)
	_winch = _button(root, "winch", "anchor", Vector2(-375, -440), Vector2(165, 96), true)
	_reel = _button(root, "winch_in", "swap_vert", Vector2(-195, -490), Vector2(165, 96), true)
	_interact = _button(root, "interact", "touch_app", Vector2(-375, -560), Vector2(345, 100), true)
	# Top left, under the car card: pause, map, and the drawer for everything else.
	_button(root, "pause", "pause", Vector2(30, 150), Vector2(80, 66), false, true)
	_button(root, "map", "map", Vector2(118, 150), Vector2(80, 66), false, true)
	var more := _button(root, "", "menu", Vector2(206, 150), Vector2(80, 66), false, true)
	(more.get_child(-1) as TouchScreenButton).pressed.connect(func() -> void:
		_drawer.visible = not _drawer.visible
		_drawer_t = 6.0)
	_drawer = Control.new()
	_drawer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drawer.visible = false
	root.add_child(_drawer)
	var x := 30.0
	for b in [["camera", "videocam"], ["reset", "restart_alt"], ["low_range", "landscape"], ["awd", "AWD"],
			["diff", "lock"], ["lights", "highlight"], ["hazards", "warning"], ["ignition", "power_settings_new"]]:
		_button(_drawer, b[0], b[1], Vector2(x, 226), Vector2(80, 66), false, true)
		x += 88.0


func _process(delta: float) -> void:
	visible = not GameState.ui_open
	if _drawer.visible:
		_drawer_t -= delta
		if _drawer_t <= 0.0:
			_drawer.visible = false
	if not car:
		return
	_clutch.visible = car.manual_clutch()
	_winch.visible = bool(car.spec.get("winch", false))
	_reel.visible = car.winch_anchor != Vector3.INF
	_interact.visible = sites != null and sites.hint(car) != ""


## label: an icon name from assets/icons, or plain text. action "" = no input action (handled by caller).
func _button(root: Control, action: String, label: String, pos: Vector2, size: Vector2,
		from_right: bool, from_top := false) -> Control:
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
	sb.bg_color = Color(0.16, 0.16, 0.24, 0.42)
	sb.set_corner_radius_all(22)
	sb.set_border_width_all(2)
	sb.border_color = Color(CREAM, 0.45)
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
	if action != "":
		tsb.action = action
	tsb.passby_press = action in ["left", "right", "gas", "brake", "winch_in", "clutch"]
	tsb.pressed.connect(func() -> void:
		sb.bg_color = Color(0.62, 0.85, 0.77, 0.55)
		if _drawer and holder.get_parent() == _drawer:
			_drawer_t = 6.0)
	tsb.released.connect(func() -> void: sb.bg_color = Color(0.16, 0.16, 0.24, 0.42))
	holder.add_child(tsb)
	return holder
