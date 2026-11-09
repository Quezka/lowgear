class_name Compass
extends Control
## Heading strip at the top of the screen with pins for undiscovered viewpoints.

const SPAN := 1.2  # radians from the centre to each edge

var cam: Camera3D
var feats: Collectibles
var _sb: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sb = StyleBoxFlat.new()
	_sb.bg_color = Color(0.17, 0.18, 0.26, 0.55)
	_sb.set_corner_radius_all(14)


func _x(ang: float, heading: float) -> float:
	var diff := wrapf(ang - heading, -PI, PI)
	if absf(diff) > SPAN:
		return -1.0
	return size.x * 0.5 + diff / SPAN * (size.x * 0.5 - 16.0)


func _draw() -> void:
	if not cam or not cam.is_inside_tree():
		return
	_sb.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
	var f := -cam.global_transform.basis.z
	var heading := atan2(f.x, -f.z)
	var font := ThemeDB.fallback_font
	var cream := Color("#fff8f0")
	var dark := Color("#2b2d42")
	var h := size.y
	for k in 12:
		var x := _x(k * TAU / 12.0, heading)
		if x < 0.0:
			continue
		if k % 3 == 0:
			var txt: String = ["N", "E", "S", "W"][k / 3]
			draw_string(font, Vector2(x - 20, h * 0.5 + 10), txt, HORIZONTAL_ALIGNMENT_CENTER, 40, 28, cream)
		else:
			draw_line(Vector2(x, h * 0.3), Vector2(x, h * 0.7), Color(1, 1, 1, 0.6), 2.0)
	draw_line(Vector2(size.x * 0.5, 2), Vector2(size.x * 0.5, 10), cream, 3.0)
	if not feats:
		return
	var label_lm: Dictionary = {}
	var label_diff := 0.22
	for lm in feats.landmarks:
		if lm["found"]:
			continue
		var dd: Vector3 = (lm["pos"] as Vector3) - cam.global_position
		var df := absf(wrapf(atan2(dd.x, -dd.z) - heading, -PI, PI))
		if df < label_diff:
			label_diff = df
			label_lm = lm
	for lm in feats.landmarks:
		if lm["found"]:
			continue
		var p: Vector3 = lm["pos"]
		var d := p - cam.global_position
		var ang := atan2(d.x, -d.z)
		var x := _x(ang, heading)
		if x < 0.0:
			continue
		var c: Color = lm["color"]
		draw_circle(Vector2(x, h * 0.5), 11.0, dark)
		draw_circle(Vector2(x, h * 0.5), 8.0, c)
		if lm == label_lm:
			var txt := "%s  %d m" % [lm["name"], int(Vector2(d.x, d.z).length())]
			var pos := Vector2(x - 180, h + 30)
			draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_CENTER, 360, 24, 8, dark)
			draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_CENTER, 360, 24, cream)
