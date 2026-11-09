class_name Terrain
extends Node3D
## Procedural 1 km island: heightfield on a 4 m grid, flat-shaded chunks with trimesh collision.

const HALF := 512.0
const CELL := 4.0
const N := 256
const CHUNK := 32
const CHUNKS := 8
const SEA_FLOOR := -7.0

const SAND := Color("#ecd3a2")
const WET_SAND := Color("#d9c9a6")
const ROCK := Color("#a99bc0")
const SNOW := Color("#f8f1f4")
const GRASS_A := Color("#8fc98a")
const GRASS_B := Color("#b2d98c")
const MEADOW := Color("#cfd197")

var heights := PackedFloat32Array()
var spawn_transform := Transform3D.IDENTITY

var _base := FastNoiseLite.new()
var _ridge := FastNoiseLite.new()
var _warp := FastNoiseLite.new()
var _bumps := FastNoiseLite.new()
var _tint := FastNoiseLite.new()
var _material: StandardMaterial3D
# Chunk build buffers (members so helpers can append to them).
var _v := PackedVector3Array()
var _n := PackedVector3Array()
var _c := PackedColorArray()


func generate(seed_value := 1337) -> void:
	_setup_noise(seed_value)
	heights.resize((N + 1) * (N + 1))
	for j in N + 1:
		var z := -HALF + j * CELL
		for i in N + 1:
			heights[j * (N + 1) + i] = _raw_height(-HALF + i * CELL, z)
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.vertex_color_is_srgb = true
	_material.roughness = 1.0
	_material.metallic_specular = 0.1
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for cz in CHUNKS:
		for cx in CHUNKS:
			_build_chunk(cx, cz)
	_find_spawn()


func _setup_noise(s: int) -> void:
	_base.seed = s
	_base.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_base.frequency = 0.0036
	_base.fractal_type = FastNoiseLite.FRACTAL_FBM
	_base.fractal_octaves = 4
	_ridge.seed = s + 1
	_ridge.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ridge.frequency = 0.0026
	_ridge.fractal_octaves = 3
	_warp.seed = s + 2
	_warp.frequency = 0.006
	_warp.fractal_octaves = 2
	_bumps.seed = s + 3
	_bumps.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_bumps.frequency = 0.045
	_bumps.fractal_type = FastNoiseLite.FRACTAL_NONE
	_tint.seed = s + 4
	_tint.frequency = 0.02


func _raw_height(x: float, z: float) -> float:
	var d := Vector2(x, z).length() / HALF + _warp.get_noise_2d(x, z) * 0.18
	var mask := 1.0 - smoothstep(0.62, 0.93, d)
	var base := clampf(_base.get_noise_2d(x, z) * 0.75 + 0.5, 0.0, 1.0)
	var hills := pow(base, 1.7) * 44.0
	var r := 1.0 - absf(_ridge.get_noise_2d(x, z))
	var ridge := pow(r, 3.0) * 22.0 * (1.0 - smoothstep(0.2, 0.75, d))
	var bumps := _bumps.get_noise_2d(x, z) * 1.6
	var land := 5.0 + hills + ridge + bumps
	return lerpf(SEA_FLOOR, land, mask)


func _vtx(i: int, j: int) -> Vector3:
	return Vector3(-HALF + i * CELL, heights[j * (N + 1) + i], -HALF + j * CELL)


func _build_chunk(cx: int, cz: int) -> void:
	_v = PackedVector3Array()
	_n = PackedVector3Array()
	_c = PackedColorArray()
	var i0 := cx * CHUNK
	var j0 := cz * CHUNK
	for j in range(j0, j0 + CHUNK):
		for i in range(i0, i0 + CHUNK):
			var a := _vtx(i, j)
			var b := _vtx(i + 1, j)
			var c := _vtx(i, j + 1)
			var d := _vtx(i + 1, j + 1)
			_tri(a, b, d)
			_tri(a, d, c)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _v
	arrays[Mesh.ARRAY_NORMAL] = _n
	arrays[Mesh.ARRAY_COLOR] = _c
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _material
	mi.visibility_range_end = 600.0
	add_child(mi)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(_v)
	cs.shape = shape
	body.add_child(cs)
	add_child(body)


func _tri(a: Vector3, b: Vector3, d: Vector3) -> void:
	var nn := (b - a).cross(d - a).normalized()
	if nn.y < 0.0:
		nn = -nn
	var cen := (a + b + d) / 3.0
	var col := _color(cen.y, nn.y, cen.x, cen.z)
	_v.append(a)
	_v.append(b)
	_v.append(d)
	for k in 3:
		_n.append(nn)
		_c.append(col)


func _color(h: float, ny: float, x: float, z: float) -> Color:
	var c: Color
	if h < -0.4:
		c = WET_SAND
	elif h < 1.4:
		c = SAND
	elif ny < 0.72:
		c = ROCK
	elif h > 58.0 and ny > 0.8:
		c = SNOW
	else:
		c = GRASS_A.lerp(GRASS_B, _tint.get_noise_2d(x, z) * 0.5 + 0.5)
		if h > 32.0:
			c = c.lerp(MEADOW, clampf((h - 32.0) / 22.0, 0.0, 1.0))
		if ny < 0.82:
			c = c.lerp(ROCK, clampf((0.82 - ny) / 0.1, 0.0, 1.0) * 0.6)
	var j := (fposmod(sin(x * 12.9898 + z * 78.233) * 43758.5453, 1.0) - 0.5) * 0.05
	return Color(c.r + j, c.g + j, c.b + j)


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


func _find_spawn() -> void:
	var z := HALF * 0.95
	while z > 0.0 and get_height(0.0, z) < 3.0:
		z -= 2.0
	z -= 12.0
	var tries := 0
	while tries < 60 and get_normal(0.0, z).y < 0.97:
		z -= 2.0
		tries += 1
	var h := get_height(0.0, z)
	# Cars face +Z; turn around so we look inland.
	spawn_transform = Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, h + 1.2, z))
