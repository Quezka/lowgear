class_name Hud
extends CanvasLayer
## Big, high-contrast driving HUD.

var car: Car
var feats: Collectibles
var cam: Camera3D

var _car_lbl: Label
var _speed: Label
var _trip: Label
var _coins: Label
var _views: Label
var _toast: Label
var _hint: Label
var _fade: ColorRect
var _compass: Compass
var _toast_t := 0.0
var _hint_t := 14.0


func _ready() -> void:
	layer = 2
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_car_lbl = _label(root, 26, Vector2(28, 18))
	_speed = _label(root, 48, Vector2(28, 48))
	_trip = _label(root, 24, Vector2(28, 116))
	_coins = _label_right(root, 30, 18)
	_views = _label_right(root, 30, 62)

	_compass = Compass.new()
	_compass.cam = cam
	_compass.feats = feats
	_compass.anchor_left = 0.5
	_compass.anchor_right = 0.5
	_compass.offset_left = -300
	_compass.offset_right = 300
	_compass.offset_top = 14
	_compass.offset_bottom = 64
	root.add_child(_compass)

	_toast = Label.new()
	_toast.label_settings = GameState.label_settings(34)
	_toast.anchor_right = 1.0
	_toast.anchor_top = 1.0
	_toast.anchor_bottom = 1.0
	_toast.offset_top = -190
	_toast.offset_bottom = -140
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	root.add_child(_toast)

	_hint = Label.new()
	_hint.label_settings = GameState.label_settings(22)
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = 28
	_hint.offset_top = -56
	_hint.offset_right = 1340
	_hint.text = "W / S  gas & brake     A / D  steer     Space  handbrake     R  reset     C  camera     Esc  pause"
	root.add_child(_hint)

	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color("#fff3e8")
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	root.add_child(_fade)


func _label(parent: Control, size: int, pos: Vector2) -> Label:
	var l := Label.new()
	l.label_settings = GameState.label_settings(size)
	l.position = pos
	parent.add_child(l)
	return l


func _label_right(parent: Control, size: int, top: float) -> Label:
	var l := Label.new()
	l.label_settings = GameState.label_settings(size)
	l.anchor_left = 1.0
	l.anchor_right = 1.0
	l.offset_left = -440
	l.offset_right = -28
	l.offset_top = top
	l.offset_bottom = top + size + 16
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	parent.add_child(l)
	return l


func _process(delta: float) -> void:
	if not car:
		return
	_car_lbl.text = str(car.spec["name"])
	_speed.text = "%d km/h" % int(absf(car.fwd_speed) * 3.6)
	_trip.text = "Trip  %.1f km" % (car.trip / 1000.0)
	_coins.text = "Coins  %d / %d" % [GameState.coins.size(), feats.total_coins]
	_views.text = "Viewpoints  %d / %d" % [feats.found_count(), feats.landmarks.size()]
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.modulate.a = clampf(_toast_t / 0.8, 0.0, 1.0)
	if _hint_t > 0.0:
		_hint_t -= delta
		_hint.modulate.a = clampf(_hint_t / 2.0, 0.0, 1.0)
	_compass.queue_redraw()


func toast(text: String) -> void:
	_toast.text = text
	_toast_t = 4.0
	_toast.modulate.a = 1.0


func flash() -> void:
	_fade.modulate.a = 0.9
	create_tween().tween_property(_fade, "modulate:a", 0.0, 0.7)
