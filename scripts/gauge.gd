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
	custom_minimum_size = Vector2(260, 268)


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
	var gt := car.gear_text()
	draw_string(font, Vector2(c.x - 70, c.y + (26 if gt.length() < 3 else 16)), gt, HORIZONTAL_ALIGNMENT_CENTER, 140, 76 if gt.length() < 3 else 44, CREAM if gt != "OFF" else CORAL)
	var kmh := "%d" % int(absf(car.fwd_speed) * 3.6)
	draw_string(font, Vector2(c.x - 60, c.y + 74), kmh, HORIZONTAL_ALIGNMENT_CENTER, 120, 34, CREAM)
	draw_string(font, Vector2(c.x - 60, c.y + 98), "km/h", HORIZONTAL_ALIGNMENT_CENTER, 120, 18, Color(CREAM, 0.75))
	var chips: Array = []
	if car.low_range:
		chips.append(["LOW", Color("#f6bd60")])
	if car.awd_on and car.spec["awd"] == "switchable":
		chips.append(["AWD", Color("#9ed9c5")])
	if car.diff_locked:
		chips.append(["DIFF", Color("#f28482")])
	if car.manual_clutch() and car.clutch < 0.5:
		chips.append(["CL", Color("#8ecae6")])
	if car.parking:
		chips.append(["P", Color("#f28482")])
	chips.append(["AUTO" if car.is_auto() else "MAN", Color("#b8a1e3")])
	var cw := 56.0 if chips.size() < 5 else 44.0
	var x := c.x - (chips.size() * (cw + 6.0) - 6.0) * 0.5
	for ch in chips:
		var rect := Rect2(x, c.y - 72, cw, 24)
		draw_rect(rect, Color(ch[1], 0.92))
		draw_string(font, Vector2(rect.position.x, rect.position.y + 18), ch[0], HORIZONTAL_ALIGNMENT_CENTER, cw, 15, Color("#2b2d42"))
		x += cw + 6.0
	# Fuel.
	var fr := car.fuel_ratio()
	var bar := Rect2(c.x - 90, c.y + 128, 180, 12)
	draw_rect(bar, Color(1, 1, 1, 0.16))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * fr, bar.size.y)), CORAL if fr < 0.2 else Color("#f6bd60"))
	draw_texture_rect(Icons.tex("local_gas_station", 36), Rect2(c.x - 90, c.y + 106, 18, 18), false, Color(CREAM, 0.85))
	draw_string(font, Vector2(c.x - 68, c.y + 122), "%d L" % int(car.fuel), HORIZONTAL_ALIGNMENT_LEFT, 160, 15, Color(CREAM, 0.8))
	if car.lights_mode > 0:
		draw_texture_rect(Icons.tex("highlight", 36), Rect2(c.x + 50, c.y + 104, 20, 20), false, Color("#fff3c4") if car.lights_mode == 1 else Color("#8ecae6"))
	if car.hazards:
		draw_texture_rect(Icons.tex("warning", 36), Rect2(c.x + 72, c.y + 104, 20, 20), false, Color("#ffb347"))
