class_name CarBuilder
extends RefCounted
## Builds car bodies (visual only) and drivable VehicleBody3D cars from a spec.


static func build_visual(spec: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Visual"
	var colors: Dictionary = spec["colors"]
	for p in spec["parts"]:
		root.add_child(_part(p, colors))
	return root


static func _part(p: Array, colors: Dictionary) -> Node3D:
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
	if kind == "cyl":
		mesh = LowPoly.cyl(dims.x, dims.y, dims.z, 12)
	else:
		mesh = LowPoly.box(dims)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var c: Color = colors.get(key, Color.MAGENTA)
	var rough := 0.35 if key == "glass" else 0.85
	var emission := 0.0
	if key == "light":
		emission = 0.6
	elif key == "tail":
		emission = 0.4
	if key == "tail":
		var tm := StandardMaterial3D.new()
		tm.albedo_color = c
		tm.emission_enabled = true
		tm.emission = c
		tm.emission_energy_multiplier = emission
		mi.material_override = tm
		mi.add_to_group("tail_light")
	else:
		mi.material_override = LowPoly.mat(c, rough, emission)
	mi.position = p[2]
	if p.size() > 4:
		mi.rotation_degrees = p[4]
	return mi


static func build_wheel_visual(spec: Dictionary) -> Node3D:
	var w: Dictionary = spec["wheel"]
	var colors: Dictionary = spec["colors"]
	var r: float = w["radius"]
	var width: float = w["width"]
	var root := Node3D.new()
	var tyre := MeshInstance3D.new()
	tyre.mesh = LowPoly.cyl(r, r, width, 14)
	tyre.material_override = LowPoly.mat(colors["tyre"], 0.95)
	tyre.rotation_degrees = Vector3(0, 0, 90)
	root.add_child(tyre)
	var hub := MeshInstance3D.new()
	hub.mesh = LowPoly.cyl(r * 0.5, r * 0.5, width + 0.02, 8)
	hub.material_override = LowPoly.mat(colors["hub"], 0.7)
	hub.rotation_degrees = Vector3(0, 0, 90)
	root.add_child(hub)
	return root


static func wheel_positions(spec: Dictionary) -> Array:
	var w: Dictionary = spec["wheel"]
	var x: float = w["x"]
	var y: float = w["y"]
	var fz: float = w["front_z"]
	var rz: float = w["rear_z"]
	return [Vector3(x, y, fz), Vector3(-x, y, fz), Vector3(x, y, rz), Vector3(-x, y, rz)]


## A static model sitting on y = 0, for the menu turntable (and later remote players).
static func build_display(spec: Dictionary) -> Node3D:
	var w: Dictionary = spec["wheel"]
	var root := Node3D.new()
	var car := Node3D.new()
	root.add_child(car)
	car.add_child(build_visual(spec))
	var drop: float = float(w["rest"]) + 0.06
	for p in wheel_positions(spec):
		var wv := build_wheel_visual(spec)
		wv.position = p - Vector3(0, drop, 0)
		car.add_child(wv)
	car.position.y = float(w["radius"]) - (float(w["y"]) - drop)
	return root


static func build_vehicle(spec: Dictionary) -> Car:
	var w: Dictionary = spec["wheel"]
	var car := Car.new()
	car.name = "Car"
	car.spec = spec
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
	var visual := build_visual(spec)
	car.add_child(visual)
	for n in visual.get_children():
		if n.is_in_group("tail_light"):
			car.tail_mats.append((n as MeshInstance3D).material_override)
	var awd: bool = spec["drive"] == "awd"
	var positions := wheel_positions(spec)
	for i in positions.size():
		var front := i < 2
		var wheel := VehicleWheel3D.new()
		wheel.name = ["WheelFL", "WheelFR", "WheelRL", "WheelRR"][i]
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
		wheel.use_as_steering = front
		wheel.use_as_traction = front or awd
		wheel.add_child(build_wheel_visual(spec))
		car.add_child(wheel)
	for side in [0.0]:
		var l := SpotLight3D.new()
		l.position = Vector3(side, 0.5, 1.6)
		l.rotation_degrees = Vector3(-6, 180, 0)
		l.spot_range = 34.0
		l.spot_angle = 40.0
		l.light_color = Color("#fff1c9")
		l.light_energy = 0.0
		l.visible = false
		car.add_child(l)
	return car
