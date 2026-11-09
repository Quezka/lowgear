class_name MeshKit
extends RefCounted
## Smooth vehicle building blocks: rounded boxes and treaded tyres. Meshes are cached.

static var _cache: Dictionary = {}


## Box with rounded edges (radius r), smooth normals.
static func rbox(size: Vector3, r: float) -> ArrayMesh:
	var key := "rb%s_%.3f" % [size, r]
	if _cache.has(key):
		return _cache[key]
	var b := BoxMesh.new()
	b.size = size
	b.subdivide_width = 5
	b.subdivide_height = 5
	b.subdivide_depth = 5
	var arr := b.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var half := size * 0.5
	var inner := (half - Vector3.ONE * r).max(Vector3.ZERO)
	for i in v.size():
		var p := v[i]
		var c := p.clamp(-inner, inner)
		var d := p - c
		if d.length_squared() > 1e-8:
			var dn := d.normalized()
			v[i] = c + dn * r
			n[i] = dn
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_TANGENT] = null
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_cache[key] = m
	return m


## Tyre around the X axis with tread lugs in a chevron pattern.
static func tyre(radius: float, width: float, lugs: int) -> ArrayMesh:
	var key := "ty%.3f_%.3f_%d" % [radius, width, lugs]
	if _cache.has(key):
		return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rot := Transform3D(Basis(Vector3(0, 0, 1), PI / 2.0), Vector3.ZERO)
	var body := CylinderMesh.new()
	body.top_radius = radius * 0.94
	body.bottom_radius = radius * 0.94
	body.height = width
	body.radial_segments = 28
	body.rings = 2
	st.append_from(body, 0, rot)
	var lug := BoxMesh.new()
	lug.size = Vector3(width * 0.42, radius * 0.1, radius * 0.16)
	for i in lugs:
		var a := TAU * i / lugs
		for side in [-1.0, 1.0]:
			var off := Vector3(side * width * 0.24, 0, 0)
			var t := Transform3D(Basis(Vector3.RIGHT, a) * Basis(Vector3.UP, side * 0.35), Vector3.ZERO)
			t.origin = t.basis * Vector3(0, radius * 0.95, 0) + off
			st.append_from(lug, 0, t)
	st.generate_normals()
	var m := st.commit()
	_cache[key] = m
	return m


static func paint(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/vehicle.gdshader")
	m.set_shader_parameter("paint", color)
	m.set_shader_parameter("dirt_tex", load("res://assets/cc0/terrain/mud_color.jpg"))
	return m


static func rubber() -> StandardMaterial3D:
	if _cache.has("rubber"):
		return _cache["rubber"]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/cc0/vehicle/rubber_color.jpg")
	m.normal_enabled = true
	m.normal_texture = load("res://assets/cc0/vehicle/rubber_normal.jpg")
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(2, 2, 2)
	m.roughness = 0.95
	_cache["rubber"] = m
	return m
