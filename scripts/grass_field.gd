class_name GrassField
extends MultiMeshInstance3D
## Grass clumps on meadows around the camera. Positions come from a fixed jittered grid,
## so clumps don't jump around when the field refreshes as you drive.

const SPACING := 0.62

var terrain: Terrain
var cam: Camera3D
var radius := 30.0
var _centre := Vector2(INF, INF)
var _mat: ShaderMaterial
var _thread: Thread
var _pending := Vector2(INF, INF)


func setup(t: Terrain, c: Camera3D, quality: int) -> void:
	terrain = t
	cam = c
	radius = [0.0, 24.0, 40.0][clampi(quality, 0, 2)]
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	visible = radius > 0.0
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/grass.gdshader")
	_mat.set_shader_parameter("tex", load("res://assets/cc0/foliage/grass_clump.png"))
	_mat.set_shader_parameter("radius", radius)
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = _clump()
	top_level = true


static func _clump() -> ArrayMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	for k in 2:
		var a := k * PI / 2.0 + 0.4
		var side := Vector3(cos(a), 0, sin(a)) * 0.38
		var b := v.size()
		v.append_array([-side + Vector3(0, 0.5, 0), side + Vector3(0, 0.5, 0), side, -side])
		for i in 4:
			n.append(Vector3.UP)
		uv.append_array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
		idx.append_array([b, b + 1, b + 2, b, b + 2, b + 3])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


func _process(_delta: float) -> void:
	if not visible or not cam:
		return
	var p := Vector2(cam.global_position.x, cam.global_position.z)
	_mat.set_shader_parameter("cam_pos", cam.global_position)
	if _thread and not _thread.is_alive():
		var res: Array = _thread.wait_to_finish()
		_thread = null
		_apply(res[0], res[1])
	if not _thread and p.distance_to(_centre) > radius * 0.3:
		_centre = p
		# Placement runs on a worker thread; terrain data is read-only by now.
		_thread = Thread.new()
		_thread.start(_compute.bind(p))


func _exit_tree() -> void:
	if _thread:
		_thread.wait_to_finish()


func _apply(xforms: Array, cols: Array) -> void:
	multimesh.instance_count = xforms.size()
	for i in xforms.size():
		multimesh.set_instance_transform(i, xforms[i])
		multimesh.set_instance_color(i, cols[i])


func _compute(centre: Vector2) -> Array:
	var _centre := centre
	var xforms: Array = []
	var cols: Array = []
	var cells := int(radius / SPACING)
	var gx0 := int(floor(_centre.x / SPACING))
	var gz0 := int(floor(_centre.y / SPACING))
	for gz in range(gz0 - cells, gz0 + cells + 1):
		for gx in range(gx0 - cells, gx0 + cells + 1):
			var hsh := _hash(gx, gz)
			var x := (gx + fposmod(hsh * 7.31, 1.0)) * SPACING
			var z := (gz + fposmod(hsh * 3.17, 1.0)) * SPACING
			if Vector2(x, z).distance_to(_centre) > radius:
				continue
			if terrain.meadow_at(x, z) < 0.55:
				continue
			var h := terrain.get_height(x, z)
			if h < 1.6:
				continue
			var s := 0.55 + fposmod(hsh * 13.7, 1.0) * 0.6
			xforms.append(Transform3D(Basis(Vector3.UP, hsh * TAU).scaled(Vector3(s, s, s)), Vector3(x, h - 0.05, z)))
			var g := 0.85 + fposmod(hsh * 5.3, 1.0) * 0.3
			cols.append(Color(g * 0.9, g * 1.05, g * 0.75))
	return [xforms, cols]


static func _hash(x: int, z: int) -> float:
	return fposmod(sin(x * 127.1 + z * 311.7) * 43758.5453, 1.0)
