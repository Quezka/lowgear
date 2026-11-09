class_name Gauge
extends Control
## Instrument cluster: rpm arc, gear in the middle, speed underneath, LOW / AUTO chips.

const START := deg_to_rad(135.0)
const SWEEP := deg_to_rad(270.0)
const CREAM := Color("#fff8f0")
const MINT := Color("#9ed9c5")
const CORAL := Color("#f28482")

var car: Car


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(250, 220)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not car:
		return
	var font := ThemeDB.fallback_font
	var c := Vector2(size.x * 0.5, 112.0)
	var r := 92.0
	draw_arc(c, r, START, START + SWEEP, 64, Color(1, 1, 1, 0.16), 16.0, true)
	draw_arc(c, r + 13.0, START + SWEEP * 0.85, START + SWEEP, 16, Color(CORAL, 0.85), 5.0, true)
	var f := clampf(car.rpm, 0.0, 1.0)
	var col := MINT.lerp(CORAL, clampf((f - 0.7) / 0.2, 0.0, 1.0))
	if f > 0.01:
		draw_arc(c, r, START, START + SWEEP * f, 64, col, 16.0, true)
	for i in 8:
		var a := START + SWEEP * i / 7.0
		var dir := Vector2(cos(a), sin(a))
		draw_line(c + dir * (r - 24.0), c + dir * (r - 14.0), Color(CREAM, 0.7), 2.0)
	draw_string(font, Vector2(c.x - 60, c.y + 26), car.gear_text(), HORIZONTAL_ALIGNMENT_CENTER, 120, 76, CREAM)
	var kmh := "%d" % int(absf(car.fwd_speed) * 3.6)
	draw_string(font, Vector2(c.x - 60, c.y + 74), kmh, HORIZONTAL_ALIGNMENT_CENTER, 120, 34, CREAM)
	draw_string(font, Vector2(c.x - 60, c.y + 98), "km/h", HORIZONTAL_ALIGNMENT_CENTER, 120, 18, Color(CREAM, 0.75))
	var chips: Array = []
	if car.low_range:
		chips.append(["LOW", Color("#f6bd60")])
	chips.append(["AUTO" if car.is_auto() else "MANUAL", Color("#b8a1e3")])
	var x := c.x - (chips.size() * 84.0 - 8.0) * 0.5
	for ch in chips:
		var rect := Rect2(x, c.y - 70, 76, 26)
		draw_rect(rect, Color(ch[1], 0.9))
		draw_string(font, Vector2(rect.position.x, rect.position.y + 20), ch[0], HORIZONTAL_ALIGNMENT_CENTER, 76, 17, Color("#2b2d42"))
		x += 84.0
