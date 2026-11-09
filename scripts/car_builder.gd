class_name CarBuilder
extends RefCounted
## Builds vehicle bodies (visual only) and drivable VehicleBody3D vehicles from a spec.
## garage: {"tyres": String, "snorkel": bool}


static func _top(spec: Dictionary) -> float:
	var top := 1.0
	for c in spec["collision"]:
		top = maxf(top, (c[1] as Vector3).y + (c[0] as Vector3).y * 0.5)
	return top


## Returns the body; paint materials (for dirt) are stored in its "paint_mats" meta.
static func build_visual(spec: Dictionary, garage := {}) -> Node3D:
	var root := Node3D.new()
	root.name = "Visual"
	var colors: Dictionary = spec["colors"]
	var mats := {}
	var paint_mats: Array = []
	var parts: Array = (spec["parts"] as Array).duplicate()
	if garage.get("snorkel", false) and spec.has("snorkel_parts"):
		parts.append_array(spec["snorkel_parts"])
	var top := _top(spec)
	parts.append_array(_lamps(parts))
	for p in parts:
		root.add_child(_part(p, colors, mats, paint_mats, top))
	root.set_meta("paint_mats", paint_mats)
	return root


## Reverse lights next to each tail light, amber indicators above the tails and below the headlights.
static func _lamps(parts: Array) -> Array:
	var out: Array = []
	for p in parts:
		var key: String = p[3]
		var dims: Vector3 = p[1]
		var pos: Vector3 = p[2]
		var s := signf(pos.x) if absf(pos.x) > 0.05 else 1.0
		if key == "tail":
			out.append(["fbox", Vector3(dims.x * 0.8, dims.y * 0.6, 0.03), pos - Vector3(s * (dims.x + 0.04), 0, 0), "reverse"])
			out.append(["fbox", Vector3(dims.x, dims.y * 0.55, 0.03), pos + Vector3(0, dims.y * 0.85, 0), "amber"])
		elif key == "light" and absf(pos.x) > 0.4:
			var h: float = dims.x if p[0] == "cyl" else dims.y
			out.append(["fbox", Vector3(0.14, 0.06, 0.03), pos + Vector3(s * 0.02, -h - 0.06, 0.01), "amber"])
	return out


static func _material(key: String, colors: Dictionary, mats: Dictionary, paint_mats: Array, top: float) -> Material:
	if mats.has(key):
		return mats[key]
	var c: Color = colors.get(key, Color.MAGENTA)
	var m: Material
	match key:
		"glass":
			var g := StandardMaterial3D.new()
			g.albedo_color = c
			g.roughness = 0.08
			g.metallic = 0.5
			m = g
		"light", "tail", "reverse", "amber":
			if key == "reverse":
				c = Color("#f4f4f0")
			elif key == "amber":
				c = Color("#ffb347")
			var e := StandardMaterial3D.new()
			e.albedo_color = c.darkened(0.25)
			e.emission_enabled = true
			e.emission = c
			e.emission_energy_multiplier = 0.15
			m = e
		"tyre":
			m = MeshKit.rubber()
		_:
			var pm := MeshKit.paint(c)
			pm.set_shader_parameter("roughness", 0.65 if key == "trim" else 0.42)
			pm.set_shader_parameter("dirt_top", top)
			paint_mats.append(pm)
			m = pm
	mats[key] = m
	return m


static func _part(p: Array, colors: Dictionary, mats: Dictionary, paint_mats: Array, top: float) -> Node3D:
	var kind: String = p[0]
	var key: String = p[3]
	if kind == "label":
		var l := Label3D.new()
		l.text = str(p[1])
		l.position = p[2]
		l.rotation_degrees = p[4]
		l.font_size = 72
		l.pixel_size = 0.0035
		l.outline_size = 0
		l.modulate = colors.get(key, Color.BLACK)
		l.double_sided = false
		return l
	var dims: Vector3 = p[1]
	var mesh: Mesh
	match kind:
		"cyl":
			mesh = LowPoly.cyl(dims.x, dims.y, dims.z, 20)
		"box":
			mesh = MeshKit.rbox(dims, clampf(minf(dims.x, minf(dims.y, dims.z)) * 0.22, 0.01, 0.14))
		_:
			mesh = LowPoly.box(dims)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _material(key, colors, mats, paint_mats, top)
	if key in ["tail", "light", "reverse", "amber"]:
		mi.add_to_group("lamp_" + key)
	mi.position = p[2]
	if p.size() > 4:
		mi.rotation_degrees = p[4]
	return mi


static func build_wheel_visual(spec: Dictionary, garage := {}) -> Node3D:
	var w: Dictionary = spec["wheel"]
	var colors: Dictionary = spec["colors"]
	var r: float = w["radius"]
	var width: float = w["width"]
	var tyres := str(garage.get("tyres", spec.get("tyres", "allroad")))
	var lugs: int = int(w.get("lugs", 16)) + (8 if tyres == "mud" else 0) - (6 if tyres == "highway" else 0)
	var root := Node3D.new()
	var tyre := MeshInstance3D.new()
	tyre.mesh = MeshKit.tyre(r, width, maxi(lugs, 8))
	tyre.material_override = MeshKit.rubber()
	root.add_child(tyre)
	var hub := MeshInstance3D.new()
	hub.mesh = LowPoly.cyl(r * 0.55, r * 0.55, width + 0.03, 16)
	hub.material_override = MeshKit.paint(colors["hub"])
	hub.rotation_degrees = Vector3(0, 0, 90)
	root.add_child(hub)
	var cap := MeshInstance3D.new()
	cap.mesh = LowPoly.cyl(r * 0.18, r * 0.18, width + 0.06, 10)
	cap.material_override = MeshKit.paint(colors["trim"])
	cap.rotation_degrees = Vector3(0, 0, 90)
	root.add_child(cap)
	if tyres == "chains":
		for i in 6:
			var ch := MeshInstance3D.new()
			ch.mesh = LowPoly.box(Vector3(width * 1.02, 0.03, 0.04))
			ch.material_override = LowPoly.mat(Color("#9aa0a8"), 0.4)
			var a := TAU * i / 6.0
			ch.position = Vector3(0, cos(a), sin(a)) * r * 0.99
			ch.rotation = Vector3(a, 0, 0)
			root.add_child(ch)
	return root


## Two wheels per axle: [+x, -x] for each axle, front to back.
static func wheel_positions(spec: Dictionary) -> Array:
	var w: Dictionary = spec["wheel"]
	var x: float = w["x"]
	var y: float = w["y"]
	var out: Array = []
	for a in spec["axles"]:
		var z: float = a["z"]
		out.append(Vector3(x, y, z))
		out.append(Vector3(-x, y, z))
	return out


## A static model sitting on y = 0, for the menu turntable.
static func build_display(spec: Dictionary, garage := {}) -> Node3D:
	var w: Dictionary = spec["wheel"]
	var root := Node3D.new()
	var car := Node3D.new()
	root.add_child(car)
	car.add_child(build_visual(spec, garage))
	var n_wheels := (spec["axles"] as Array).size() * 2
	var sag := 9.8 / (n_wheels * float(w["stiffness"]))
	var drop: float = float(w["rest"]) - sag
	for p in wheel_positions(spec):
		var wv := build_wheel_visual(spec, garage)
		wv.position = p - Vector3(0, drop, 0)
		car.add_child(wv)
	car.position.y = float(w["radius"]) - (float(w["y"]) - drop)
	return root


static func build_vehicle(spec: Dictionary, garage := {}) -> Car:
	var w: Dictionary = spec["wheel"]
	var car := Car.new()
	car.name = "Car"
	car.spec = spec
	car.garage = garage
	car.mass = spec["mass"]
	car.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	car.center_of_mass = spec["com"]
	car.collision_layer = 2
	car.collision_mask = 1 | 2 | 4
	car.can_sleep = false
	for c in spec["collision"]:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = c[0]
		cs.shape = box
		cs.position = c[1]
		car.add_child(cs)
	var visual := build_visual(spec, garage)
	car.add_child(visual)
	car.paint_mats = visual.get_meta("paint_mats")
	for n in visual.get_children():
		for k in ["tail", "light", "reverse", "amber"]:
			if n.is_in_group("lamp_" + k):
				var mat: Material = (n as MeshInstance3D).material_override
				if not (car.lamp_mats[k] as Array).has(mat):
					(car.lamp_mats[k] as Array).append(mat)
	var positions := wheel_positions(spec)
	var axles: Array = spec["axles"]
	var names := ["L", "R"]
	for i in positions.size():
		var axle: Dictionary = axles[i / 2]
		var wheel := VehicleWheel3D.new()
		wheel.name = "Wheel%d%s" % [i / 2, names[i % 2]]
		wheel.position = positions[i]
		wheel.wheel_radius = w["radius"]
		wheel.wheel_rest_length = w["rest"]
		wheel.suspension_travel = w["travel"]
		wheel.suspension_stiffness = w["stiffness"]
		wheel.suspension_max_force = float(spec["mass"]) * 45.0
		wheel.damping_compression = w["comp"]
		wheel.damping_relaxation = w["relax"]
		wheel.wheel_friction_slip = w["slip"]
		wheel.wheel_roll_influence = w["roll"]
		wheel.use_as_steering = bool(axle["steer"])
		wheel.use_as_traction = bool(axle["drive"])
		wheel.set_meta("axle", i / 2)
		wheel.add_child(build_wheel_visual(spec, garage))
		car.add_child(wheel)
	var front_z: float = (axles[0] as Dictionary)["z"]
	var top := _top(spec)
	for side in [0.0]:
		var l := SpotLight3D.new()
		l.position = Vector3(side, top * 0.45, front_z + 0.7)
		l.rotation_degrees = Vector3(-6, 180, 0)
		l.spot_range = 40.0
		l.spot_angle = 40.0
		l.light_color = Color("#fff1c9")
		l.light_energy = 0.0
		l.visible = false
		car.add_child(l)
	return car
