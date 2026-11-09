class_name Car
extends VehicleBody3D
## Player car: input, per-wheel drive, air control, flip and water resets, fake gearbox for the engine sound.

signal was_reset

var spec: Dictionary = {}
var terrain: Terrain
var autopilot := false
var auto_target := Vector3.ZERO

var wheels: Array[VehicleWheel3D] = []
var traction: Array[VehicleWheel3D] = []
var rear: Array[VehicleWheel3D] = []
var lights: Array[SpotLight3D] = []

var throttle := 0.0   ## 0..1, for the engine sound
var rpm := 0.2        ## 0..1, fake gearbox
var fwd_speed := 0.0  ## m/s along the car's nose
var grounded := false
var trip := 0.0       ## metres driven on the ground
var resets := 0

var _steer := 0.0
var _flip_t := 0.0
var _safe_t := 0.0
var _last_safe := Transform3D.IDENTITY
var _stuck_t := 0.0
var _reverse_t := 0.0


func setup_wheels() -> void:
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

	var top: float = spec["top_speed"]
	var ef: float = spec["engine_force"]
	var brake_max: float = spec["brake"]
	var force := 0.0
	var brake_v := 0.0
	if gas > 0.05:
		if fwd_speed < -1.0:
			brake_v = brake_max * gas
		else:
			force = ef * gas * clampf(1.0 - pow(maxf(fwd_speed, 0.0) / top, 2.0), 0.0, 1.0)
	if brk > 0.05:
		if fwd_speed > 1.0:
			brake_v = maxf(brake_v, brake_max * brk)
		elif fwd_speed > -7.0:
			force = -ef * 0.5 * brk
	if gas <= 0.05 and brk <= 0.05:
		brake_v = brake_max * 0.06
	var per := force / maxf(traction.size(), 1.0)
	for w in wheels:
		w.engine_force = per if w.use_as_traction else 0.0
		w.brake = brake_v
	if hb:
		for w in rear:
			w.brake = brake_max * 1.6
			w.engine_force = 0.0

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
		apply_torque((b.x * (brk - gas) * 2.2 - b.z * steer_in * 1.6) * mass)

	# Fake gearbox so the engine note rises and drops.
	var ratio := absf(fwd_speed) / top
	var gears := [0.0, 0.2, 0.42, 0.66, 0.9, 1.3]
	var g := 0
	while g < gears.size() - 2 and ratio > float(gears[g + 1]):
		g += 1
	var lo: float = gears[g]
	var hi: float = gears[g + 1]
	var target_rpm := 0.22 + 0.68 * clampf((ratio - lo) / (hi - lo), 0.0, 1.0)
	if not grounded or (gas > 0.5 and speed < 1.5):
		target_rpm = 0.25 + 0.7 * gas
	rpm = lerpf(rpm, target_rpm, 1.0 - exp(-delta * 8.0))
	throttle = maxf(gas, brk if fwd_speed < 1.0 else 0.0)

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
	resets += 1
	was_reset.emit()


func set_night(darkness: float) -> void:
	for l in lights:
		l.visible = darkness > 0.05
		l.light_energy = darkness * 3.0


## Compact state for the multiplayer sync (phase 2).
func net_state() -> Array:
	return [global_transform, linear_velocity, _steer, rpm, throttle]
