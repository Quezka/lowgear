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
var _gear: Label
var _range: Label
var _tach: ProgressBar
var _tach_fill: StyleBoxFlat
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
	_hint.text = "W / S  gas & brake    A / D  steer    Q / E  shift    L  low range    Space  handbrake    R  reset    C  camera    Esc  pause"
	root.add_child(_hint)

	_gear = Label.new()
	_gear.label_settings = GameState.label_settings(72)
	_gear.anchor_left = 1.0
	_gear.anchor_right = 1.0
	_gear.anchor_top = 1.0
	_gear.anchor_bottom = 1.0
	_gear.offset_left = -150
	_gear.offset_right = -36
	_gear.offset_top = -170
	_gear.offset_bottom = -80
	_gear.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_gear)
	_range = Label.new()
	_range.label_settings = GameState.label_settings(24)
	_range.anchor_left = 1.0
	_range.anchor_right = 1.0
	_range.anchor_top = 1.0
	_range.anchor_bottom = 1.0
	_range.offset_left = -360
	_range.offset_right = -36
	_range.offset_top = -200
	_range.offset_bottom = -168
	_range.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_range)
	_tach = ProgressBar.new()
	_tach.show_percentage = false
	_tach.min_value = 0.0
	_tach.max_value = 1.0
	_tach.anchor_left = 1.0
	_tach.anchor_right = 1.0
	_tach.anchor_top = 1.0
	_tach.anchor_bottom = 1.0
	_tach.offset_left = -330
	_tach.offset_right = -36
	_tach.offset_top = -74
	_tach.offset_bottom = -52
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.17, 0.18, 0.26, 0.6)
	bg.set_corner_radius_all(8)
	_tach.add_theme_stylebox_override("background", bg)
	_tach_fill = StyleBoxFlat.new()
	_tach_fill.set_corner_radius_all(8)
	_tach.add_theme_stylebox_override("fill", _tach_fill)
	root.add_child(_tach)

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
	_gear.text = car.gear_text()
	_range.text = ("LOW  " if car.low_range else "") + ("AUTO" if car.is_auto() else "MANUAL")
	_tach.value = car.rpm
	_tach_fill.bg_color = Color("#9ed9c5").lerp(Color("#f28482"), clampf((car.rpm - 0.7) / 0.25, 0.0, 1.0))
	_compass.queue_redraw()


func toast(text: String) -> void:
	_toast.text = text
	_toast_t = 4.0
	_toast.modulate.a = 1.0


func flash() -> void:
	_fade.modulate.a = 0.9
	create_tween().tween_property(_fade, "modulate:a", 0.0, 0.7)
