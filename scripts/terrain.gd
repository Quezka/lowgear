class_name Terrain
extends Node3D
## Island terrain v2: 2 m heightfield, smooth shading, textured layers from a splat map,
## 64 m chunks with 3 levels of detail, gravel tracks found by A* over the slopes.
## Order: generate_heights() -> (landmarks get placed) -> add_tracks() -> build().

const HALF := 512.0
const CELL := 2.0
const N := 512                 # cells per side
const CHUNK := 32              # cells per chunk side (64 m)
const CHUNKS := 16
const SEA_FLOOR := -7.0
const SNOW_LINE := 52.0
const SPLAT := 512             # splat pixels per side (2 m each, one per grid cell)
const LAYERS := ["meadow", "sand", "gravel", "rock", "snow", "dirt"]

enum Surface { GRASS, SAND, ROCK, SNOW, WATER, MUD, GRAVEL }

var heights := PackedFloat32Array()
var spawn_transform := Transform3D.IDENTITY
var splat_img: Image
var tracks: Array = []         ## Array of PackedVector3Array polylines
var quality := 1

var _base := FastNoiseLite.new()
var _ridge := FastNoiseLite.new()
var _warp := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _patch := FastNoiseLite.new()
var _material: ShaderMaterial
var _normals := PackedVector3Array()


# --- heights ---------------------------------------------------------------------

func generate_heights(seed_value := 1337) -> void:
	_setup_noise(seed_value)
	var w := N + 1
	heights.resize(w * w)
	for j in w:
		var z := -HALF + j * CELL
		for i in w:
			heights[j * w + i] = _raw_height(-HALF + i * CELL, z)
	_find_spawn()


func _setup_noise(s: int) -> void:
	_base.seed = s
	_base.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_base.frequency = 0.0034
	_base.fractal_type = FastNoiseLite.FRACTAL_FBM
	_base.fractal_octaves = 5
	_ridge.seed = s + 1
	_ridge.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ridge.frequency = 0.0021
	_ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_ridge.fractal_octaves = 4
	_warp.seed = s + 2
	_warp.frequency = 0.006
	_warp.fractal_octaves = 2
	_detail.seed = s + 3
	_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_detail.frequency = 0.03
	_detail.fractal_octaves = 2
	_patch.seed = s + 4
	_patch.frequency = 0.02
	_patch.fractal_octaves = 3


func _raw_height(x: float, z: float) -> float:
	var d := Vector2(x, z).length() / HALF + _warp.get_noise_2d(x, z) * 0.18
	var mask := 1.0 - smoothstep(0.6, 0.93, d)
	var base := clampf(_base.get_noise_2d(x, z) * 0.75 + 0.5, 0.0, 1.0)
	var hills := pow(base, 1.6) * 44.0
	var ridge := clampf(_ridge.get_noise_2d(x, z) * 0.5 + 0.5, 0.0, 1.0)
	var mountains := pow(ridge, 2.2) * 30.0 * (1.0 - smoothstep(0.15, 0.7, d))
	var land := 4.5 + hills + mountains + _detail.get_noise_2d(x, z) * 0.7
	return lerpf(SEA_FLOOR, land, mask)


func _h(i: int, j: int) -> float:
	i = clampi(i, 0, N)
	j = clampi(j, 0, N)
	return heights[j * (N + 1) + i]


## Exact height of the rendered/collision surface at (x, z).
func get_height(x: float, z: float) -> float:
	var gx := (x + HALF) / CELL
	var gz := (z + HALF) / CELL
	if gx < 0.0 or gz < 0.0 or gx >= N or gz >= N:
		return SEA_FLOOR
	var i := int(gx)
	var j := int(gz)
	var fx := gx - i
	var fz := gz - j
	var w := N + 1
	var ha := heights[j * w + i]
	var hb := heights[j * w + i + 1]
	var hc := heights[(j + 1) * w + i]
	var hd := heights[(j + 1) * w + i + 1]
	if fx >= fz:
		return ha + (hb - ha) * fx + (hd - hb) * fz
	return ha + (hc - ha) * fz + (hd - hc) * fx


func get_normal(x: float, z: float) -> Vector3:
	var e := 2.0
	var hl := get_height(x - e, z)
	var hr := get_height(x + e, z)
	var hd := get_height(x, z - e)
	var hu := get_height(x, z + e)
	return Vector3((hl - hr) / (2.0 * e), 1.0, (hd - hu) / (2.0 * e)).normalized()


func surface_at(x: float, z: float) -> int:
	if get_height(x, z) < 0.05:
		return Surface.WATER
	if not splat_img:
		return Surface.GRASS
	var px := clampi(int((x + HALF) / (2.0 * HALF) * SPLAT), 0, SPLAT - 1)
	var pz := clampi(int((z + HALF) / (2.0 * HALF) * SPLAT), 0, SPLAT - 1)
	var c := splat_img.get_pixel(px, pz)
	var best := 1.0 - (c.r + c.g + c.b + c.a)
	var s: int = Surface.GRASS
	for k in [[c.r, Surface.SAND], [c.g, Surface.GRAVEL], [c.b, Surface.ROCK], [c.a, Surface.SNOW]]:
		if float(k[0]) > best:
			best = k[0]
			s = k[1]
	return s


## 0..1 how much meadow (grass) there is at a point, for the grass field and trees.
func meadow_at(x: float, z: float) -> float:
	if not splat_img:
		return 1.0
	var px := clampi(int((x + HALF) / (2.0 * HALF) * SPLAT), 0, SPLAT - 1)
	var pz := clampi(int((z + HALF) / (2.0 * HALF) * SPLAT), 0, SPLAT - 1)
	var c := splat_img.get_pixel(px, pz)
	return clampf(1.0 - (c.r + c.g + c.b + c.a), 0.0, 1.0)


func _find_spawn() -> void:
	var z := HALF * 0.95
	while z > 0.0 and get_height(0.0, z) < 3.0:
		z -= 2.0
	z -= 14.0
	var tries := 0
	while tries < 60 and get_normal(0.0, z).y < 0.97:
		z -= 2.0
		tries += 1
	spawn_transform = Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, get_height(0.0, z) + 1.2, z))


# --- tracks ------------------------------------------------------------------

## Finds gentle gravel tracks from the spawn to each target and flattens the ground under them.
func add_tracks(targets: Array) -> void:
	var grid := AStarGrid2D.new()
	var step := 16.0
	var cells := int(2.0 * HALF / step)
	grid.region = Rect2i(0, 0, cells, cells)
	grid.cell_size = Vector2(1, 1)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	grid.update()
	for cz in cells:
		for cx in cells:
			var x := -HALF + (cx + 0.5) * step
			var z := -HALF + (cz + 0.5) * step
			if get_height(x, z) < 1.2:
				grid.set_point_solid(Vector2i(cx, cz), true)
				continue
			var slope := 1.0 - get_normal(x, z).y
			grid.set_point_weight_scale(Vector2i(cx, cz), 1.0 + slope * 60.0)
	var from := _cell(spawn_transform.origin, step, cells)
	for t in targets:
		var to := _cell(t as Vector3, step, cells)
		if grid.is_point_solid(from) or grid.is_point_solid(to):
			continue
		var path := grid.get_id_path(from, to)
		if path.size() < 3:
			continue
		var pts := PackedVector3Array()
		for p in path:
			pts.append(Vector3(-HALF + (p.x + 0.5) * step, 0, -HALF + (p.y + 0.5) * step))
		pts = _smooth(pts, 3)
		for k in pts.size():
			pts[k].y = get_height(pts[k].x, pts[k].z)
		tracks.append(pts)
	_flatten_tracks()


func _cell(p: Vector3, step: float, cells: int) -> Vector2i:
	return Vector2i(clampi(int((p.x + HALF) / step), 0, cells - 1), clampi(int((p.z + HALF) / step), 0, cells - 1))


## Chaikin corner cutting.
func _smooth(pts: PackedVector3Array, rounds: int) -> PackedVector3Array:
	for r in rounds:
		var out := PackedVector3Array()
		out.append(pts[0])
		for i in pts.size() - 1:
			out.append(pts[i].lerp(pts[i + 1], 0.25))
			out.append(pts[i].lerp(pts[i + 1], 0.75))
		out.append(pts[pts.size() - 1])
		pts = out
	return pts


func _flatten_tracks() -> void:
	for t in tracks.size():
		var pts: PackedVector3Array = tracks[t]
		var prof := PackedFloat32Array()
		prof.resize(pts.size())
		for k in pts.size():
			var acc := 0.0
			var n := 0
			for m in range(maxi(0, k - 4), mini(pts.size(), k + 5)):
				acc += pts[m].y
				n += 1
			prof[k] = acc / n
		for k in pts.size():
			var p := pts[k]
			var i0 := int((p.x + HALF) / CELL)
			var j0 := int((p.z + HALF) / CELL)
			for j in range(j0 - 3, j0 + 4):
				for i in range(i0 - 3, i0 + 4):
					if i < 0 or j < 0 or i > N or j > N:
						continue
					var d := Vector2(-HALF + i * CELL - p.x, -HALF + j * CELL - p.z).length()
					if d > 5.0:
						continue
					var f := 1.0 - smoothstep(2.5, 5.0, d)
					var idx := j * (N + 1) + i
					heights[idx] = lerpf(heights[idx], prof[k] - 0.05, f * 0.8)
			pts[k].y = prof[k]
		tracks[t] = pts


# --- splat ---------------------------------------------------------------------

func _build_splat() -> void:
	splat_img = Image.create(SPLAT, SPLAT, false, Image.FORMAT_RGBA8)
	var mpp := 2.0 * HALF / SPLAT
	for pz in SPLAT:
		var z := -HALF + (pz + 0.5) * mpp
		for px in SPLAT:
			var x := -HALF + (px + 0.5) * mpp
			var gi := mini(px, N)
			var gj := mini(pz, N)
			var h := heights[gj * (N + 1) + gi]
			var ny := _normals[gj * (N + 1) + gi].y
			var n := _patch.get_noise_2d(x, z)
			var sand := 1.0 - smoothstep(1.2, 2.4 + n * 0.8, h)
			var rock := smoothstep(0.86 + n * 0.03, 0.74, ny)
			var snow := smoothstep(SNOW_LINE - 4.0, SNOW_LINE + 4.0, h + n * 6.0) * smoothstep(0.72, 0.82, ny)
			rock *= 1.0 - snow
			sand *= 1.0 - rock
			splat_img.set_pixel(px, pz, Color(sand, 0.0, rock, snow))
	for pts in tracks:
		_paint_track(pts, mpp)


func _paint_track(pts: PackedVector3Array, mpp: float) -> void:
	var half_w := 2.4
	for k in pts.size() - 1:
		var a := Vector2(pts[k].x, pts[k].z)
		var b := Vector2(pts[k + 1].x, pts[k + 1].z)
		var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2.ONE * (half_w + 2.0)
		var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2.ONE * (half_w + 2.0)
		for pz in range(int((lo.y + HALF) / mpp), int((hi.y + HALF) / mpp) + 1):
			for px in range(int((lo.x + HALF) / mpp), int((hi.x + HALF) / mpp) + 1):
				if px < 0 or pz < 0 or px >= SPLAT or pz >= SPLAT:
					continue
				var p := Vector2(-HALF + (px + 0.5) * mpp, -HALF + (pz + 0.5) * mpp)
				var d := Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p)
				var g := 1.0 - smoothstep(half_w - 0.8, half_w + 1.2, d + _patch.get_noise_2d(p.x * 3.0, p.y * 3.0) * 0.6)
				if g <= 0.0:
					continue
				var c := splat_img.get_pixel(px, pz)
				if g > c.g:
					var keep := 1.0 - g
					splat_img.set_pixel(px, pz, Color(c.r * keep, g, c.b * keep, c.a * keep))


# --- meshes ---------------------------------------------------------------------

func build(q := 1) -> void:
	quality = q
	var t0 := Time.get_ticks_msec()
	_compute_normals()
	_build_splat()
	print("[terrain] splat+normals %d ms" % (Time.get_ticks_msec() - t0))
	_material = _make_material()
	t0 = Time.get_ticks_msec()
	for cz in CHUNKS:
		for cx in CHUNKS:
			_build_chunk(cx, cz)
	print("[terrain] chunks %d ms" % (Time.get_ticks_msec() - t0))


func _compute_normals() -> void:
	var w := N + 1
	_normals.resize(w * w)
	for j in w:
		for i in w:
			_normals[j * w + i] = Vector3(_h(i - 1, j) - _h(i + 1, j), 2.0 * CELL, _h(i, j - 1) - _h(i, j + 1)).normalized()


func _make_material() -> ShaderMaterial:
	var size := 512 if quality == 0 else 1024
	var albedo: Array[Image] = []
	var normal: Array[Image] = []
	for l in LAYERS:
		albedo.append(_layer_image("res://assets/cc0/terrain/%s_color.jpg" % l, size))
		normal.append(_layer_image("res://assets/cc0/terrain/%s_normal.jpg" % l, size))
	var alb := Texture2DArray.new()
	alb.create_from_images(albedo)
	var nor := Texture2DArray.new()
	nor.create_from_images(normal)
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/terrain.gdshader")
	m.set_shader_parameter("albedo_tex", alb)
	m.set_shader_parameter("normal_tex", nor)
	m.set_shader_parameter("splat", ImageTexture.create_from_image(splat_img))
	m.set_shader_parameter("map_half", HALF)
	m.set_shader_parameter("use_normals", quality > 0)
	var macro := NoiseTexture2D.new()
	macro.width = 256
	macro.height = 256
	macro.seamless = true
	var fn := FastNoiseLite.new()
	fn.frequency = 0.02
	fn.fractal_octaves = 3
	macro.noise = fn
	m.set_shader_parameter("macro", macro)
	return m


static func _layer_image(path: String, size: int) -> Image:
	var img := (load(path) as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	if img.get_width() != size:
		img.resize(size, size, Image.INTERPOLATE_LANCZOS)
	img.generate_mipmaps()
	return img


func _build_chunk(cx: int, cz: int) -> void:
	var lods := [[1, 0.0, 200.0], [2, 185.0, 430.0], [4, 410.0, 0.0]]
	for lod in lods:
		var mi := MeshInstance3D.new()
		mi.mesh = _chunk_mesh(cx, cz, int(lod[0]))
		mi.material_override = _material
		mi.visibility_range_begin = lod[1]
		mi.visibility_range_end = lod[2]
		mi.visibility_range_begin_margin = 10.0
		mi.visibility_range_end_margin = 10.0
		if int(lod[0]) > 1:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	var faces := PackedVector3Array()
	var w := N + 1
	for j in range(cz * CHUNK, (cz + 1) * CHUNK):
		for i in range(cx * CHUNK, (cx + 1) * CHUNK):
			var a := Vector3(-HALF + i * CELL, heights[j * w + i], -HALF + j * CELL)
			var b := Vector3(a.x + CELL, heights[j * w + i + 1], a.z)
			var c := Vector3(a.x, heights[(j + 1) * w + i], a.z + CELL)
			var d := Vector3(a.x + CELL, heights[(j + 1) * w + i + 1], a.z + CELL)
			faces.append_array([a, b, d, a, d, c])
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	cs.shape = shape
	body.add_child(cs)
	add_child(body)


func _chunk_mesh(cx: int, cz: int, step: int) -> ArrayMesh:
	var w := N + 1
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	var n := CHUNK / step + 1
	for jj in n:
		for ii in n:
			var i := cx * CHUNK + ii * step
			var j := cz * CHUNK + jj * step
			verts.append(Vector3(-HALF + i * CELL, heights[j * w + i], -HALF + j * CELL))
			norms.append(_normals[j * w + i])
	for jj in n - 1:
		for ii in n - 1:
			var a := jj * n + ii
			idx.append_array([a, a + 1, a + n + 1, a, a + n + 1, a + n])
	# Skirts hide cracks between neighbouring chunks at different detail levels.
	var drop := 2.0 * step
	for edge in 4:
		var ring: Array = []
		for k in n:
			match edge:
				0: ring.append(k)
				1: ring.append((n - 1) * n + (n - 1 - k))
				2: ring.append((n - 1 - k) * n)
				3: ring.append(k * n + n - 1)
		var base := verts.size()
		for r in ring:
			verts.append(verts[r] - Vector3(0, drop, 0))
			norms.append(norms[r])
		for k in n - 1:
			var t0: int = ring[k]
			var t1: int = ring[k + 1]
			idx.append_array([t0, base + k, t1, t1, base + k, base + k + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


## Heights as a float texture, for the water shader (depth colour and shore foam).
func height_texture() -> ImageTexture:
	var img := Image.create_from_data(N + 1, N + 1, false, Image.FORMAT_RF, heights.to_byte_array())
	return ImageTexture.create_from_image(img)
