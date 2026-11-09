class_name Collectibles
extends Node3D
## Landmarks (viewpoints with light beacons) and coin trails.

signal coin_collected(total: int)
signal trail_completed
signal discovered(lm_name: String, count: int)
signal refuelling(ratio: float)

const TRAILS := 30
const PER_TRAIL := 5

const CREAM := Color("#fff1e0")
const PEACH := Color("#f4a99b")
const PINK := Color("#f4a6b5")
const LAVENDER := Color("#cdb4db")
const STONE := Color("#c9bfd8")
const TRIM := Color("#6c6f86")
const WOOD := Color("#e8b89a")
const BARK := Color("#b39a8c")
const MINT := Color("#9ed9c5")

const DEFS := [
	{"id": "summit", "name": "Summit Cairn", "color": Color("#f6bd60")},
	{"id": "mast", "name": "Radio Mast", "color": Color("#f28482")},
	{"id": "lighthouse", "name": "Lighthouse", "color": Color("#84a59d")},
	{"id": "picnic", "name": "Picnic Spot", "color": Color("#f5cac3")},
	{"id": "windmill", "name": "Old Windmill", "color": Color("#b8a1e3")},
	{"id": "cabin", "name": "Hillside Cabin", "color": Color("#ff8fab")},
	{"id": "arch", "name": "Stone Arch", "color": Color("#8ecae6")},
	{"id": "blossom", "name": "Blossom Tree", "color": Color("#ffafcc")},
]

var terrain: Terrain
var landmarks: Array = []  ## {id, name, color, pos, found, beacon}
var total_coins := 0
var stations: Array = []  ## [{pos, area}]
var anchors: Array = []
var _trail_left: Dictionary = {}
var _coin_root: Node3D
var _spinners: Array = []
var _blinkers: Array = []
var _time := 0.0
var _rng := RandomNumberGenerator.new()


func build(t: Terrain, spawn: Transform3D) -> void:
	terrain = t
	_rng.seed = 808
	_place_landmarks(spawn.origin)
	_place_coins(spawn)
	var side := spawn.basis.x
	_station(spawn.origin + side * 12.0 + spawn.basis.z * 4.0, spawn.basis)
	var lms := landmarks.duplicate()
	lms.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["pos"] as Vector3).distance_to(spawn.origin) < (b["pos"] as Vector3).distance_to(spawn.origin))
	for k in mini(2, lms.size()):
		var lp: Vector3 = lms[k + 1 if lms.size() > 2 else k]["pos"]
		var dir := (spawn.origin - lp)
		dir.y = 0.0
		var p := lp + dir.normalized() * 18.0
		p.y = terrain.get_height(p.x, p.z)
		_station(p, Basis(Vector3.UP, atan2(dir.x, dir.z)))
	for l in landmarks:
		anchors.append((l["pos"] as Vector3) + Vector3.UP * 1.5)


func avoid_points() -> Array:
	var out: Array = []
	for l in landmarks:
		out.append(l["pos"])
	return out


func found_count() -> int:
	var n := 0
	for l in landmarks:
		if l["found"]:
			n += 1
	return n


# --- landmarks ------------------------------------------------------------

func _place_landmarks(spawn: Vector3) -> void:
	var cands: Array = []
	var x := -Terrain.HALF * 0.88
	while x <= Terrain.HALF * 0.88:
		var z := -Terrain.HALF * 0.88
		while z <= Terrain.HALF * 0.88:
			var h := terrain.get_height(x, z)
			if h > 1.5:
				cands.append({"p": Vector3(x, h, z), "flat": terrain.get_normal(x, z).y, "r": _rng.randf()})
			z += 16.0
		x += 16.0
	var chosen: Array = []
	for def in DEFS:
		var best: Dictionary = {}
		var best_s := -INF
		for relax in 2:
			for c in cands:
				var p: Vector3 = c["p"]
				if p.distance_to(spawn) < 45.0 or _too_close(chosen, p, 170.0 if relax == 0 else 90.0):
					continue
				if relax == 0 and not _ok(def["id"], c, spawn):
					continue
				var s := _score(def["id"], c, spawn)
				if s > best_s:
					best_s = s
					best = c
			if not best.is_empty():
				break
		if best.is_empty():
			continue
		var pos: Vector3 = best["p"]
		chosen.append(pos)
		_make_landmark(def, pos)


func _too_close(points: Array, p: Vector3, r: float) -> bool:
	for q in points:
		if (q as Vector3).distance_to(p) < r:
			return true
	return false


func _ok(id: String, c: Dictionary, spawn: Vector3) -> bool:
	var p: Vector3 = c["p"]
	var flat: float = c["flat"]
	match id:
		"summit": return flat > 0.7
		"mast": return flat > 0.8
		"lighthouse": return p.y < 7.0 and flat > 0.85
		"picnic":
			var d := p.distance_to(spawn)
			return d > 80.0 and d < 170.0 and flat > 0.95
		"windmill": return p.y > 16.0 and p.y < 40.0 and flat > 0.93
		"cabin": return p.y > 8.0 and p.y < 30.0 and flat > 0.94
		"arch": return p.y > 6.0 and p.y < 45.0 and flat > 0.9
		"blossom": return p.y > 3.0 and p.y < 16.0 and flat > 0.9
	return true


func _score(id: String, c: Dictionary, spawn: Vector3) -> float:
	var p: Vector3 = c["p"]
	match id:
		"summit", "mast": return p.y
		"lighthouse": return Vector2(p.x, p.z).length() + p.distance_to(spawn) * 0.6
	return c["r"]


func _make_landmark(def: Dictionary, pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos - Vector3(0, 0.3, 0)
	root.rotation.y = _rng.randf() * TAU
	add_child(root)
	var body := StaticBody3D.new()
	body.collision_mask = 0
	root.add_child(body)
	match def["id"]:
		"windmill": _windmill(root, body)
		"lighthouse": _lighthouse(root, body)
		"mast": _mast(root, body)
		"cabin": _cabin(root, body)
		"arch": _arch(root, body)
		"picnic": _picnic(root, body)
		"blossom": _blossom(root, body)
		"summit": _summit(root, body)
	var id: String = def["id"]
	var lm := {"id": id, "name": def["name"], "color": def["color"], "pos": pos,
		"found": GameState.viewpoints.has(id), "beacon": null}
	if not lm["found"]:
		var beacon := MeshInstance3D.new()
		beacon.mesh = LowPoly.cyl(1.3, 1.3, 120.0, 8)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(def["color"], 0.3)
		m.disable_fog = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		beacon.material_override = m
		beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beacon.position = pos + Vector3(0, 62.0, 0)
		add_child(beacon)
		lm["beacon"] = beacon
	landmarks.append(lm)
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	area.position = pos
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 16.0
	sh.height = 40.0
	cs.shape = sh
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(_on_landmark_entered.bind(lm))


func _on_landmark_entered(body: Node3D, lm: Dictionary) -> void:
	if lm["found"] or not body is Car:
		return
	lm["found"] = true
	GameState.viewpoints[lm["id"]] = true
	GameState.save_game()
	var beacon: Node3D = lm["beacon"]
	if beacon:
		var tw := create_tween()
		tw.tween_property(beacon, "scale", Vector3(0.01, 1.0, 0.01), 1.2)
		tw.tween_callback(beacon.queue_free)
	discovered.emit(lm["name"], found_count())


## One primitive part, flat-shaded; optionally solid.
func _part(parent: Node3D, body: StaticBody3D, kind: String, dims: Vector3, pos: Vector3,
		color: Color, rot := Vector3.ZERO, solid := false, emission := 0.0) -> MeshInstance3D:
	var mesh: Mesh
	var shape: Shape3D
	match kind:
		"box":
			mesh = LowPoly.box(dims)
			var b := BoxShape3D.new()
			b.size = dims
			shape = b
		"cyl":
			mesh = LowPoly.cyl(dims.x, dims.y, dims.z, 18)
			var c := CylinderShape3D.new()
			c.radius = maxf(dims.x, dims.y)
			c.height = dims.z
			shape = c
		_:
			mesh = LowPoly.sphere(dims.x, dims.y, 16, 8)
			var s := SphereShape3D.new()
			s.radius = dims.x
			shape = s
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = LowPoly.mat(color, 0.9, emission)
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	if solid and body:
		# Solid parts are always direct children of the landmark root, like the body.
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = pos
		cs.rotation_degrees = rot
		body.add_child(cs)
	return mi


func _windmill(r: Node3D, b: StaticBody3D) -> void:
	_part(r, b, "cyl", Vector3(1.5, 2.4, 10.0), Vector3(0, 4.7, 0), CREAM, Vector3.ZERO, true)
	_part(r, b, "cyl", Vector3(0.0, 1.9, 2.2), Vector3(0, 10.8, 0), PINK)
	_part(r, b, "box", Vector3(1.0, 1.8, 0.1), Vector3(0, 0.9, 2.3), TRIM, Vector3(-12, 0, 0))
	var pivot := Node3D.new()
	pivot.position = Vector3(0, 8.4, 2.1)
	r.add_child(pivot)
	_part(pivot, null, "sph", Vector3(0.45, 0.9, 0), Vector3.ZERO, TRIM)
	for i in 4:
		var arm := Node3D.new()
		arm.rotation_degrees = Vector3(0, 0, i * 90.0)
		pivot.add_child(arm)
		_part(arm, null, "box", Vector3(0.8, 4.8, 0.12), Vector3(0.25, 2.6, 0), LAVENDER)
	_spinners.append([pivot, Vector3(0, 0, 1), 0.7])


func _lighthouse(r: Node3D, b: StaticBody3D) -> void:
	_part(r, b, "cyl", Vector3(2.3, 2.6, 1.4), Vector3(0, 0.4, 0), STONE, Vector3.ZERO, true)
	for i in 4:
		var bottom := 1.9 - i * 0.12
		_part(r, null, "cyl", Vector3(bottom - 0.12, bottom, 3.0), Vector3(0, 2.6 + i * 3.0, 0), CREAM if i % 2 == 0 else PEACH)
	var cs := CollisionShape3D.new()
	var tower := CylinderShape3D.new()
	tower.radius = 1.9
	tower.height = 12.0
	cs.shape = tower
	cs.position = Vector3(0, 7.0, 0)
	b.add_child(cs)
	_part(r, null, "cyl", Vector3(1.8, 1.8, 0.15), Vector3(0, 13.2, 0), TRIM)
	_part(r, null, "cyl", Vector3(1.15, 1.15, 1.6), Vector3(0, 14.1, 0), Color("#fff3b0"), Vector3.ZERO, false, 1.2)
	_part(r, null, "cyl", Vector3(0.0, 1.6, 1.4), Vector3(0, 15.6, 0), PINK)


func _mast(r: Node3D, b: StaticBody3D) -> void:
	_part(r, b, "box", Vector3(3.2, 2.6, 3.2), Vector3(4.0, 1.3, 0), CREAM, Vector3.ZERO, true)
	_part(r, null, "box", Vector3(3.6, 0.2, 3.6), Vector3(4.0, 2.7, 0), PINK)
	_part(r, b, "cyl", Vector3(0.25, 0.75, 28.0), Vector3(0, 14.0, 0), LAVENDER, Vector3.ZERO, true)
	_part(r, null, "cyl", Vector3(0.62, 0.66, 1.0), Vector3(0, 9.0, 0), PINK)
	_part(r, null, "cyl", Vector3(0.42, 0.46, 1.0), Vector3(0, 18.0, 0), PINK)
	var light := _part(r, null, "sph", Vector3(0.5, 1.0, 0), Vector3(0, 28.3, 0), Color("#ff6b81"), Vector3.ZERO, false, 2.0)
	_blinkers.append(light)


func _cabin(r: Node3D, b: StaticBody3D) -> void:
	_part(r, null, "box", Vector3(6.6, 1.0, 5.6), Vector3(0, 0.0, 0), STONE)
	_part(r, b, "box", Vector3(6.0, 3.0, 5.0), Vector3(0, 2.0, 0), WOOD, Vector3.ZERO, true)
	_part(r, null, "box", Vector3(6.8, 0.25, 3.4), Vector3(0, 4.25, 1.4), Color("#e5989b"), Vector3(32, 0, 0))
	_part(r, null, "box", Vector3(6.8, 0.25, 3.4), Vector3(0, 4.25, -1.4), Color("#e5989b"), Vector3(-32, 0, 0))
	_part(r, null, "box", Vector3(5.6, 1.6, 0.2), Vector3(0, 4.0, 0), WOOD)
	_part(r, null, "box", Vector3(0.6, 1.6, 0.6), Vector3(1.8, 5.0, -0.9), TRIM)
	_part(r, null, "box", Vector3(1.0, 2.0, 0.08), Vector3(0, 1.5, 2.53), TRIM)
	for x in [-1.8, 1.8]:
		_part(r, null, "box", Vector3(0.9, 0.8, 0.08), Vector3(x, 2.4, 2.53), Color("#fff3b0"), Vector3.ZERO, false, 0.5)


func _arch(r: Node3D, b: StaticBody3D) -> void:
	for x in [-3.3, 3.3]:
		_part(r, b, "box", Vector3(1.8, 8.0, 1.8), Vector3(x, 3.6, 0), STONE, Vector3.ZERO, true)
		_part(r, null, "box", Vector3(2.2, 0.6, 2.2), Vector3(x, 0.0, 0), Color("#b8acc9"))
	_part(r, b, "box", Vector3(8.6, 1.6, 2.2), Vector3(0, 8.2, 0), Color("#b8acc9"), Vector3.ZERO, true)
	_part(r, null, "box", Vector3(2.0, 0.8, 2.4), Vector3(0, 9.3, 0), STONE)


func _picnic(r: Node3D, b: StaticBody3D) -> void:
	_part(r, b, "box", Vector3(2.4, 0.12, 1.0), Vector3(0, 1.25, 0), WOOD, Vector3.ZERO, true)
	_part(r, null, "box", Vector3(2.5, 0.03, 1.1), Vector3(0, 1.33, 0), PINK)
	for x in [-1.0, 1.0]:
		_part(r, null, "box", Vector3(0.12, 1.2, 0.9), Vector3(x, 0.65, 0), WOOD)
	for z in [-0.85, 0.85]:
		_part(r, null, "box", Vector3(2.4, 0.1, 0.4), Vector3(0, 0.85, z), WOOD)
	_part(r, null, "cyl", Vector3(0.05, 0.05, 2.8), Vector3(0, 2.0, 0), TRIM)
	_part(r, null, "cyl", Vector3(0.0, 1.7, 0.7), Vector3(0, 3.3, 0), MINT)


func _blossom(r: Node3D, b: StaticBody3D) -> void:
	_part(r, b, "cyl", Vector3(0.6, 1.0, 7.5), Vector3(0, 3.5, 0), BARK, Vector3.ZERO, true)
	_part(r, null, "sph", Vector3(4.2, 6.0, 0), Vector3(0, 8.8, 0), Color("#f7c6d9"))
	_part(r, null, "sph", Vector3(3.0, 4.4, 0), Vector3(3.0, 7.6, 1.5), Color("#fbd3e2"))
	_part(r, null, "sph", Vector3(3.2, 4.6, 0), Vector3(-2.6, 7.9, -1.4), Color("#f3b6cc"))


func _summit(r: Node3D, b: StaticBody3D) -> void:
	_part(r, b, "sph", Vector3(1.6, 1.8, 0), Vector3(0, 0.7, 0), STONE, Vector3.ZERO, true)
	_part(r, null, "sph", Vector3(1.25, 1.4, 0), Vector3(0.1, 2.0, 0), Color("#b8acc9"))
	_part(r, null, "sph", Vector3(0.95, 1.1, 0), Vector3(-0.1, 3.0, 0.1), STONE)
	_part(r, null, "sph", Vector3(0.65, 0.8, 0), Vector3(0, 3.8, 0), Color("#b8acc9"))
	_part(r, null, "cyl", Vector3(0.05, 0.05, 3.0), Vector3(0.3, 5.4, 0), TRIM)
	_part(r, null, "box", Vector3(1.2, 0.7, 0.04), Vector3(0.9, 6.5, 0), PINK)


# --- fuel stations ----------------------------------------------------------------

func _station(pos: Vector3, basis: Basis) -> void:
	pos.y = terrain.get_height(pos.x, pos.z)
	var root := Node3D.new()
	root.position = pos - Vector3(0, 0.1, 0)
	root.basis = basis
	add_child(root)
	var body := StaticBody3D.new()
	body.collision_mask = 0
	root.add_child(body)
	_part(root, null, "box", Vector3(7.0, 0.3, 5.0), Vector3(0, 0.05, 0), Color("#c9c3ba"))
	_part(root, body, "box", Vector3(0.8, 1.7, 0.6), Vector3(-2.6, 0.95, 0), Color("#e8707f"), Vector3.ZERO, true)
	_part(root, null, "box", Vector3(0.6, 0.4, 0.05), Vector3(-2.6, 1.3, 0.31), Color("#fff3c4"), Vector3.ZERO, false, 0.4)
	for x in [-3.2, 3.2]:
		_part(root, body, "cyl", Vector3(0.12, 0.12, 4.2), Vector3(x, 2.1, -1.8), Color("#e8e4dc"), Vector3.ZERO, true)
		_part(root, body, "cyl", Vector3(0.12, 0.12, 4.2), Vector3(x, 2.1, 1.8), Color("#e8e4dc"), Vector3.ZERO, true)
	_part(root, null, "box", Vector3(7.4, 0.35, 4.6), Vector3(0, 4.3, 0), Color("#e8707f"))
	var sign := Label3D.new()
	sign.text = "FUEL"
	sign.font_size = 160
	sign.pixel_size = 0.006
	sign.outline_size = 24
	sign.modulate = Color("#fff8f0")
	sign.outline_modulate = Color("#2b2d42")
	sign.position = Vector3(0, 4.3, 2.35)
	root.add_child(sign)
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 7.0
	sh.height = 6.0
	cs.shape = sh
	area.add_child(cs)
	root.add_child(area)
	stations.append({"pos": pos, "area": area})
	anchors.append(pos + basis * Vector3(3.2, 1.5, 1.8))


func _physics_process(delta: float) -> void:
	for s in stations:
		for b in (s["area"] as Area3D).get_overlapping_bodies():
			if b is Car and (b as Car).linear_velocity.length() < 2.0:
				var car := b as Car
				var fuelled := car.refuel(float(car.spec["fuel"]) * 0.12 * delta)
				var fixed := car.repair(0.12 * delta)
				if fuelled or fixed:
					refuelling.emit(minf(car.fuel_ratio(), minf(car.engine_health, minf(car.body_health, car.worst_wheel()))))


# --- coins -------------------------------------------------------------------

func _place_coins(spawn: Transform3D) -> void:
	_coin_root = Node3D.new()
	add_child(_coin_root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var mesh := LowPoly.cyl(0.5, 0.5, 0.12, 12)
	var mat := LowPoly.mat(Color("#ffc94d"), 0.4, 0.35)
	var shape := SphereShape3D.new()
	shape.radius = 1.5
	var lm_points := avoid_points()
	var trail := 0
	var tries := 0
	while trail < TRAILS and tries < 5000:
		tries += 1
		var start: Vector3
		var dir: Vector3
		if trail == 0:
			# First trail sits right in front of the spawn, as a hint.
			dir = spawn.basis.z
			dir.y = 0.0
			dir = dir.normalized()
			start = spawn.origin + dir * 22.0
		else:
			start = Vector3(rng.randf_range(-420.0, 420.0), 0, rng.randf_range(-420.0, 420.0))
			dir = Vector3(0, 0, 1).rotated(Vector3.UP, rng.randf() * TAU)
		var pts: Array = []
		var ok := true
		for k in PER_TRAIL:
			var p := start + dir * (k * 7.0)
			var h := terrain.get_height(p.x, p.z)
			if h < 1.5 or h > 62.0 or _too_close(lm_points, Vector3(p.x, h, p.z), 14.0):
				ok = false
				break
			pts.append(Vector3(p.x, h + 1.3, p.z))
		if not ok:
			continue
		var left := 0
		for k in PER_TRAIL:
			var id := trail * PER_TRAIL + k
			total_coins += 1
			if GameState.coins.has(str(id)):
				continue
			left += 1
			var area := Area3D.new()
			area.collision_layer = 0
			area.collision_mask = 2
			area.position = pts[k]
			var cs := CollisionShape3D.new()
			cs.shape = shape
			area.add_child(cs)
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.material_override = mat
			mi.rotation_degrees = Vector3(90, 0, 0)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			area.add_child(mi)
			_coin_root.add_child(area)
			area.body_entered.connect(_on_coin.bind(str(id), trail, area))
		_trail_left[trail] = left
		trail += 1


func _on_coin(body: Node3D, id: String, trail: int, area: Area3D) -> void:
	if not body is Car or GameState.coins.has(id):
		return
	GameState.coins[id] = true
	area.set_deferred("monitoring", false)
	var tw := create_tween()
	tw.tween_property(area, "scale", Vector3(1.6, 1.6, 1.6), 0.08)
	tw.tween_property(area, "scale", Vector3(0.01, 0.01, 0.01), 0.14)
	tw.tween_callback(area.queue_free)
	coin_collected.emit(GameState.coins.size())
	_trail_left[trail] = int(_trail_left.get(trail, 1)) - 1
	if _trail_left[trail] == 0:
		trail_completed.emit()


func _process(delta: float) -> void:
	_time += delta
	for c in _coin_root.get_children():
		(c as Node3D).rotate_y(delta * 2.2)
	for s in _spinners:
		(s[0] as Node3D).rotate_object_local(s[1], float(s[2]) * delta)
	var on := fmod(_time, 2.0) < 1.0
	for bl in _blinkers:
		(bl as MeshInstance3D).visible = on
