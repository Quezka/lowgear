class_name Props
extends Node3D
## Trees (textured cards near the camera, simple shapes far away), rocks, trunk collisions.

const BLOCK := 128.0
const FAR_END := 700.0
const CONIFER_AVG := Color(0.2, 0.3, 0.2)
const BROAD_AVG := Color(0.3, 0.42, 0.22)

static var _cache: Dictionary = {}

var near_dist := 160.0


# --- meshes (shared) -------------------------------------------------------------------

static func bark_mat() -> StandardMaterial3D:
	if _cache.has("bark"):
		return _cache["bark"]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/cc0/terrain/bark_color.jpg")
	m.normal_enabled = true
	m.normal_texture = load("res://assets/cc0/terrain/bark_normal.jpg")
	m.uv1_scale = Vector3(1.0, 3.0, 1.0)
	m.roughness = 0.95
	_cache["bark"] = m
	return m


static func foliage_mat(texture: String) -> ShaderMaterial:
	var key := "fol_" + texture
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/foliage.gdshader")
	m.set_shader_parameter("tex", load("res://assets/cc0/foliage/%s.png" % texture))
	_cache[key] = m
	return m


static func rock_mat() -> StandardMaterial3D:
	if _cache.has("rock"):
		return _cache["rock"]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/cc0/terrain/rock_color.jpg")
	m.normal_enabled = true
	m.normal_texture = load("res://assets/cc0/terrain/rock_normal.jpg")
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.6, 0.6, 0.6)
	m.roughness = 0.85
	m.vertex_color_use_as_albedo = true
	_cache["rock"] = m
	return m


static func _add_cylinder(m: ArrayMesh, top: float, bottom: float, height: float, y: float, mat: Material) -> void:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = 7
	c.rings = 2
	var arr := c.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	for i in v.size():
		v[i].y += y
	arr[Mesh.ARRAY_VERTEX] = v
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(m.get_surface_count() - 1, mat)


static func _cards_surface(m: ArrayMesh, quads: Array, mat: Material) -> void:
	## quads: [p0, p1, p2, p3, normal, shade] with UVs (0,0) (0,1) (1,1) (1,0) along base->tip.
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var idx := PackedInt32Array()
	for q in quads:
		var b := v.size()
		for k in 4:
			v.append(q[k])
			n.append(q[4])
			col.append(Color(q[5], q[5], q[5]))
		uv.append_array([Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)])
		idx.append_array([b, b + 1, b + 2, b, b + 2, b + 3])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_COLOR] = col
	arr[Mesh.ARRAY_INDEX] = idx
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(m.get_surface_count() - 1, mat)


static func conifer_mesh() -> ArrayMesh:
	if _cache.has("conifer"):
		return _cache["conifer"]
	var m := ArrayMesh.new()
	_add_cylinder(m, 0.05, 0.3, 9.6, 4.8, bark_mat())
	var quads: Array = []
	var tiers := 9
	for t in tiers:
		var f := float(t) / (tiers - 1)
		var y := lerpf(1.6, 9.0, f)
		var length := lerpf(2.7, 0.55, f)
		var droop := length * 0.45
		var width := length * 0.85
		for k in 6:
			var a := k * TAU / 6.0 + t * 0.52
			var dir := Vector3(cos(a), 0, sin(a))
			var side := Vector3(-sin(a), 0, cos(a)) * width * 0.5
			var base := Vector3(0, y, 0) + dir * 0.08
			var tip := base + dir * length + Vector3(0, -droop, 0)
			var nrm := (dir * 0.35 + Vector3.UP).normalized()
			quads.append([base - side, base + side, tip + side, tip - side, nrm, lerpf(0.7, 1.0, f)])
	for k in 3:
		var a := k * TAU / 3.0
		var dir := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-sin(a), 0, cos(a)) * 0.25
		var base := Vector3(0, 9.0, 0)
		var tip := base + dir * 0.3 + Vector3(0, 1.1, 0)
		quads.append([base - side, base + side, tip + side, tip - side, dir, 1.0])
	_cards_surface(m, quads, foliage_mat("conifer_branch"))
	var inner := LowPoly.cyl(0.0, 1.5, 7.6, 8)
	var arr := inner.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	for i in v.size():
		v[i].y += 5.4
	arr[Mesh.ARRAY_VERTEX] = v
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var im := StandardMaterial3D.new()
	im.albedo_color = Color(0.14, 0.22, 0.13)
	im.vertex_color_use_as_albedo = true
	im.roughness = 1.0
	m.surface_set_material(m.get_surface_count() - 1, im)
	_cache["conifer"] = m
	return m


static func broadleaf_mesh() -> ArrayMesh:
	if _cache.has("broadleaf"):
		return _cache["broadleaf"]
	var m := ArrayMesh.new()
	_add_cylinder(m, 0.12, 0.3, 5.0, 2.5, bark_mat())
	var quads: Array = []
	var count := 16
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var centre := Vector3(0, 5.4, 0)
	for k in count:
		# Fibonacci sphere, squashed into a crown.
		var yy := 1.0 - (k + 0.5) / count * 2.0
		var r := sqrt(1.0 - yy * yy)
		var th := k * 2.39996
		var dir := Vector3(cos(th) * r, yy * 0.8, sin(th) * r).normalized()
		var p := centre + Vector3(dir.x * 2.3, dir.y * 1.9, dir.z * 2.3)
		var s := rng.randf_range(1.3, 1.7)
		var t1 := dir.cross(Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT).normalized()
		var t2 := dir.cross(t1).normalized()
		var roll := rng.randf() * TAU
		var u := (t1 * cos(roll) + t2 * sin(roll)) * s
		var w := (t1 * -sin(roll) + t2 * cos(roll)) * s
		var shade := lerpf(0.6, 1.0, yy * 0.5 + 0.5)
		quads.append([p - u - w, p - u + w, p + u + w, p + u - w, dir, shade])
	_cards_surface(m, quads, foliage_mat("broadleaf_cluster"))
	_cache["broadleaf"] = m
	return m


static func far_conifer() -> Mesh:
	return _offset(LowPoly.cyl(0.0, 2.3, 8.6, 7), 5.2)


static func far_broadleaf() -> Mesh:
	var m := ArrayMesh.new()
	_add_cylinder(m, 0.12, 0.3, 5.0, 2.5, bark_mat())
	var s := LowPoly.sphere(2.5, 4.2, 8, 5)
	var arr := s.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	for i in v.size():
		v[i].y += 5.4
	arr[Mesh.ARRAY_VERTEX] = v
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(1, LowPoly.instance_mat())
	return m


static func _offset(src: PrimitiveMesh, y: float) -> ArrayMesh:
	var arr := src.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	for i in v.size():
		v[i].y += y
	arr[Mesh.ARRAY_VERTEX] = v
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, LowPoly.instance_mat())
	return m


static func rock_mesh(seed_value: int) -> ArrayMesh:
	var key := "rock%d" % seed_value
	if _cache.has(key):
		return _cache[key]
	var s := LowPoly.sphere(1.0, 1.5, 14, 8)
	var arr := s.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.9
	noise.fractal_octaves = 3
	for i in v.size():
		var p := v[i]
		var k := 1.0 + noise.get_noise_3d(p.x, p.y, p.z) * 0.35
		v[i] = Vector3(p.x * k, maxf(p.y * k, -0.2), p.z * k)
	arr[Mesh.ARRAY_VERTEX] = v
	var st := SurfaceTool.new()
	st.create_from_arrays(arr)
	st.generate_normals()
	var m := st.commit()
	m.surface_set_material(0, rock_mat())
	_cache[key] = m
	return m


# --- placement ---------------------------------------------------------------------

func build(t: Terrain, avoid: Array, quality := 1) -> void:
	near_dist = [110.0, 160.0, 220.0][clampi(quality, 0, 2)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var forest := FastNoiseLite.new()
	forest.seed = 99
	forest.frequency = 0.006
	forest.fractal_octaves = 3
	var blocks: Dictionary = {}  # Vector2i -> {"c": [xf], "cc": [col], "b": [...], "bc": [...]}
	var trunks := StaticBody3D.new()
	trunks.collision_mask = 0
	add_child(trunks)
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = 0.35
	trunk_shape.height = 5.0
	var placed := 0
	for k in 30000:
		if placed >= 2600:
			break
		var x := rng.randf_range(-480.0, 480.0)
		var z := rng.randf_range(-480.0, 480.0)
		var h := t.get_height(x, z)
		if h < 2.2 or h > 60.0:
			continue
		var f := forest.get_noise_2d(x, z)
		if f < 0.02 and rng.randf() > 0.05:
			continue
		if t.get_normal(x, z).y < 0.84 or t.meadow_at(x, z) < 0.6:
			continue
		if _near(avoid, x, z, 14.0):
			continue
		var s := rng.randf_range(0.75, 1.35)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.15), s)), Vector3(x, h - 0.2, z))
		var key := Vector2i(int(floor((x + Terrain.HALF) / BLOCK)), int(floor((z + Terrain.HALF) / BLOCK)))
		if not blocks.has(key):
			blocks[key] = {"c": [], "cc": [], "b": [], "bc": []}
		var bl: Dictionary = blocks[key]
		var tint := Color(rng.randf_range(0.85, 1.1), rng.randf_range(0.9, 1.1), rng.randf_range(0.85, 1.05))
		if h > 22.0 or f > 0.25 or rng.randf() < 0.3:
			bl["c"].append(xf)
			bl["cc"].append(tint)
		else:
			bl["b"].append(xf)
			bl["bc"].append(tint)
		var cs := CollisionShape3D.new()
		cs.shape = trunk_shape
		cs.position = Vector3(x, h + 2.4, z)
		trunks.add_child(cs)
		placed += 1
	var cm := conifer_mesh()
	var bm := broadleaf_mesh()
	var cf := far_conifer()
	var bf := far_broadleaf()
	for key in blocks:
		var bl: Dictionary = blocks[key]
		_pair(cm, cf, bl["c"], bl["cc"], CONIFER_AVG)
		_pair(bm, bf, bl["b"], bl["bc"], BROAD_AVG)
	_rocks(t, rng, avoid)


func _pair(near_mesh: Mesh, far_mesh: Mesh, xforms: Array, tints: Array, avg: Color) -> void:
	if xforms.is_empty():
		return
	var near := _multi(near_mesh, xforms, tints)
	near.visibility_range_end = near_dist
	near.visibility_range_end_margin = 12.0
	add_child(near)
	var far_tints: Array = []
	for c in tints:
		far_tints.append(Color(avg.r * c.r, avg.g * c.g, avg.b * c.b))
	var far := _multi(far_mesh, xforms, far_tints)
	far.visibility_range_begin = near_dist
	far.visibility_range_begin_margin = 12.0
	far.visibility_range_end = FAR_END
	far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(far)


func _rocks(t: Terrain, rng: RandomNumberGenerator, avoid: Array) -> void:
	var rocks := StaticBody3D.new()
	rocks.collision_mask = 0
	add_child(rocks)
	var sets: Array = [[], [], []]
	var cols: Array = [[], [], []]
	var placed := 0
	for k in 5000:
		if placed >= 320:
			break
		var x := rng.randf_range(-470.0, 470.0)
		var z := rng.randf_range(-470.0, 470.0)
		var h := t.get_height(x, z)
		if h < 0.8 or _near(avoid, x, z, 12.0):
			continue
		var steep := 1.0 - t.get_normal(x, z).y
		if steep < 0.08 and rng.randf() > 0.25:
			continue
		if t.surface_at(x, z) == Terrain.Surface.GRAVEL:
			continue
		var sx := rng.randf_range(0.5, 2.6)
		var sy := sx * rng.randf_range(0.5, 0.85)
		var sz := sx * rng.randf_range(0.7, 1.2)
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(sx, sy, sz))
		var v := rng.randi_range(0, 2)
		sets[v].append(Transform3D(b, Vector3(x, h - sy * 0.25, z)))
		var g := rng.randf_range(0.85, 1.1)
		cols[v].append(Color(g, g * 0.98, g * 1.02))
		if sx > 1.1:
			var cs := CollisionShape3D.new()
			var sh := SphereShape3D.new()
			sh.radius = minf(sx, sz) * 0.75
			cs.shape = sh
			cs.position = Vector3(x, h, z)
			rocks.add_child(cs)
		placed += 1
	for v in 3:
		if not sets[v].is_empty():
			var mm := _multi(rock_mesh(v + 3), sets[v], cols[v])
			mm.visibility_range_end = 450.0
			add_child(mm)


func _near(points: Array, x: float, z: float, r: float) -> bool:
	for p in points:
		var v: Vector3 = p
		if Vector2(v.x - x, v.z - z).length() < r:
			return true
	return false


func _multi(mesh: Mesh, xforms: Array, colors: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors.size() > 0
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		if mm.use_colors:
			mm.set_instance_color(i, colors[i])
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	return inst
