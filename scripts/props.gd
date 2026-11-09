class_name Props
extends Node3D
## Trees, rocks and flowers scattered over the island with MultiMeshes.

const PINE_COLS := ["#84b59f", "#93c4a6", "#7aa995", "#a0cbb0"]
const ROUND_COLS := ["#f7c6d9", "#ffd6a5", "#cfe8a9", "#f9dcc4", "#bfe3c0"]
const ROCK_COLS := ["#c3b8d6", "#b5b9cc", "#cdc3d9", "#bdb0cc"]
const FLOWER_COLS := ["#ffffff", "#ffd6e0", "#fff1a8", "#d8c7f5"]
const TRUNK_COL := Color("#b39a8c")


static func pine_crown() -> ArrayMesh:
	return LowPoly.flat_many([
		[LowPoly.cyl(0.0, 1.6, 2.8, 6), Vector3(0, 2.6, 0)],
		[LowPoly.cyl(0.0, 1.15, 2.2, 6), Vector3(0, 4.0, 0)],
	])


static func round_crown() -> ArrayMesh:
	return LowPoly.flat(LowPoly.sphere(1.5, 2.8, 7, 4), Vector3(0, 2.9, 0))


static func trunk() -> ArrayMesh:
	return LowPoly.flat(LowPoly.cyl(0.22, 0.3, 1.9, 5), Vector3(0, 0.9, 0))


static func rock() -> ArrayMesh:
	return LowPoly.flat(LowPoly.sphere(1.0, 1.4, 6, 3))


static func flower() -> ArrayMesh:
	return LowPoly.flat(LowPoly.cyl(0.0, 0.22, 0.45, 4), Vector3(0, 0.2, 0))


func build(t: Terrain, avoid: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var forest := FastNoiseLite.new()
	forest.seed = 99
	forest.frequency = 0.007

	var trunk_x: Array = []
	var pine_x: Array = []
	var pine_c: Array = []
	var round_x: Array = []
	var round_c: Array = []
	var trunks := StaticBody3D.new()
	trunks.collision_mask = 0
	add_child(trunks)
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = 0.35
	trunk_shape.height = 4.0
	for k in 14000:
		if trunk_x.size() >= 1500:
			break
		var x := rng.randf_range(-470.0, 470.0)
		var z := rng.randf_range(-470.0, 470.0)
		var h := t.get_height(x, z)
		if h < 2.0 or h > 56.0:
			continue
		if t.get_normal(x, z).y < 0.82:
			continue
		if forest.get_noise_2d(x, z) < 0.08 and rng.randf() > 0.06:
			continue
		if _near(avoid, x, z, 16.0):
			continue
		var s := rng.randf_range(0.8, 1.5)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(x, h - 0.15, z))
		trunk_x.append(xf)
		if h > 26.0 or (h > 10.0 and rng.randf() < 0.5):
			pine_x.append(xf)
			pine_c.append(_pick(rng, PINE_COLS))
		else:
			round_x.append(xf)
			round_c.append(_pick(rng, ROUND_COLS))
		var cs := CollisionShape3D.new()
		cs.shape = trunk_shape
		cs.position = Vector3(x, h + 2.0, z)
		trunks.add_child(cs)
	add_child(_multi(trunk(), trunk_x, [], LowPoly.mat(TRUNK_COL)))
	add_child(_multi(pine_crown(), pine_x, pine_c, LowPoly.instance_mat()))
	add_child(_multi(round_crown(), round_x, round_c, LowPoly.instance_mat()))

	# Rocks: big ones are solid, small ones are just scenery.
	var rocks := StaticBody3D.new()
	rocks.collision_mask = 0
	add_child(rocks)
	var rock_x: Array = []
	var rock_c: Array = []
	for k in 4000:
		if rock_x.size() >= 300:
			break
		var x := rng.randf_range(-470.0, 470.0)
		var z := rng.randf_range(-470.0, 470.0)
		var h := t.get_height(x, z)
		if h < 0.6 or h > 75.0 or _near(avoid, x, z, 12.0):
			continue
		var sx := rng.randf_range(0.5, 2.4)
		var sy := sx * rng.randf_range(0.5, 0.9)
		var sz := sx * rng.randf_range(0.7, 1.2)
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(sx, sy, sz))
		rock_x.append(Transform3D(b, Vector3(x, h + sy * 0.15, z)))
		rock_c.append(_pick(rng, ROCK_COLS))
		if sx > 1.2:
			var cs := CollisionShape3D.new()
			var sh := SphereShape3D.new()
			sh.radius = minf(sx, sz) * 0.8
			cs.shape = sh
			cs.position = Vector3(x, h + sy * 0.1, z)
			rocks.add_child(cs)
	add_child(_multi(rock(), rock_x, rock_c, LowPoly.instance_mat()))

	var fl_x: Array = []
	var fl_c: Array = []
	for k in 9000:
		if fl_x.size() >= 2600:
			break
		var x := rng.randf_range(-470.0, 470.0)
		var z := rng.randf_range(-470.0, 470.0)
		var h := t.get_height(x, z)
		if h < 2.0 or h > 40.0 or t.get_normal(x, z).y < 0.9:
			continue
		var s := rng.randf_range(0.7, 1.4)
		fl_x.append(Transform3D(Basis.from_scale(Vector3(s, s, s)), Vector3(x, h, z)))
		fl_c.append(_pick(rng, FLOWER_COLS))
	add_child(_multi(flower(), fl_x, fl_c, LowPoly.instance_mat()))


func _pick(rng: RandomNumberGenerator, cols: Array) -> Color:
	return Color(str(cols[rng.randi_range(0, cols.size() - 1)]))


func _near(points: Array, x: float, z: float, r: float) -> bool:
	for p in points:
		var v: Vector3 = p
		if Vector2(v.x - x, v.z - z).length() < r:
			return true
	return false


func _multi(mesh: Mesh, xforms: Array, colors: Array, material: Material) -> MultiMeshInstance3D:
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
	inst.material_override = material
	return inst
