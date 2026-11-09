class_name Hud
extends CanvasLayer
## Driving HUD: soft dark cards with big light text (readable on any sky), gauge cluster,
## compass, toasts and the multiplayer roster.

const CREAM := Color("#fff8f0")
const SURFACES := ["Grass", "Sand", "Rock", "Snow", "Water"]

var car: Car
var feats: Collectibles
var cam: Camera3D

var _car_lbl: Label
var _trip: Label
var _surface: Label
var _coins: Label
var _views: Label
var _players: VBoxContainer
var _players_card: PanelContainer
var _toast: Label
var _toast_card: PanelContainer
var _hint_card: PanelContainer
var _fade: ColorRect
var _compass: Compass
var _toast_t := 0.0
var _hint_t := 16.0


func _ready() -> void:
	layer = 2
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Top left: car and trip.
	var tl := _card(root)
	tl.position = Vector2(20, 16)
	var tlv := _vbox(tl)
	_car_lbl = _text(tlv, 30)
	_trip = _text(tlv, 22)
	_surface = _text(tlv, 20, Color(CREAM, 0.75))

	# Top right: progress and players.
	var tr := _card(root)
	_anchor_right(tr, 16)
	var trv := _vbox(tr)
	_coins = _text(trv, 26)
	_views = _text(trv, 26)
	_coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_views.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_players_card = _card(root)
	_anchor_right(_players_card, 118)
	_players = _vbox(_players_card)
	_players_card.visible = false

	_compass = Compass.new()
	_compass.cam = cam
	_compass.feats = feats
	_compass.anchor_left = 0.5
	_compass.anchor_right = 0.5
	_compass.offset_left = -280
	_compass.offset_right = 280
	_compass.offset_top = 16
	_compass.offset_bottom = 64
	root.add_child(_compass)

	# Bottom right: instruments.
	var gc := _card(root)
	gc.anchor_left = 1.0
	gc.anchor_right = 1.0
	gc.anchor_top = 1.0
	gc.anchor_bottom = 1.0
	gc.offset_right = -20
	gc.offset_bottom = -16
	gc.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	gc.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var gauge := Gauge.new()
	gauge.car = car
	gc.add_child(gauge)

	# Bottom centre: toasts.
	var tc := CenterContainer.new()
	tc.anchor_right = 1.0
	tc.anchor_top = 1.0
	tc.anchor_bottom = 1.0
	tc.offset_top = -200
	tc.offset_bottom = -130
	tc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tc)
	_toast_card = _card(tc, 26)
	_toast = _text(_toast_card, 32)
	_toast_card.modulate.a = 0.0

	# Bottom left: controls, fades out.
	_hint_card = _card(root)
	_hint_card.anchor_top = 1.0
	_hint_card.anchor_bottom = 1.0
	_hint_card.offset_left = 20
	_hint_card.offset_bottom = -16
	_hint_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 2)
	_hint_card.add_child(grid)
	for pair in [["W / S", "gas, brake"], ["A / D", "steer"], ["Q / E", "shift"], ["L", "low range"],
			["Space", "handbrake"], ["R", "reset"], ["C", "camera"], ["Esc", "pause"]]:
		_text(grid, 20, Color("#f6bd60")).text = pair[0]
		_text(grid, 20).text = pair[1]

	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color("#fff3e8")
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	root.add_child(_fade)

	Net.roster_changed.connect(_refresh_players)
	_refresh_players()


func _card(parent: Control, radius := 16) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.16, 0.24, 0.62)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p


func _vbox(parent: Control) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	parent.add_child(v)
	return v


func _text(parent: Control, size: int, color := CREAM) -> Label:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.font_color = color
	l.label_settings = ls
	parent.add_child(l)
	return l


func _anchor_right(c: Control, top: float) -> void:
	c.anchor_left = 1.0
	c.anchor_right = 1.0
	c.offset_right = -20
	c.offset_top = top
	c.grow_horizontal = Control.GROW_DIRECTION_BEGIN


func _refresh_players() -> void:
	if not _players:
		return
	for c in _players.get_children():
		c.queue_free()
	_players_card.visible = Net.active
	if not Net.active:
		return
	var head := _text(_players, 20, Color(CREAM, 0.75))
	head.text = "Hosting on %s" % ", ".join(Net.local_ips()) if Net.is_host() else "Online"
	var ids := Net.players.keys()
	ids.sort()
	for id in ids:
		var p: Dictionary = Net.players[id]
		var l := _text(_players, 24, Net.player_color(id).lightened(0.3))
		var you := "  (you)" if id == Net.my_id() else ""
		l.text = "%s  %s%s" % [p["name"], CarSpecs.get_spec(str(p["car"]))["name"], you]


func _process(delta: float) -> void:
	if not car:
		return
	_car_lbl.text = str(car.spec["name"])
	_trip.text = "Trip  %.1f km" % (car.trip / 1000.0)
	_surface.text = "On %s" % SURFACES[car.surface].to_lower()
	_coins.text = "Coins  %d / %d" % [GameState.coins.size(), feats.total_coins]
	_views.text = "Viewpoints  %d / %d" % [feats.found_count(), feats.landmarks.size()]
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast_card.modulate.a = clampf(_toast_t / 0.8, 0.0, 1.0)
	if _hint_t > 0.0:
		_hint_t -= delta
		_hint_card.modulate.a = clampf(_hint_t / 2.0, 0.0, 1.0)
	_compass.queue_redraw()


func toast(text: String) -> void:
	_toast.text = text
	_toast_t = 4.0
	_toast_card.modulate.a = 1.0


func flash() -> void:
	_fade.modulate.a = 0.9
	create_tween().tween_property(_fade, "modulate:a", 0.0, 0.7)
