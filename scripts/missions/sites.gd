class_name Sites
extends Node3D
## Places for work on a map (garage, warehouse, sawmill, logging camp, farm, building sites),
## their buildings and zones, cargo loading/unloading, ground piles and the contracts.

signal contract_done(title: String, cash: int, xp: int)
signal changed

const ZONE := 13.0

## Contracts for the island. needs: {cargo type: loads}. effect: what appears when it's done.
const CONTRACTS := [
	{"id": "farm", "title": "Supplies for the farm", "site": "farm", "needs": {"pallet": 3}, "cash": 2500, "xp": 300},
	{"id": "bridge", "title": "Rebuild the bridge over the mud", "site": "bridge", "needs": {"planks": 2, "pipes": 1},
		"cash": 4000, "xp": 500, "effect": "bridge"},
	{"id": "rescue", "title": "Spare parts for the stuck truck", "site": "stuck", "needs": {"parts": 1},
		"cash": 3000, "xp": 400, "effect": "rescue"},
	{"id": "lookout", "title": "Build the lookout tower", "site": "lookout", "needs": {"pipes": 2, "planks": 2},
		"cash": 5000, "xp": 600, "effect": "tower"},
	{"id": "lighthouse", "title": "Parts for the lighthouse lamp", "site": "lighthouse", "needs": {"parts": 2},
		"cash": 3500, "xp": 450},
	{"id": "logs", "title": "Logs for the sawmill", "site": "sawmill", "needs": {"logs": 2}, "cash": 6000, "xp": 700},
	{"id": "farm_daily", "title": "Weekly farm order", "site": "farm", "needs": {"pallet": 1}, "cash": 700, "xp": 80,
		"repeat": true, "after": "farm"},
	{"id": "logs_daily", "title": "Sawmill order", "site": "sawmill", "needs": {"logs": 1}, "cash": 2200, "xp": 220,
		"repeat": true, "after": "logs"},
]

var terrain: Terrain
var sites: Dictionary = {}      ## id -> {id, name, icon, pos, products, basis}
var piles: Array = []           ## cargo on the ground: {pos, type, node}
var log_piles: Array = []       ## Vector3
var garage_pos := Vector3.INF
var reveal_all := false


func avoid_points() -> Array:
	var out: Array = []
	for id in sites:
		out.append(sites[id]["pos"])
	out.append_array(log_piles)
	return out


# --- placement -------------------------------------------------------------------

func place(t: Terrain, spawn: Transform3D, landmarks: Array) -> void:
	terrain = t
	var tr := t.tracks
	_add("garage", "Garage", "garage_home", _flat(spawn.origin - spawn.basis.x * 16.0 + spawn.basis.z * 3.0, 6.0), [])
	garage_pos = sites["garage"]["pos"]
	if tr.size() > 0:
		_add("warehouse", "Warehouse", "warehouse", _beside(tr[1 % tr.size()], 0.45, 14.0), ["pallet", "pipes", "parts"])
		_add("sawmill", "Sawmill", "carpenter", _beside(tr[2 % tr.size()], 0.6, 15.0), ["planks"])
		_add("logging", "Logging camp", "forest", _beside(tr[3 % tr.size()], 0.75, 16.0), ["logs"])
		_add("farm", "Farm", "agriculture", _beside(tr[4 % tr.size()], 0.85, 18.0), [])
	if t.mud_pit != Vector3.INF:
		_add("bridge", "Bridge site", "construction", t.mud_pit, [])
	for l in landmarks:
		if l["id"] == "summit":
			_add("lookout", "Lookout site", "construction", _flat((l["pos"] as Vector3) + Vector3(14, 0, 0), 10.0), [])
		elif l["id"] == "lighthouse":
			_add("lighthouse", "Lighthouse", "flag", _flat((l["pos"] as Vector3) + Vector3(0, 0, 14), 8.0), [])
	_add("stuck", "Stuck truck", "car_crash", _deep_mud(spawn.origin), [])
	# Extra log piles out in the forest, for the logging truck's crane.
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for k in 6:
		var pts: PackedVector3Array = tr[rng.randi_range(0, tr.size() - 1)] if tr.size() > 0 else PackedVector3Array([spawn.origin])
		var p := pts[rng.randi_range(pts.size() / 3, pts.size() - 1)]
		var side := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
		log_piles.append(_flat(p + side * 9.0, 4.0))
	if sites.has("logging"):
		log_piles.append((sites["logging"]["pos"] as Vector3) + Vector3(6, 0, 4))


func _add(id: String, title: String, icon: String, pos: Vector3, products: Array) -> void:
	pos.y = terrain.get_height(pos.x, pos.z)
	sites[id] = {"id": id, "name": title, "icon": icon, "pos": pos, "products": products}


func _beside(pts: PackedVector3Array, f: float, off: float) -> Vector3:
	var k := clampi(int(pts.size() * f), 1, pts.size() - 2)
	var dir := pts[k + 1] - pts[k - 1]
	dir.y = 0.0
	var side := dir.normalized().cross(Vector3.UP)
	return _flat(pts[k] + side * off, 8.0)


## The flattest dry spot within r metres.
func _flat(p: Vector3, r: float) -> Vector3:
	var best := p
	var best_s := -INF
	for k in 24:
		var a := k * TAU / 12.0
		var d := r * (0.3 + 0.7 * float(k % 12) / 11.0) if k >= 12 else r * float(k) / 12.0
		var q := p + Vector3(cos(a), 0, sin(a)) * d
		var h := terrain.get_height(q.x, q.z)
		if h < 1.5:
			continue
		var s := terrain.get_normal(q.x, q.z).y - terrain.mud_at(q.x, q.z) * 0.3 - d * 0.002
		if s > best_s:
			best_s = s
			best = q
	best.y = terrain.get_height(best.x, best.z)
	return best


func _deep_mud(from: Vector3) -> Vector3:
	var best := from
	var best_m := 0.0
	for j in range(0, Terrain.N, 4):
		for i in range(0, Terrain.N, 4):
			var x := -Terrain.HALF + i * Terrain.CELL
			var z := -Terrain.HALF + j * Terrain.CELL
			var m := terrain.mud_at(x, z)
			var d := Vector2(x - from.x, z - from.z).length()
			if m > best_m and d > 160.0 and d < 380.0:
				best_m = m
				best = Vector3(x, 0, z)
	best.y = terrain.get_height(best.x, best.z)
	return best


# --- buildings -------------------------------------------------------------------

func build() -> void:
	var state := GameState.map_state()
	for id in sites:
		var s: Dictionary = sites[id]
		var root := Node3D.new()
		root.position = s["pos"] as Vector3
		root.rotation.y = randf_range(0, TAU) if id in ["logging", "stuck"] else atan2(-(s["pos"] as Vector3).x, -(s["pos"] as Vector3).z)
		add_child(root)
		s["root"] = root
		var body := StaticBody3D.new()
		body.collision_mask = 0
		root.add_child(body)
		match id:
			"garage": _garage(root, body)
			"warehouse": _shed(root, body, Color("#9fb3c8"), Color("#e8707f"), "WAREHOUSE")
			"sawmill": _sawmill(root, body)
			"logging": _logging(root, body)
			"farm": _farm(root, body)
			"bridge", "lookout": _site_fence(root)
			"lighthouse": _site_fence(root)
			"stuck": _stuck_truck(root, "rescue" in state["built"])
		var area := Area3D.new()
		area.collision_layer = 0
		area.collision_mask = 2
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = ZONE
		sh.height = 10.0
		cs.shape = sh
		area.add_child(cs)
		root.add_child(area)
		s["area"] = area
	for p in log_piles:
		var pile := Cargo.model("logs")
		pile.position = p
		pile.rotation.y = randf() * TAU
		pile.scale = Vector3(1.2, 1.2, 1.2)
		add_child(pile)
	for b in state["built"]:
		_apply_effect(str(b))


func _box(parent: Node3D, body: StaticBody3D, size: Vector3, pos: Vector3, color: Color, solid := true, rot := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = MeshKit.rbox(size, minf(0.12, minf(size.x, minf(size.y, size.z)) * 0.2))
	mi.material_override = LowPoly.mat(color, 0.85)
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	if solid and body:
		var cs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = size
		cs.shape = b
		cs.position = pos
		cs.rotation_degrees = rot
		body.add_child(cs)


func _sign(parent: Node3D, text: String, pos: Vector3, size := 120) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.006
	l.outline_size = 22
	l.modulate = Color("#fff8f0")
	l.outline_modulate = Color("#2b2d42")
	l.position = pos
	parent.add_child(l)


func _garage(r: Node3D, b: StaticBody3D) -> void:
	_box(r, null, Vector3(14, 0.3, 12), Vector3(0, 0.0, 0), Color("#c9c3ba"), false)
	_box(r, b, Vector3(0.4, 6.0, 9.0), Vector3(-6.0, 3.0, -1.0), Color("#e8e4dc"))
	_box(r, b, Vector3(0.4, 6.0, 9.0), Vector3(6.0, 3.0, -1.0), Color("#e8e4dc"))
	_box(r, b, Vector3(12.4, 6.0, 0.4), Vector3(0, 3.0, -5.5), Color("#e8e4dc"))
	_box(r, null, Vector3(13.2, 0.4, 10.0), Vector3(0, 6.2, -1.0), Color("#7d93b2"), false)
	_box(r, null, Vector3(10.0, 0.6, 0.2), Vector3(0, 5.4, 3.5), Color("#2b2d42"), false)
	_sign(r, "GARAGE", Vector3(0, 5.4, 3.65))


func _shed(r: Node3D, b: StaticBody3D, wall: Color, roof: Color, title: String) -> void:
	_box(r, null, Vector3(16, 0.3, 14), Vector3(0, 0.0, 0), Color("#c9c3ba"), false)
	_box(r, b, Vector3(10.0, 5.0, 7.0), Vector3(0, 2.5, -4.0), wall)
	_box(r, null, Vector3(10.6, 0.3, 4.2), Vector3(0, 5.6, -2.2), roof, false, Vector3(20, 0, 0))
	_box(r, null, Vector3(10.6, 0.3, 4.2), Vector3(0, 5.6, -5.8), roof, false, Vector3(-20, 0, 0))
	_box(r, null, Vector3(4.0, 3.5, 0.15), Vector3(0, 1.75, -0.45), Color("#5b5f73"), false)
	for k in 3:
		var p := Cargo.model(["pallet", "pipes", "parts"][k])
		p.position = Vector3(-4.5 + k * 3.0, 0.15, 3.0)
		r.add_child(p)
	_sign(r, title, Vector3(0, 4.0, -0.4))


func _sawmill(r: Node3D, b: StaticBody3D) -> void:
	_shed(r, b, Color("#d9b48f"), Color("#7fb07a"), "SAWMILL")
	for k in 2:
		var p := Cargo.model("planks")
		p.position = Vector3(5.5, 0.15 + k * 0.4, 1.5)
		r.add_child(p)
	var lg := Cargo.model("logs")
	lg.position = Vector3(-6.0, 0.15, 2.0)
	r.add_child(lg)


func _logging(r: Node3D, b: StaticBody3D) -> void:
	_box(r, b, Vector3(4.0, 2.8, 3.0), Vector3(-5.0, 1.4, -3.0), Color("#b08a63"))
	_box(r, null, Vector3(4.4, 0.25, 3.4), Vector3(-5.0, 2.95, -3.0), Color("#7d93b2"), false)
	for k in 3:
		var lg := Cargo.model("logs")
		lg.position = Vector3(1.0 + k * 2.4, 0.0, -2.0)
		lg.scale = Vector3(1.2, 1.2, 1.2)
		r.add_child(lg)
	_sign(r, "LOGGING CAMP", Vector3(-5.0, 3.6, -1.4), 90)


func _farm(r: Node3D, b: StaticBody3D) -> void:
	_box(r, b, Vector3(8.0, 4.5, 6.0), Vector3(0, 2.25, -5.0), Color("#c96b5a"))
	_box(r, null, Vector3(8.6, 0.3, 3.6), Vector3(0, 5.0, -3.6), Color("#5b5f73"), false, Vector3(25, 0, 0))
	_box(r, null, Vector3(8.6, 0.3, 3.6), Vector3(0, 5.0, -6.4), Color("#5b5f73"), false, Vector3(-25, 0, 0))
	var silo := MeshInstance3D.new()
	silo.mesh = LowPoly.cyl(1.6, 1.6, 8.0, 20)
	silo.material_override = LowPoly.mat(Color("#e8e4dc"), 0.6)
	silo.position = Vector3(6.5, 4.0, -5.0)
	r.add_child(silo)
	_sign(r, "FARM", Vector3(0, 3.5, -1.95))


func _site_fence(r: Node3D) -> void:
	for k in 8:
		var a := k * TAU / 8.0
		_box(r, null, Vector3(0.12, 1.1, 0.12), Vector3(cos(a) * 7.0, 0.55, sin(a) * 7.0), Color("#f6bd60"), false)
	var sign := Node3D.new()
	r.add_child(sign)
	_box(sign, null, Vector3(1.8, 1.0, 0.1), Vector3(0, 1.8, -7.2), Color("#f6bd60"), false)
	_box(sign, null, Vector3(0.1, 1.4, 0.1), Vector3(0, 0.7, -7.2), Color("#3a3f4b"), false)


func _stuck_truck(r: Node3D, rescued: bool) -> void:
	var spec := CarSpecs.get_spec("volok")
	var vis := CarBuilder.build_display(spec)
	vis.position = Vector3(0, -0.5 if not rescued else 0.0, 0)
	vis.rotation = Vector3(0.08, 0, -0.12) if not rescued else Vector3.ZERO
	vis.name = "Truck"
	r.add_child(vis)


# --- effects -----------------------------------------------------------------------

func _apply_effect(effect: String) -> void:
	match effect:
		"bridge":
			if not sites.has("bridge"):
				return
			var s: Dictionary = sites["bridge"]
			var pts: PackedVector3Array = terrain.tracks[0]
			var k := int(pts.size() * 0.35)
			var a := pts[maxi(k - 8, 0)]
			var b := pts[mini(k + 8, pts.size() - 1)]
			var mid := (a + b) * 0.5
			var len := Vector2(b.x - a.x, b.z - a.z).length()
			var deck := StaticBody3D.new()
			deck.collision_mask = 0
			add_child(deck)
			deck.global_position = Vector3(mid.x, maxf(a.y, b.y) + 0.35, mid.z)
			deck.look_at(Vector3(b.x, deck.global_position.y, b.z), Vector3.UP)
			_box(deck, deck, Vector3(5.0, 0.4, len + 2.0), Vector3.ZERO, Color("#b08a63"))
			for x in [-2.4, 2.4]:
				_box(deck, null, Vector3(0.15, 0.8, len + 2.0), Vector3(x, 0.6, 0), Color("#8a6a4d"), false)
			# Ramps down to the ground at both ends.
			for e in [-1.0, 1.0]:
				_box(deck, deck, Vector3(5.0, 0.3, 4.0), Vector3(0, -0.35, e * (len * 0.5 + 2.6)), Color("#b08a63"), true, Vector3(e * 8.0, 0, 0))
		"tower":
			if not sites.has("lookout"):
				return
			var r: Node3D = sites["lookout"]["root"]
			for x in [-1.6, 1.6]:
				for z in [-1.6, 1.6]:
					_box(r, null, Vector3(0.25, 12.0, 0.25), Vector3(x, 6.0, z), Color("#8a6a4d"), false)
			_box(r, null, Vector3(4.6, 0.3, 4.6), Vector3(0, 12.0, 0), Color("#b08a63"), false)
			_box(r, null, Vector3(5.0, 0.25, 5.0), Vector3(0, 14.4, 0), Color("#c96b5a"), false)
			reveal_all = true
		"rescue":
			if sites.has("stuck"):
				var r: Node3D = sites["stuck"]["root"]
				var t := r.get_node_or_null("Truck") as Node3D
				if t:
					t.position = Vector3.ZERO
					t.rotation = Vector3.ZERO


# --- contracts ---------------------------------------------------------------------

func contract_state(id: String) -> Dictionary:
	var all: Dictionary = GameState.map_state()["contracts"]
	if not all.has(id):
		all[id] = {"got": {}, "done": false, "runs": 0}
	return all[id]


## Contracts you can work on now (not done, and their prerequisite is done).
func active_contracts() -> Array:
	var out: Array = []
	for c in CONTRACTS:
		if not sites.has(c["site"]):
			continue
		var st := contract_state(c["id"])
		if st["done"] and not c.get("repeat", false):
			continue
		if c.has("after") and not contract_state(c["after"])["done"]:
			continue
		out.append(c)
	return out


func remaining(c: Dictionary) -> Dictionary:
	var st := contract_state(c["id"])
	var got: Dictionary = st["got"]
	var out := {}
	for t in c["needs"]:
		var left := int(c["needs"][t]) - int(got.get(t, 0))
		if left > 0:
			out[t] = left
	return out


func _complete(c: Dictionary) -> void:
	var st := contract_state(c["id"])
	st["done"] = true
	st["runs"] = int(st["runs"]) + 1
	st["got"] = {}
	if c.has("effect"):
		var built: Array = GameState.map_state()["built"]
		if not built.has(c["effect"]):
			built.append(c["effect"])
		_apply_effect(c["effect"])
	GameState.reward(int(c["cash"]), int(c["xp"]))
	contract_done.emit(c["title"], int(c["cash"]), int(c["xp"]))
	changed.emit()


# --- interaction -------------------------------------------------------------------

func _in_zone(body: Node3D, id: String) -> bool:
	if not sites.has(id):
		return false
	var p: Vector3 = sites[id]["pos"]
	return Vector2(body.global_position.x - p.x, body.global_position.z - p.z).length() < ZONE


func zone_of(car: Car) -> String:
	for id in sites:
		if _in_zone(car, id) or (car.trailer and _in_zone(car.trailer, id)):
			return id
	return ""


func _near_log_pile(car: Car) -> bool:
	for p in log_piles:
		if (p as Vector3).distance_to(car.global_position) < 12.0:
			return true
	return false


func _near_pile(car: Car) -> int:
	for i in piles.size():
		if (piles[i]["pos"] as Vector3).distance_to(car.global_position) < 12.0:
			return i
	return -1


## What pressing T would do here, for the HUD prompt ("" = nothing).
func hint(car: Car) -> String:
	if car.linear_velocity.length() > 2.0:
		return ""
	var z := zone_of(car)
	if z == "garage":
		return "Open the garage"
	var crane := str(car.spec.get("crane", ""))
	if crane == "any" and _near_pile(car) >= 0:
		return "Lift the spilled %s with the crane" % Cargo.type_name(piles[_near_pile(car)]["type"])
	if crane == "logs" and _near_log_pile(car) and car.carrier() != null:
		return "Load logs with the crane"
	if z == "":
		return ""
	var s: Dictionary = sites[z]
	if not (s["products"] as Array).is_empty() and car.carrier() != null:
		return "Load cargo at the %s" % s["name"]
	for c in active_contracts():
		if c["site"] == z and not car.carrier_load().is_empty():
			return "Unload for \"%s\"" % c["title"]
	return ""


## Does the job for this spot; returns a message (or "garage" to open the garage screen).
func interact(car: Car) -> String:
	if car.linear_velocity.length() > 2.0:
		return "Stop first"
	var z := zone_of(car)
	if z == "garage":
		return "garage"
	var crane := str(car.spec.get("crane", ""))
	if crane == "any":
		var i := _near_pile(car)
		if i >= 0:
			var t: String = piles[i]["type"]
			if Cargo.fits(car.carrier_spec(), car.carrier_load(), t):
				var l := car.carrier_load().duplicate()
				l.append(t)
				car.set_carrier_load(l)
				(piles[i]["node"] as Node).queue_free()
				piles.remove_at(i)
				return "Lifted the %s onto the bed" % Cargo.type_name(t)
			return "No room on the bed for that"
	if crane == "logs" and _near_log_pile(car) and z != "sawmill":
		return _load(car, "logs")
	if z == "":
		return "Nothing to do here. Open the map (M) to see the jobs"
	# Deliver first, then load.
	var delivered := _deliver(car, z)
	if delivered != "":
		return delivered
	var products: Array = sites[z]["products"]
	if products.is_empty():
		return "Nothing needed here right now"
	if car.carrier() == null:
		return "This vehicle can't carry cargo"
	# Load what an open contract needs first.
	var wanted: Array = []
	for c in active_contracts():
		for t in remaining(c):
			if products.has(t) and not wanted.has(t):
				wanted.append(t)
	for t in products:
		if not wanted.has(t):
			wanted.append(t)
	for t in wanted:
		if Cargo.fits(car.carrier_spec(), car.carrier_load(), t):
			return _load(car, t)
	if wanted.has("logs"):
		return "Logs need a logging truck"
	return "The bed is full"


func _load(car: Car, t: String) -> String:
	if not Cargo.fits(car.carrier_spec(), car.carrier_load(), t):
		return "No room for %s" % Cargo.type_name(t)
	var l := car.carrier_load().duplicate()
	l.append(t)
	car.set_carrier_load(l)
	var slots := int(Cargo.bed(car.carrier_spec())["slots"])
	return "Loaded %s  (%d / %d slots)" % [Cargo.type_name(t), Cargo.used_slots(l), slots]


func _deliver(car: Car, z: String) -> String:
	var load := car.carrier_load().duplicate()
	if load.is_empty():
		return ""
	var given: Array = []
	for c in active_contracts():
		if c["site"] != z:
			continue
		var st := contract_state(c["id"])
		var need := remaining(c)
		for t in need:
			var n := int(need[t])
			while n > 0 and load.has(t):
				load.erase(t)
				st["got"][t] = int(st["got"].get(t, 0)) + 1
				given.append(t)
				n -= 1
		if remaining(c).is_empty():
			_complete(c)
	if given.is_empty():
		return ""
	car.set_carrier_load(load)
	GameState.save_game()
	changed.emit()
	return "Delivered %d load%s" % [given.size(), "" if given.size() == 1 else "s"]


func spill(at: Vector3, load: Array) -> void:
	for k in load.size():
		var t: String = load[k]
		var p := at + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
		p.y = terrain.get_height(p.x, p.z)
		var m := Cargo.model(t)
		m.position = p
		m.rotation = Vector3(randf_range(-0.2, 0.2), randf() * TAU, randf_range(-0.2, 0.2))
		add_child(m)
		piles.append({"pos": p, "type": t, "node": m})
