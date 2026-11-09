class_name TyreTracks
extends MeshInstance3D
## Tyre marks behind every wheel (colour by ground) and rut memory: each pass through mud
## makes that spot deeper for the next vehicle.

const MAX_PTS := 320
const STEP := 0.45

var _strips: Dictionary = {}  ## key -> {pts: Array, cols: Array, w: float, last: Vector3}
var _ruts: Dictionary = {}    ## Vector2i (1 m cell) -> 0..1
var _dirty := false
var _t := 0.0


func _ready() -> void:
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.9
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = m


func _colour(surface: int, mud: float) -> Color:
	if mud > 0.15:
		return Color(0.22, 0.16, 0.11, 0.55 + mud * 0.3)
	match surface:
		Terrain.Surface.GRASS: return Color(0.3, 0.27, 0.18, 0.35)
		Terrain.Surface.SAND: return Color(0.62, 0.53, 0.4, 0.45)
		Terrain.Surface.SNOW: return Color(0.72, 0.76, 0.84, 0.6)
		Terrain.Surface.GRAVEL: return Color(0.4, 0.38, 0.35, 0.22)
	return Color(0, 0, 0, 0)


func add_point(key: int, pos: Vector3, width: float, surface: int, mud: float) -> void:
	if not _strips.has(key):
		_strips[key] = {"pts": [], "cols": [], "w": width, "last": Vector3.INF}
	var s: Dictionary = _strips[key]
	var col := _colour(surface, mud)
	var last: Vector3 = s["last"]
	if col.a <= 0.0:
		if last != Vector3.INF:
			(s["pts"] as Array).append(Vector3.INF)
			(s["cols"] as Array).append(col)
			s["last"] = Vector3.INF
		return
	if last != Vector3.INF and pos.distance_to(last) < STEP:
		return
	(s["pts"] as Array).append(pos + Vector3.UP * 0.04)
	(s["cols"] as Array).append(col)
	s["last"] = pos
	if (s["pts"] as Array).size() > MAX_PTS:
		(s["pts"] as Array).pop_front()
		(s["cols"] as Array).pop_front()
	if mud > 0.05:
		var cell := Vector2i(int(floor(pos.x)), int(floor(pos.z)))
		_ruts[cell] = minf(1.0, float(_ruts.get(cell, 0.0)) + 0.06 * mud)
	_dirty = true


func rut_at(x: float, z: float) -> float:
	return _ruts.get(Vector2i(int(floor(x)), int(floor(z))), 0.0)


func _process(delta: float) -> void:
	_t += delta
	if not _dirty or _t < 0.2:
		return
	_t = 0.0
	_dirty = false
	var v := PackedVector3Array()
	var c := PackedColorArray()
	var n := PackedVector3Array()
	var idx := PackedInt32Array()
	for key in _strips:
		var s: Dictionary = _strips[key]
		var pts: Array = s["pts"]
		var cols: Array = s["cols"]
		var hw: float = float(s["w"]) * 0.5
		var count := pts.size()
		for i in count - 1:
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[i + 1]
			if a == Vector3.INF or b == Vector3.INF:
				continue
			var dir := b - a
			dir.y = 0.0
			if dir.length_squared() < 0.0001:
				continue
			var side := dir.normalized().cross(Vector3.UP) * hw
			var age := 0.35 + 0.65 * float(i) / count
			var ca: Color = cols[i]
			var cb: Color = cols[i + 1]
			ca.a *= age
			cb.a *= age
			var base := v.size()
			v.append_array([a - side, a + side, b + side, b - side])
			c.append_array([ca, ca, cb, cb])
			for k in 4:
				n.append(Vector3.UP)
			idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	if v.is_empty():
		mesh = null
		return
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_COLOR] = c
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh = m
