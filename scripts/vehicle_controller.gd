class_name Car
extends VehicleBody3D
## Player car: engine + manual gearbox (with low range on the 4x4s), brakes, drag,
## air control, flip and water resets, dust.

signal was_reset
signal message(text: String)

const SHIFT_TIME := 0.25
const EFFICIENCY := 0.85

var spec: Dictionary = {}
var terrain: Terrain
var autopilot := false
var auto_target := Vector3.ZERO

var wheels: Array[VehicleWheel3D] = []
var traction: Array[VehicleWheel3D] = []
var rear: Array[VehicleWheel3D] = []
var lights: Array[SpotLight3D] = []

var gear := 1          ## -1 reverse, 0 neutral, 1..n
var low_range := false
var engine_rpm := 900.0
var throttle := 0.0    ## 0..1, for the engine sound
var rpm := 0.2         ## engine_rpm / redline, for the sound and the HUD
var fwd_speed := 0.0   ## m/s along the car's nose
var grounded := false
var trip := 0.0        ## metres driven on the ground
var resets := 0

var _dt: Dictionary
var _steer := 0.0
var _shift_t := 0.0
var _flip_t := 0.0
var _safe_t := 0.0
var _last_safe := Transform3D.IDENTITY
var _stuck_t := 0.0
var _reverse_t := 0.0
var _dust: CPUParticles3D


func setup_wheels() -> void:
	_dt = spec["drivetrain"]
	engine_rpm = _dt["idle"]
	for c in get_children():
		if c is VehicleWheel3D:
			var w := c as VehicleWheel3D
			wheels.append(w)
			if w.use_as_traction:
				traction.append(w)
			if not w.use_as_steering:
				rear.append(w)
		elif c is SpotLight3D:
			lights.append(c as SpotLight3D)
	_last_safe = global_transform
	_make_dust()


func gear_count() -> int:
	return (_dt["gears"] as Array).size()


func has_low() -> bool:
	return float(_dt["low"]) > 0.0


func is_auto() -> bool:
	return autopilot or bool(GameState.settings.get("auto_gearbox", false))


func gear_text() -> String:
	if gear < 0:
		return "R"
	if gear == 0:
		return "N"
	return str(gear)


## Overall ratio engine -> wheel, signed (negative in reverse), 0 in neutral.
func _ratio() -> float:
	if gear == 0:
		return 0.0
	var gears: Array = _dt["gears"]
	var g: float = gears[0] * 1.1 if gear < 0 else gears[gear - 1]
	var range_r: float = _dt["low"] if low_range else _dt["high"]
	var r: float = g * float(_dt["final"]) * range_r
	return -r if gear < 0 else r


func _torque(r: float) -> float:
	var peak: float = _dt["torque"]
	var pr: float = _dt["peak_rpm"]
	var red: float = _dt["redline"]
	if r <= pr:
		return peak * (0.62 + 0.38 * clampf(r / pr, 0.0, 1.0))
	var f := (r - pr) / (red - pr)
	return peak * (1.0 - 0.45 * f * f)


func _shift(to: int) -> void:
	to = clampi(to, -1, gear_count())
	if to == gear:
		return
	if to < 0 and fwd_speed > 1.5:
		message.emit("Stop before reverse")
		return
	gear = to
	_shift_t = SHIFT_TIME


func _toggle_low() -> void:
	if not has_low():
		message.emit("No low range on this car")
		return
	if absf(fwd_speed) > 3.0:
		message.emit("Slow down to change range")
		return
	low_range = not low_range
	_shift_t = SHIFT_TIME * 2.0
	message.emit("Low range" if low_range else "Normal range")


func _physics_process(delta: float) -> void:
	var gas := 0.0
	var brk := 0.0
	var steer_in := 0.0
	var hb := false
	var b := global_transform.basis
	var speed := linear_velocity.length()
	fwd_speed = linear_velocity.dot(b.z)

	if autopilot:
		var to := auto_target - global_position
		to.y = 0.0
		var local := b.inverse() * to
		steer_in = clampf(atan2(local.x, local.z) * 1.5, -1.0, 1.0)
		gas = 0.85
		if speed < 1.0 and grounded:
			_stuck_t += delta
		else:
			_stuck_t = maxf(0.0, _stuck_t - delta)
		if _stuck_t > 2.5:
			if has_low() and not low_range:
				low_range = true
			else:
				_reverse_t = 1.5
			_stuck_t = 0.0
		if _reverse_t > 0.0:
			_reverse_t -= delta
			gas = 0.0
			brk = 1.0
			steer_in = -steer_in
	else:
		gas = Input.get_action_strength("gas")
		brk = Input.get_action_strength("brake")
		steer_in = Input.get_action_strength("left") - Input.get_action_strength("right")
		hb = Input.is_action_pressed("handbrake")
		if Input.is_action_just_pressed("reset"):
			reset_car(false)
			return
		if Input.is_action_just_pressed("low_range"):
			_toggle_low()
		if not is_auto():
			if Input.is_action_just_pressed("shift_up"):
				_shift(gear + 1)
			if Input.is_action_just_pressed("shift_down"):
				_shift(gear - 1)

	var red: float = _dt["redline"]
	var idle: float = _dt["idle"]
	var radius: float = (spec["wheel"] as Dictionary)["radius"]
	var brake_max: float = spec["brake"]

	# Automatic: S brakes, then reverses once stopped.
	if is_auto():
		if gear < 0:
			if gas > 0.1 and fwd_speed > -0.5:
				_shift(1)
			else:
				var g2 := gas
				gas = brk
				brk = g2
		elif brk > 0.1 and gas < 0.05 and fwd_speed < 0.5:
			_shift(-1)
			gas = brk
			brk = 0.0
		if gear == 0:
			gear = 1

	# Engine speed from the driven wheels' ground speed.
	var ratio := _ratio()
	var wheel_rpm := absf(fwd_speed) / (TAU * radius) * 60.0
	var linked := wheel_rpm * absf(ratio)
	_shift_t = maxf(0.0, _shift_t - delta)
	var clutch_in := ratio == 0.0 or _shift_t > 0.0
	var target_rpm: float
	if clutch_in:
		target_rpm = idle + gas * (red - idle) * 0.85
	else:
		# The clutch slips at launch, so the engine never drops below a launch rpm with gas.
		var launch: float = idle + gas * (float(_dt["peak_rpm"]) - idle) * 0.85
		target_rpm = maxf(linked, launch if gas > 0.05 else idle)
		if not grounded:
			target_rpm = maxf(target_rpm, idle + gas * (red - idle) * 0.9)
	engine_rpm = lerpf(engine_rpm, minf(target_rpm, red * 1.02), 1.0 - exp(-delta * 10.0))
	rpm = engine_rpm / red

	if is_auto() and gear > 0 and _shift_t <= 0.0 and grounded:
		if linked > red * 0.9 and gear < gear_count():
			_shift(gear + 1)
		elif gear > 1:
			var gears: Array = _dt["gears"]
			var lower := linked * float(gears[gear - 2]) / float(gears[gear - 1])
			if lower < red * 0.6:
				_shift(gear - 1)

	var force := 0.0
	var brake_v := brk * brake_max
	if not clutch_in:
		if linked < red:
			force = _torque(engine_rpm) * gas * ratio * EFFICIENCY / radius
		if gas < 0.05:
			# Engine braking, stronger in low gears.
			brake_v += clampf(linked / red, 0.0, 1.0) * absf(ratio) * 0.012 * brake_max
	brake_v += brake_max * 0.015  # rolling resistance
	var per := force / maxf(traction.size(), 1.0)
	for w in wheels:
		w.engine_force = per if w.use_as_traction else 0.0
		w.brake = brake_v
	if hb:
		for w in rear:
			w.brake = brake_max * 1.6
			w.engine_force = 0.0
	# Air drag.
	var cda: float = _dt["cda"]
	apply_central_force(-linear_velocity * speed * cda * 0.6)

	var top: float = spec["top_speed"]
	var steer_max: float = spec["steer_max"]
	var steer_lim := lerpf(steer_max, steer_max * 0.35, clampf(absf(fwd_speed) / top, 0.0, 1.0))
	_steer = move_toward(_steer, steer_in * steer_lim, delta * 2.2)
	steering = _steer

	var contacts := 0
	for w in wheels:
		if w.is_in_contact():
			contacts += 1
	grounded = contacts > 0
	if contacts == 0:
		apply_torque((b.x * (brk - gas) * 1.6 - b.z * steer_in * 1.2) * mass)
	throttle = gas

	_dust.emitting = contacts >= 2 and speed > 4.0 and global_position.y > 1.0
	_dust.initial_velocity_max = 1.0 + speed * 0.15

	# Resets: on the roof for 2 s, or in the sea.
	var up_y := b.y.y
	if up_y < 0.3 and speed < 3.0:
		_flip_t += delta
	else:
		_flip_t = 0.0
	if _flip_t > 2.0:
		reset_car(false)
		return
	if global_position.y < -0.9:
		reset_car(true)
		return
	if contacts == wheels.size() and up_y > 0.85 and global_position.y > 0.6:
		_safe_t += delta
		if _safe_t > 1.0:
			_safe_t = 0.0
			_last_safe = global_transform
	if grounded:
		trip += Vector2(linear_velocity.x, linear_velocity.z).length() * delta


## Puts the car back on its wheels where it is (or at the last safe spot), facing the same way.
func reset_car(to_safe: bool) -> void:
	var src := _last_safe if to_safe else global_transform
	var f := src.basis.z
	f.y = 0.0
	if f.length() < 0.1:
		f = Vector3(0, 0, 1)
	f = f.normalized()
	var p := src.origin
	var h := terrain.get_height(p.x, p.z) if terrain else p.y
	p.y = maxf(h, 0.0) + 1.6
	var t := Transform3D(Basis.looking_at(-f, Vector3.UP), p)
	var rid := get_rid()
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, t)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)
	_flip_t = 0.0
	_steer = 0.0
	if not is_auto():
		gear = 1
	resets += 1
	was_reset.emit()


func set_night(darkness: float) -> void:
	for l in lights:
		l.visible = darkness > 0.05
		l.light_energy = darkness * 4.0


func _make_dust() -> void:
	_dust = CPUParticles3D.new()
	_dust.amount = 28
	_dust.lifetime = 1.4
	_dust.emitting = false
	_dust.local_coords = false
	_dust.position = Vector3(0, -0.1, float((spec["wheel"] as Dictionary)["rear_z"]) - 0.3)
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_dust.emission_box_extents = Vector3(0.7, 0.05, 0.2)
	_dust.direction = Vector3(0, 0.6, -1)
	_dust.spread = 35.0
	_dust.gravity = Vector3(0, 0.4, 0)
	_dust.initial_velocity_min = 0.5
	_dust.initial_velocity_max = 2.0
	_dust.damping_min = 1.5
	_dust.damping_max = 2.5
	_dust.scale_amount_min = 0.6
	_dust.scale_amount_max = 1.6
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 1.6))
	_dust.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.93, 0.88, 0.8, 0.45))
	ramp.set_color(1, Color(0.93, 0.88, 0.8, 0.0))
	_dust.color_ramp = ramp
	var q := QuadMesh.new()
	q.size = Vector2(0.7, 0.7)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	tex.gradient = g
	m.albedo_texture = tex
	q.material = m
	_dust.mesh = q
	add_child(_dust)


## Compact state for the multiplayer sync (phase 2).
func net_state() -> Array:
	return [global_transform, linear_velocity, _steer, rpm, throttle, gear]
