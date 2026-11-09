class_name LowPoly
extends RefCounted
## Shared materials and flat-shaded (faceted) mesh helpers.

static var _mats: Dictionary = {}


static func mat(c: Color, rough := 0.9, emission := 0.0) -> StandardMaterial3D:
	var key := "%s_%.2f_%.2f" % [c.to_html(), rough, emission]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic_specular = 0.25
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emission
	_mats[key] = m
	return m


## White material that takes its colour from MultiMesh instance colours.
static func instance_mat() -> StandardMaterial3D:
	if _mats.has("__inst"):
		return _mats["__inst"]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.95
	m.metallic_specular = 0.15
	_mats["__inst"] = m
	return m


static func flat(src: Mesh, offset := Vector3.ZERO) -> ArrayMesh:
	return flat_many([[src, offset]])


## Merges primitive meshes (each [Mesh, offset]) into one mesh with one normal per face.
static func flat_many(parts: Array) -> ArrayMesh:
	var out_v := PackedVector3Array()
	var out_n := PackedVector3Array()
	for part in parts:
		var src: Mesh = part[0]
		var off: Vector3 = part[1]
		var arr := src.surface_get_arrays(0)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idx := PackedInt32Array()
		if arr[Mesh.ARRAY_INDEX] != null:
			idx = arr[Mesh.ARRAY_INDEX]
		var count := idx.size() if idx.size() > 0 else verts.size()
		for i in range(0, count, 3):
			var ia := idx[i] if idx.size() > 0 else i
			var ib := idx[i + 1] if idx.size() > 0 else i + 1
			var ic := idx[i + 2] if idx.size() > 0 else i + 2
			var a := verts[ia]
			var b := verts[ib]
			var c := verts[ic]
			var n := (b - a).cross(c - a)
			if n.length_squared() < 1e-10:
				continue
			n = n.normalized()
			if n.dot(norms[ia] + norms[ib] + norms[ic]) < 0.0:
				n = -n
			out_v.append(a + off)
			out_v.append(b + off)
			out_v.append(c + off)
			out_n.append(n)
			out_n.append(n)
			out_n.append(n)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = out_v
	arrays[Mesh.ARRAY_NORMAL] = out_n
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


static func cyl(top: float, bottom: float, height: float, segments := 8) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = segments
	c.rings = 1
	return c


static func sphere(radius: float, height: float, segments := 8, rings := 4) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = height
	s.radial_segments = segments
	s.rings = rings
	return s


static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b
