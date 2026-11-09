class_name MapScreen
extends CanvasLayer
## Full-screen map: shaded terrain, fog of war, places, you and your friends, jobs.
## Click/tap the map to set a waypoint (shown on the compass).

const FOG_N := 64

var terrain: Terrain
var sites: Sites
var feats: Collectibles
var car: Car
var remotes: Dictionary = {}

var _map: TextureRect
var _fog_img: Image
var _fog_tex: ImageTexture
var _fog: TextureRect
var _overlay: Control
var _jobs: VBoxContainer
var _fog_dirty := false
var _fog_t := 0.0


func setup() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.13, 0.13, 0.19, 0.92)
	add_child(bg)
	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 24)
	root.theme = GameState.ui_theme()
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 24)
	add_child(m)
	m.add_child(root)
	var side := get_viewport().get_visible_rect().size.y - 48.0
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(side, side)
	root.add_child(holder)
	_map = TextureRect.new()
	_map.texture = ImageTexture.create_from_image(_render())
	_map.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map.gui_input.connect(_on_map_input)
	holder.add_child(_map)
	_fog_img = Image.create(FOG_N, FOG_N, false, Image.FORMAT_RGBA8)
	_load_fog()
	_fog_tex = ImageTexture.create_from_image(_fog_img)
	_fog = TextureRect.new()
	_fog.texture = _fog_tex
	_fog.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fog.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fog.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_fog)
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	holder.add_child(_overlay)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	root.add_child(right)
	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", 10)
	right.add_child(title)
	title.add_child(Icons.rect("assignment", 34))
	var tl := Label.new()
	tl.text = "Jobs"
	tl.label_settings = GameState.label_settings(34)
	title.add_child(tl)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(sc)
	_jobs = VBoxContainer.new()
	_jobs.add_theme_constant_override("separation", 10)
	_jobs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_jobs)
	var close := Button.new()
	close.text = "Back to driving"
	close.icon = Icons.tex("close", 64)
	close.pressed.connect(toggle)
	right.add_child(close)


func _render() -> Image:
	var n := 512
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var light := Vector3(-0.5, 0.75, -0.4).normalized()
	for j in n:
		for i in n:
			var x := -Terrain.HALF + (i + 0.5) * 2.0 * Terrain.HALF / n
			var z := -Terrain.HALF + (j + 0.5) * 2.0 * Terrain.HALF / n
			var h := terrain.get_height(x, z)
			var c: Color
			if h < 0.0:
				c = Color("#5f8fb5").lerp(Color("#8fc4d6"), clampf(1.0 + h / 5.0, 0.0, 1.0))
			else:
				match terrain.surface_at(x, z):
					Terrain.Surface.SAND: c = Color("#e2cf9f")
					Terrain.Surface.ROCK: c = Color("#a59fb0")
					Terrain.Surface.SNOW: c = Color("#f4f2f6")
					Terrain.Surface.MUD: c = Color("#6e5a45")
					Terrain.Surface.GRAVEL: c = Color("#d8c9b0")
					_: c = Color("#8dbb7e").lerp(Color("#c3cf8f"), clampf(h / 60.0, 0.0, 1.0))
				var shade := clampf(terrain.get_normal(x, z).dot(light) * 1.25, 0.45, 1.15)
				c = Color(c.r * shade, c.g * shade, c.b * shade)
			img.set_pixel(i, j, c)
	return img


func _load_fog() -> void:
	_fog_img.fill(Color(0.13, 0.13, 0.19, 0.82))
	var saved := str(GameState.map_state().get("fog", ""))
	if saved.length() == FOG_N * FOG_N:
		for k in saved.length():
			if saved[k] == "1":
				_fog_img.set_pixel(k % FOG_N, k / FOG_N, Color(0, 0, 0, 0))


func _save_fog() -> void:
	var s := ""
	for j in FOG_N:
		for i in FOG_N:
			s += "1" if _fog_img.get_pixel(i, j).a < 0.5 else "0"
	GameState.map_state()["fog"] = s


## Clears fog within r metres of a point.
func reveal(p: Vector3, r: float) -> void:
	var cell := 2.0 * Terrain.HALF / FOG_N
	var ci := int((p.x + Terrain.HALF) / cell)
	var cj := int((p.z + Terrain.HALF) / cell)
	var k := int(ceil(r / cell))
	for j in range(cj - k, cj + k + 1):
		for i in range(ci - k, ci + k + 1):
			if i < 0 or j < 0 or i >= FOG_N or j >= FOG_N:
				continue
			if Vector2(i - ci, j - cj).length() * cell <= r and _fog_img.get_pixel(i, j).a > 0.0:
				_fog_img.set_pixel(i, j, Color(0, 0, 0, 0))
				_fog_dirty = true


func _process(delta: float) -> void:
	if not car:
		return
	_fog_t += delta
	if _fog_t > 0.5:
		_fog_t = 0.0
		reveal(car.global_position, 130.0)
		if sites and sites.reveal_all:
			reveal(Vector3.ZERO, Terrain.HALF * 2.0)
		if _fog_dirty:
			_fog_dirty = false
			_fog_tex.update(_fog_img)
			_save_fog()
	if visible:
		_overlay.queue_redraw()


func _to_map(p: Vector3) -> Vector2:
	var s := _overlay.size
	return Vector2((p.x + Terrain.HALF) / (2.0 * Terrain.HALF) * s.x, (p.z + Terrain.HALF) / (2.0 * Terrain.HALF) * s.y)


func _draw_overlay() -> void:
	var font := ThemeDB.fallback_font
	var dark := Color("#2b2d42")
	var known := func(p: Vector3) -> bool:
		var cell := 2.0 * Terrain.HALF / FOG_N
		var i := clampi(int((p.x + Terrain.HALF) / cell), 0, FOG_N - 1)
		var j := clampi(int((p.z + Terrain.HALF) / cell), 0, FOG_N - 1)
		return _fog_img.get_pixel(i, j).a < 0.5
	var job_sites := {}
	for c in sites.active_contracts():
		job_sites[c["site"]] = true
	for id in sites.sites:
		var s: Dictionary = sites.sites[id]
		if not known.call(s["pos"]) and id != "garage":
			continue
		var at := _to_map(s["pos"])
		var col := Color("#f6bd60") if job_sites.has(id) else Color("#fff8f0")
		_overlay.draw_circle(at, 17.0, dark)
		_overlay.draw_texture_rect(Icons.tex(s["icon"], 48), Rect2(at - Vector2(12, 12), Vector2(24, 24)), false, col)
		_overlay.draw_string_outline(font, at + Vector2(-70, 34), s["name"], HORIZONTAL_ALIGNMENT_CENTER, 140, 16, 6, dark)
		_overlay.draw_string(font, at + Vector2(-70, 34), s["name"], HORIZONTAL_ALIGNMENT_CENTER, 140, 16, Color("#fff8f0"))
	for st in feats.stations:
		if known.call(st["pos"]):
			var at := _to_map(st["pos"])
			_overlay.draw_circle(at, 13.0, dark)
			_overlay.draw_texture_rect(Icons.tex("local_gas_station", 40), Rect2(at - Vector2(9, 9), Vector2(18, 18)), false, Color("#f28482"))
	for lm in feats.landmarks:
		if known.call(lm["pos"]):
			_overlay.draw_circle(_to_map(lm["pos"]), 7.0, lm["color"])
	if GameState.waypoint != Vector3.INF:
		var at := _to_map(GameState.waypoint)
		_overlay.draw_texture_rect(Icons.tex("person_pin_circle", 64), Rect2(at - Vector2(16, 30), Vector2(32, 32)), false, Color("#8ecae6"))
	for id in remotes:
		var rc: Node3D = remotes[id]
		_overlay.draw_circle(_to_map(rc.global_position), 9.0, Net.player_color(id))
	var me := _to_map(car.global_position)
	var f := car.global_transform.basis.z
	_overlay.draw_set_transform(me, atan2(f.x, -f.z) + PI, Vector2.ONE)
	_overlay.draw_texture_rect(Icons.tex("navigation", 64), Rect2(Vector2(-16, -16), Vector2(32, 32)), false, Color("#ff8fab"))
	_overlay.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _on_map_input(event: InputEvent) -> void:
	var press := (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if not press:
		return
	var pos: Vector2 = event.position
	var s := _map.size
	var p := Vector3(pos.x / s.x * 2.0 * Terrain.HALF - Terrain.HALF, 0, pos.y / s.y * 2.0 * Terrain.HALF - Terrain.HALF)
	p.y = terrain.get_height(p.x, p.z)
	GameState.waypoint = p
	_overlay.queue_redraw()


func _refresh_jobs() -> void:
	for c in _jobs.get_children():
		c.queue_free()
	for c in sites.active_contracts():
		var card := PanelContainer.new()
		_jobs.add_child(card)
		var v := VBoxContainer.new()
		card.add_child(v)
		var t := Label.new()
		t.text = c["title"]
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.label_settings = GameState.label_settings(22, true)
		v.add_child(t)
		var need := sites.remaining(c)
		var parts: Array = []
		for k in c["needs"]:
			parts.append("%s %d/%d" % [Cargo.type_name(k), int(c["needs"][k]) - int(need.get(k, 0)), int(c["needs"][k])])
		var site: Dictionary = sites.sites[c["site"]]
		var d := Label.new()
		d.text = "%s  →  %s\nReward $%d, %d XP" % [", ".join(parts), site["name"], int(c["cash"]), int(c["xp"])]
		d.label_settings = GameState.label_settings(18, true, GameState.MUTED)
		v.add_child(d)
		var go := Button.new()
		go.text = "Set waypoint"
		go.icon = Icons.tex("flag", 48)
		go.add_theme_font_size_override("font_size", 18)
		go.pressed.connect(func() -> void:
			GameState.waypoint = site["pos"]
			_overlay.queue_redraw())
		v.add_child(go)
	var tip := Label.new()
	tip.text = "Load cargo at the warehouse, sawmill or logging camp (T), then drive it to the job's site and press T again. Logs need the Timberline."
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.label_settings = GameState.label_settings(18, false, Color("#fff8f0"))
	_jobs.add_child(tip)


func toggle() -> void:
	visible = not visible
	GameState.ui_open = visible
	if visible:
		_refresh_jobs()
		_overlay.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map") or (visible and event.is_action_pressed("pause")):
		toggle()
		get_viewport().set_input_as_handled()
