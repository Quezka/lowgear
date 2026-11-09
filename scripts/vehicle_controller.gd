class_name Car
extends VehicleBody3D
## Player vehicle: engine + manual gearbox (low range), open diffs / diff lock, switchable AWD,
## tyre grip per surface, mud sinking, water flooding (snorkel), fuel, winch, flip recovery.

signal was_reset
signal message(text: String)
signal spilled(at: Vector3, load: Array)

const SHIFT_TIME := 0.25
const EFFICIENCY := 0.85
const DUST := [Color(0.62, 0.6, 0.48), Color(0.88, 0.8, 0.66), Color(0.72, 0.7, 0.74), Color(1, 1, 1),
	Color(0.85, 0.93, 1.0), Color(0.36, 0.28, 0.2), Color(0.74, 0.72, 0.68)]
const WINCH_RANGE := 30.0

var spec: Dictionary = {}
var garage: Dictionary = {}
var terrain: Terrain
var tracks: TyreTracks
var anchors: Callable          ## () -> Array[Vector3]: things the winch can hook onto
var autopilot := false
var auto_target := Vector3.ZERO

var wheels: Array[VehicleWheel3D] = []
var rear: Array[VehicleWheel3D] = []
var lights: Array[SpotLight3D] = []
var lamp_mats := {"tail": [], "light": [], "reverse": [], "amber": []}
var paint_mats: Array = []
var cargo_holder: Node3D
var load: Array = []
var trailer: Trailer
var _base_mass := 1000.0
var _base_com := Vector3.ZERO
var _drive_radius := 0.3

var gear := 1          ## -1 reverse, 0 neutral, 1..n
var low_range := false
var awd_on := true
var diff_locked := false
var engine_on := true
var fuel := 30.0
var engine_rpm := 900.0
var clutch := 1.0       ## 0 = pedal down (disengaged), 1 = engaged
var _clutch_pedal := 0.0
var throttle := 0.0
var rpm := 0.2
var fwd_speed := 0.0
var grounded := false
var trip := 0.0
var resets := 0
var surface := 0
var skid := 0.0
var jolt := 0.0
var braking := false
var sink := 0.0        ## 0..1 average, for the HUD
var dirt := 0.0
var winch_anchor := Vector3.INF
var winch_len := 0.0
var engine_health := 1.0
var parking := false   ## latched handbrake
var lights_mode := 0   ## 0 off, 1 dipped, 2 high beam
var hazards := false
var body_health := 1.0
var wheel_health := PackedFloat32Array()

var _dt: Dictionary
var _tyres := "allroad"
var _steer := 0.0
var _shift_t := 0.0
var _flip_t := 0.0
var _safe_t := 0.0
var _last_safe := Transform3D.IDENTITY
var _stuck_t := 0.0
var _reverse_t := 0.0
var _dust: CPUParticles3D
var _exhaust: CPUParticles3D
var _splash: CPUParticles3D
var _base_slip := 4.0
var _base_rest := 0.3
var _sinks := PackedFloat32Array()
var _last_vy := 0.0
var _dirt_t := 0.0
var _rope: MeshInstance3D
var _prev_vel := Vector3.ZERO
var _was_contact: Array = []
var _redline_t := 0.0
var _smoke: CPUParticles3D
var _mud_spray: CPUParticles3D
var _frames := 0
var _dmg_t := 0.0


func setup_wheels() -> void:
	_dt = spec["drivetrain"]
	engine_rpm = _dt["idle"]
	_base_mass = spec["mass"]
	_base_com = spec["com"]
	_drive_radius = CarBuilder.axle_radius(spec, (spec["axles"] as Array).size() - 1)
	_tyres = str(garage.get("tyres", spec.get("tyres", "allroad")))
	fuel = float(spec["fuel"])
	awd_on = spec["awd"] != "switchable"
	for c in get_children():
		if c is VehicleWheel3D:
			var w := c as VehicleWheel3D
			wheels.append(w)
			if not w.use_as_steering:
				rear.append(w)
		elif c is SpotLight3D:
			lights.append(c as SpotLight3D)
	_sinks.resize(wheels.size())
	_sinks.fill(0.0)
	wheel_health.resize(wheels.size())
	wheel_health.fill(1.0)
	for i in wheels.size():
		_was_contact.append(true)
	_last_safe = global_transform
	var w: Dictionary = spec["wheel"]
	_base_slip = w["slip"]
	_base_rest = w["rest"]
	_apply_traction()
	_make_dust()
	_make_exhaust()
	_make_splash()
	_mud_spray = _puffs(60, 0.9, Color(0.24, 0.17, 0.11, 1.0), 0.22)
	_mud_spray.position = Vector3(0, -0.2, float(((spec["axles"] as Array)[-1] as Dictionary)["z"]) - 0.2)
	_mud_spray.emission_box_extents = Vector3(float((spec["wheel"] as Dictionary)["x"]), 0.1, 0.3)
	_mud_spray.direction = Vector3(0, 0.9, -1)
	_mud_spray.spread = 30.0
	_mud_spray.gravity = Vector3(0, -9.8, 0)
	_mud_spray.initial_velocity_min = 2.0
	_mud_spray.scale_amount_curve = null
	_mud_spray.scale_amount_min = 0.5
	_mud_spray.scale_amount_max = 1.3
	_smoke = _puffs(16, 1.6, Color(0.25, 0.25, 0.27, 0.5), 0.6)
	_smoke.position = Vector3(0, float((spec["collision"][0][1] as Vector3).y) + 0.6, float(spec["axles"][0]["z"]))
	_smoke.direction = Vector3(0, 1, 0)
	_smoke.gravity = Vector3(0, 1.2, 0)
	_rope = MeshInstance3D.new()
	_rope.mesh = LowPoly.cyl(0.025, 0.025, 1.0, 6)
	_rope.material_override = LowPoly.mat(Color("#d8cfb8"), 0.8)
	_rope.top_level = true
	_rope.visible = false
	add_child(_rope)


func gear_count() -> int:
	return (_dt["gears"] as Array).size()


func has_low() -> bool:
	return float(_dt["low"]) > 0.0


func is_auto() -> bool:
	return autopilot or bool(GameState.settings.get("auto_gearbox", false))


func tyre_name() -> String:
	return CarSpecs.TYRE_NAMES.get(_tyres, _tyres)


func fuel_ratio() -> float:
	return clampf(fuel / float(spec["fuel"]), 0.0, 1.0)


func gear_text() -> String:
	if not engine_on:
		return "OFF"
	if gear < 0:
		return "R"
	if gear == 0:
		return "N"
	return str(gear)


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


func manual_clutch() -> bool:
	return not autopilot and not is_auto() and bool(GameState.settings.get("manual_clutch", false))


func _shift(to: int) -> void:
	to = clampi(to, -1, gear_count())
	if to == gear:
		return
	if to < 0 and fwd_speed > 1.5:
		message.emit("Stop before reverse")
		return
	if manual_clutch() and _clutch_pedal < 0.6:
		Sfx.play("grind", 0.8)
		message.emit("Press the clutch (Shift) to change gear")
		return
	gear = to
	_shift_t = 0.0 if manual_clutch() else SHIFT_TIME


func _toggle_low() -> void:
	if not has_low():
		message.emit("No low range on this vehicle")
		return
	if absf(fwd_speed) > 3.0:
		message.emit("Slow down to change range")
		return
	low_range = not low_range
	_shift_t = SHIFT_TIME * 2.0
	message.emit("Low range" if low_range else "Normal range")


func toggle_awd() -> void:
	if spec["awd"] != "switchable":
		message.emit("AWD is permanent" if spec["awd"] == "full" else "No AWD on this vehicle")
		return
	awd_on = not awd_on
	_apply_traction()
	message.emit("AWD on" if awd_on else "AWD off (saves fuel)")


func toggle_diff() -> void:
	if not spec.get("diff_lock", false):
		message.emit("No diff lock on this vehicle")
		return
	diff_locked = not diff_locked
	message.emit("Diff lock on: more traction, harder steering" if diff_locked else "Diff lock off")


func _apply_traction() -> void:
	var axles: Array = spec["axles"]
	for w in wheels:
		var a: Dictionary = axles[int(w.get_meta("axle"))]
		var driven := bool(a["drive"])
		if spec["awd"] == "switchable" and bool(a["steer"]):
			driven = driven and awd_on
		w.use_as_traction = driven


func ignition() -> void:
	if engine_on:
		return
	if fuel <= 0.0:
		message.emit("No fuel. Press R to call a tow to the garage")
		return
	if _intake_depth() > 0.0:
		message.emit("Get the air intake out of the water first")
		return
	engine_on = true
	engine_rpm = float(_dt["idle"])
	message.emit("Engine started")


func _intake_depth() -> float:
	var local: Vector3 = spec["intake"]
	if garage.get("snorkel", false) and spec.has("snorkel_intake"):
		local = spec["snorkel_intake"]
	return -(global_transform * local).y


func refuel(litres: float) -> bool:
	var cap: float = spec["fuel"]
	if fuel >= cap - 0.01:
		return false
	fuel = minf(cap, fuel + litres)
	return true


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
			elif spec.get("diff_lock", false) and not diff_locked:
				diff_locked = true
			elif spec.get("winch", false) and winch_anchor == Vector3.INF:
				_winch_toggle()
			else:
				_reverse_t = 1.5
			_stuck_t = 0.0
		if winch_anchor != Vector3.INF:
			winch_len = maxf(1.5, winch_len - delta * 1.6)
			if speed > 2.5:
				_winch_toggle()
		if _reverse_t > 0.0:
			_reverse_t -= delta
			gas = 0.0
			brk = 1.0
			steer_in = -steer_in
	elif not GameState.ui_open:
		gas = Input.get_action_strength("gas")
		brk = Input.get_action_strength("brake")
		steer_in = Input.get_action_strength("left") - Input.get_action_strength("right")
		_clutch_pedal = Input.get_action_strength("clutch")
		if Input.is_action_just_pressed("handbrake"):
			parking = not parking
		if Input.is_action_just_pressed("lights"):
			lights_mode = (lights_mode + 1) % 3
			message.emit(["Lights off", "Headlights on", "High beams on"][lights_mode])
		if Input.is_action_just_pressed("hazards"):
			hazards = not hazards
		if parking and gas > 0.3 and fwd_speed < 0.5 and engine_on:
			parking = false
			message.emit("Handbrake released")
		hb = parking
		if Input.is_action_just_pressed("reset"):
			if fuel <= 0.0 or (not engine_on and _intake_depth() > 0.0):
				tow_home()
			else:
				reset_car(false)
			return
		if Input.is_action_just_pressed("low_range"):
			_toggle_low()
		if Input.is_action_just_pressed("awd"):
			toggle_awd()
		if Input.is_action_just_pressed("diff"):
			toggle_diff()
		if Input.is_action_just_pressed("ignition"):
			ignition()
		if Input.is_action_just_pressed("winch"):
			_winch_toggle()
		if winch_anchor != Vector3.INF and Input.is_action_pressed("winch_in"):
			winch_len = maxf(1.5, winch_len - delta * 1.6)
		if not is_auto():
			if Input.is_action_just_pressed("shift_up"):
				_shift(gear + 1)
			if Input.is_action_just_pressed("shift_down"):
				_shift(gear - 1)

	var red: float = _dt["redline"]
	var idle: float = _dt["idle"]
	var radius := _drive_radius
	var brake_max: float = spec["brake"]

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
	if not engine_on:
		gas = 0.0

	var ratio := _ratio()
	_shift_t = maxf(0.0, _shift_t - delta)
	# Clutch output speed in engine rpm (what the engine would turn at if the clutch were locked).
	var shaft := fwd_speed / (TAU * radius) * 60.0 * ratio
	var peak: float = _dt["torque"]
	var inertia: float = _dt.get("inertia", maxf(0.12, peak / 600.0))
	# Clutch engagement: the player's foot, or an automatic clutch that launches and shifts.
	var target_c := 0.0
	if manual_clutch():
		target_c = 1.0 - _clutch_pedal
	elif ratio != 0.0 and _shift_t <= 0.0 and engine_on:
		var launch: float = idle + 0.45 * (float(_dt["peak_rpm"]) - idle)
		target_c = clampf((engine_rpm - idle * 1.05) / maxf(launch - idle * 1.05, 1.0), 0.0, 1.0)
		if absf(shaft) > idle * 1.15:
			target_c = 1.0
		# Lugging: slip the clutch rather than drag the engine below idle.
		if engine_rpm < idle * 0.95 and absf(shaft) < idle:
			target_c = minf(target_c, 0.6)
	clutch = move_toward(clutch, target_c, delta * (12.0 if target_c < clutch else 5.0))
	if ratio == 0.0:
		clutch = 0.0
	# Engine torque: throttle, idle governor, rev limiter, internal friction (engine braking).
	var thr := gas
	if engine_on and engine_rpm < idle:
		thr = maxf(thr, clampf((idle - engine_rpm) / 250.0, 0.0, 0.4))
	if engine_rpm > red:
		thr = 0.0
	var t_comb := _torque(engine_rpm) * thr * lerpf(0.45, 1.0, engine_health) if engine_on else 0.0
	var t_fric := (0.05 + 0.1 * clampf(engine_rpm / red, 0.0, 1.2)) * peak * signf(engine_rpm)
	var t_cap := clutch * peak * 1.7
	var t_wheel := 0.0
	var slip_rpm := engine_rpm - shaft
	var lock_ok := manual_clutch() or engine_rpm > idle * 0.9 or not engine_on
	if lock_ok and clutch > 0.97 and absf(slip_rpm) < 150.0 and absf(t_comb - t_fric) < t_cap:
		# Locked: the engine turns with the wheels and its torque goes straight through.
		engine_rpm = shaft
		t_wheel = t_comb - t_fric
	else:
		var t_c := clampf(slip_rpm * peak * 0.02, -t_cap, t_cap)
		t_wheel = t_c
		engine_rpm += (t_comb - t_fric - t_c) / inertia * delta * 60.0 / TAU
	if not engine_on and clutch < 0.5:
		engine_rpm = move_toward(engine_rpm, 0.0, delta * 2500.0)
	if engine_on and not manual_clutch():
		engine_rpm = maxf(engine_rpm, idle * 0.85)
	engine_rpm = clampf(engine_rpm, -idle, red * 1.06)
	if engine_on and manual_clutch() and engine_rpm < idle * 0.45 and clutch > 0.5:
		engine_on = false
		message.emit("Stalled! Press the clutch, then I to restart" if manual_clutch() else "Stalled! Press I to restart")
	rpm = maxf(engine_rpm, 0.0) / red
	var linked := absf(shaft)

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
	if ratio != 0.0:
		force = t_wheel * ratio * EFFICIENCY / radius
	brake_v += brake_max * 0.015

	# Per-wheel: grip from tyre and ground, mud sinking, open differentials.
	var grip_table: Array = CarSpecs.TYRE_GRIP.get(_tyres, CarSpecs.TYRE_GRIP["allroad"])
	var driven := 0
	for w in wheels:
		if w.use_as_traction:
			driven += 1
	var per := force / maxf(driven, 1.0)
	var max_sink := radius * 0.6
	var deep := 0.0
	if trailer:
		trailer.brake_all(brake_v * 0.4 + (brake_max * 0.6 if hb else 0.0))
	var sink_sum := 0.0
	var mud_sum := 0.0
	for i in wheels.size():
		var w := wheels[i]
		var wp := w.global_position
		var sf := terrain.surface_at(wp.x, wp.z) if terrain else 0
		var wh := wheel_health[i]
		w.wheel_friction_slip = _base_slip * float(grip_table[sf]) * lerpf(0.55, 1.0, wh)
		w.suspension_stiffness = float((spec["wheel"] as Dictionary)["stiffness"]) * lerpf(0.55, 1.0, wh)
		var mud := terrain.mud_at(wp.x, wp.z) if terrain else 0.0
		var rut := tracks.rut_at(wp.x, wp.z) if tracks else 0.0
		var slip := 1.0 - w.get_skidinfo() if w.is_in_contact() else 0.0
		# Deep mud swallows more of the wheel; spinning digs it in further.
		var wheel_sink := w.wheel_radius * (0.55 + 0.35 * mud)
		var target := clampf(mud * 0.85 + rut * 0.35 * mud, 0.0, 1.0) * wheel_sink * float(CarSpecs.TYRE_SINK.get(_tyres, 1.0)) * (0.45 + slip * 0.9)
		deep = maxf(deep, mud)
		var rate := 0.18 if target > _sinks[i] else (0.25 if mud > 0.05 else 1.2)
		_sinks[i] = move_toward(_sinks[i], target, rate * delta)
		w.wheel_rest_length = maxf(0.05, _base_rest - _sinks[i])
		# The tyre itself sits down into the mud.
		var vis := w.get_child(0) as Node3D
		if vis:
			vis.position.y = -_sinks[i] * 0.9
		sink_sum += _sinks[i] / max_sink
		mud_sum += mud
		w.engine_force = per if w.use_as_traction else 0.0
		w.brake = brake_v
		if tracks and w.is_in_contact():
			tracks.add_point(i + get_instance_id() * 16, wp - Vector3.UP * w.wheel_radius * 0.97, float((spec["wheel"] as Dictionary)["width"]), sf, mud)
	if not diff_locked:
		# Open diff: an axle only pushes as hard as its weakest wheel allows.
		var axles: Array = spec["axles"]
		for a in axles.size():
			var l := wheels[a * 2]
			var r := wheels[a * 2 + 1]
			if not l.use_as_traction:
				continue
			var cl := l.get_skidinfo() if l.is_in_contact() else 0.0
			var cr := r.get_skidinfo() if r.is_in_contact() else 0.0
			var f := clampf(2.0 * minf(cl, cr) / (cl + cr + 0.001), 0.25, 1.0)
			l.engine_force *= f
			r.engine_force *= f
	sink = sink_sum / maxf(wheels.size(), 1)
	if hb:
		for w in rear:
			w.brake = brake_max * 1.6
			w.engine_force = 0.0
	# Mud suction and air drag.
	var mud_avg := mud_sum / maxf(wheels.size(), 1)
	if mud_avg > 0.02 and speed > 0.05:
		var hv := Vector3(linear_velocity.x, 0, linear_velocity.z)
		# Small wheels sink in and plough; big wheels float over.
		var small := sqrt(0.6 / radius)
		apply_central_force(-hv.normalized() * minf(hv.length(), 2.0) / 2.0 * mass * 9.8 * mud_avg * (0.05 + sink * 0.6) * small)
	var cda: float = _dt["cda"]
	apply_central_force(-linear_velocity * speed * cda * 0.6)
	_static_grip(delta, gas, brk, hb, grip_table)

	var top: float = spec["top_speed"]
	var steer_max: float = spec["steer_max"] * (0.7 if diff_locked else 1.0)
	var steer_lim := lerpf(steer_max, steer_max * 0.35, clampf(absf(fwd_speed) / top, 0.0, 1.0))
	# A bent front wheel pulls to one side.
	var pull := (wheel_health[0] - wheel_health[1]) * 0.12
	_steer = move_toward(_steer, steer_in * steer_lim + pull * clampf(absf(fwd_speed) / 5.0, 0.0, 1.0), delta * 2.2)
	steering = _steer

	var contacts := 0
	for w in wheels:
		if w.is_in_contact():
			contacts += 1
	grounded = contacts > 0
	if contacts == 0:
		apply_torque((b.x * (brk - gas) * 1.6 - b.z * steer_in * 1.2) * mass)
	throttle = gas

	var grip := 1.0
	for w in wheels:
		if w.is_in_contact():
			grip = minf(grip, w.get_skidinfo())
	skid = lerpf(skid, (1.0 - grip) if grounded else 0.0, 1.0 - exp(-delta * 10.0))
	jolt = lerpf(jolt, absf(linear_velocity.y - _last_vy) / maxf(delta, 0.001) * 0.02, 0.3)
	_last_vy = linear_velocity.y

	_physics_fuel_water_dirt(delta, speed, mud_avg)
	_physics_damage(delta)
	_physics_winch(delta)
	braking = brk > 0.1
	_update_lamps()

	var new_surface := terrain.surface_at(global_position.x, global_position.z) if terrain else 0
	if mud_avg > 0.35:
		new_surface = Terrain.Surface.MUD
	if new_surface != surface:
		surface = new_surface
		var ramp := _dust.color_ramp
		var dc: Color = DUST[surface]
		ramp.set_color(0, Color(dc, 0.45))
		ramp.set_color(1, Color(dc, 0.0))
	var in_water := global_position.y < 0.5
	_dust.emitting = contacts >= 2 and not in_water and (speed > 4.0 or skid > 0.3) and surface != Terrain.Surface.WATER
	_dust.initial_velocity_max = 1.0 + speed * 0.15
	_exhaust.emitting = engine_on and gas > 0.25 and engine_rpm > idle * 1.2
	_splash.emitting = in_water and speed > 1.5
	_mud_spray.emitting = mud_avg > 0.2 and grounded and (skid > 0.15 or (gas > 0.3 and speed > 1.0))
	_mud_spray.initial_velocity_max = 3.0 + skid * 6.0
	if in_water:
		apply_central_force(-linear_velocity * mass * 0.5)

	var up_y := b.y.y
	if up_y < 0.3 and speed < 3.0:
		_flip_t += delta
	else:
		_flip_t = 0.0
	if _flip_t > 0.6 and not load.is_empty():
		spilled.emit(global_position, load.duplicate())
		set_load([])
		message.emit("You lost your cargo! A crane truck can pick it up")
	if _flip_t > 2.0:
		reset_car(false)
		return
	if global_position.y < -2.5:
		reset_car(true)
		return
	if contacts == wheels.size() and up_y > 0.85 and global_position.y > 0.6 and mud_avg < 0.3:
		_safe_t += delta
		if _safe_t > 1.0:
			_safe_t = 0.0
			_last_safe = global_transform
	if grounded:
		trip += Vector2(linear_velocity.x, linear_velocity.z).length() * delta


## Godot's raycast tyres hardly resist creeping sideways when slow, so vehicles slid down
## sideslopes. Real tyres hold until gravity beats their grip: add that static friction here.
func _static_grip(delta: float, gas: float, brk: float, hb: bool, grip_table: Array) -> void:
	var touching := 0
	for w in wheels:
		if w.is_in_contact():
			touching += 1
	if touching < wheels.size() / 2 + 1:
		return
	var b := global_transform.basis
	var g := get_gravity()
	var mu := 0.85 * float(grip_table[surface]) * lerpf(1.0, 0.5, clampf(sink * 1.5, 0.0, 1.0))
	var normal := mass * g.length() * maxf(b.y.dot(Vector3.UP), 0.0)
	var limit := mu * normal
	# Sideways: cancel gravity's pull across the slope and damp the slide.
	var side := b.x
	var lat_v := linear_velocity.dot(side)
	var want := -g.dot(side) * mass - lat_v * mass / maxf(delta * 6.0, 0.02)
	if absf(lat_v) < 2.5:
		apply_central_force(side * clampf(want, -limit, limit))
	# Along the slope: hold still when parked or stopped with no pedals pressed.
	var fwd := b.z
	var lon_v := linear_velocity.dot(fwd)
	var holding := hb or (gas < 0.05 and absf(lon_v) < 0.6)
	if holding and absf(lon_v) < 2.0:
		var want_l := -g.dot(fwd) * mass - lon_v * mass / maxf(delta * 6.0, 0.02)
		apply_central_force(fwd * clampf(want_l, -limit, limit))


func _physics_fuel_water_dirt(delta: float, speed: float, mud_avg: float) -> void:
	if engine_on:
		var burn: float = spec["burn"]
		var mult := (1.2 if awd_on and spec["awd"] == "switchable" else 1.0) * (1.1 if diff_locked else 1.0)
		fuel = maxf(0.0, fuel - (burn * 0.08 + burn * throttle * (0.3 + rpm * 0.7)) * mult * delta)
		if fuel <= 0.0:
			engine_on = false
			message.emit("Out of fuel! Press R to call a tow to the garage")
		elif _intake_depth() > 0.0:
			engine_on = false
			engine_health = maxf(0.0, engine_health - 0.15)
			message.emit("Engine flooded! Fit a snorkel for deep water. Press I to restart")
	if mud_avg > 0.1 or (global_position.y < 0.5 and speed > 1.0):
		dirt = minf(1.0, dirt + delta * 0.02 * (1.0 + speed * 0.1))
	_dirt_t += delta
	if _dirt_t > 0.5:
		_dirt_t = 0.0
		for m in paint_mats:
			(m as ShaderMaterial).set_shader_parameter("dirt", dirt)


func _physics_damage(delta: float) -> void:
	_frames += 1
	var dv := linear_velocity - _prev_vel
	_prev_vel = linear_velocity
	if _frames < 30:
		return
	# Crashes: a sudden change of speed.
	if dv.length() > 8.0:
		var hit := (dv.length() - 8.0) / 12.0
		body_health = maxf(0.0, body_health - hit * 0.45)
		var frontal := absf(dv.normalized().dot(global_transform.basis.z))
		engine_health = maxf(0.0, engine_health - hit * 0.25 * frontal)
		message.emit("Crash! Body %d%%, engine %d%%" % [int(body_health * 100), int(engine_health * 100)])
	# Hard landings bend the suspension that takes the hit.
	for i in wheels.size():
		var contact := wheels[i].is_in_contact()
		if contact and not _was_contact[i] and _prev_vel.y < -6.5:
			var dmg := (absf(_prev_vel.y) - 6.5) * 0.09
			wheel_health[i] = maxf(0.0, wheel_health[i] - dmg)
			if dmg > 0.05:
				message.emit("Hard landing: %s suspension %d%%" % [_wheel_name(i), int(wheel_health[i] * 100)])
		_was_contact[i] = contact
	# Holding the redline overheats the engine.
	if engine_on and rpm > 0.96:
		_redline_t += delta
		if _redline_t > 4.0:
			engine_health = maxf(0.0, engine_health - 0.03 * delta)
			if int(_redline_t * 2.0) % 10 == 0:
				message.emit("Engine overheating: shift up!")
	else:
		_redline_t = 0.0
	# A badly hurt engine smokes and sometimes cuts out.
	_smoke.emitting = engine_on and engine_health < 0.5
	if engine_on and engine_health < 0.25 and randf() < 0.03 * delta:
		engine_on = false
		message.emit("The engine stalled. Press I to restart, and get it repaired")
	_dmg_t += delta
	if _dmg_t > 0.5:
		_dmg_t = 0.0
		for m in paint_mats:
			(m as ShaderMaterial).set_shader_parameter("damage", 1.0 - body_health)


func _wheel_name(i: int) -> String:
	var axles := (spec["axles"] as Array).size()
	var a := i / 2
	var pos := "front" if a == 0 else ("rear" if a == axles - 1 else "middle")
	return "%s %s" % [pos, "left" if i % 2 == 0 else "right"]


func worst_wheel() -> float:
	var m := 1.0
	for h in wheel_health:
		m = minf(m, h)
	return m


## Repairs a bit of everything; returns false when there is nothing left to fix.
func repair(amount: float) -> bool:
	var any := engine_health < 1.0 or body_health < 1.0 or worst_wheel() < 1.0
	engine_health = minf(1.0, engine_health + amount)
	body_health = minf(1.0, body_health + amount)
	for i in wheel_health.size():
		wheel_health[i] = minf(1.0, wheel_health[i] + amount)
	return any


func _winch_toggle() -> void:
	if not spec.get("winch", false):
		message.emit("No winch on this vehicle")
		return
	if winch_anchor != Vector3.INF:
		winch_anchor = Vector3.INF
		_rope.visible = false
		message.emit("Winch released")
		return
	if not engine_on:
		message.emit("Start the engine to use the winch")
		return
	var wp: Vector3 = global_transform * (spec["winch_point"] as Vector3)
	var best := Vector3.INF
	var best_d := WINCH_RANGE
	var pts: Array = anchors.call() if anchors.is_valid() else []
	for p in pts:
		var v: Vector3 = p
		var d := v.distance_to(wp)
		if d < best_d and (v - wp).normalized().dot(global_transform.basis.z) > -0.3:
			best_d = d
			best = v
	if best == Vector3.INF:
		message.emit("Nothing to hook the winch onto within %d m" % int(WINCH_RANGE))
		return
	winch_anchor = best
	winch_len = best_d
	message.emit("Winch attached. Hold H to reel in, G to release")


func _physics_winch(_delta: float) -> void:
	if winch_anchor == Vector3.INF:
		return
	var wp: Vector3 = global_transform * (spec["winch_point"] as Vector3)
	var d := winch_anchor - wp
	var dist := d.length()
	if dist > winch_len:
		var stretch := dist - winch_len
		if stretch > 6.0:
			winch_anchor = Vector3.INF
			_rope.visible = false
			message.emit("The winch line slipped off")
			return
		var f := minf(stretch * float(spec["winch_force"]) * 1.5, float(spec["winch_force"]))
		apply_force(d / dist * f, wp - global_position)
	_rope.visible = true
	_rope.global_transform = Transform3D(Basis.IDENTITY, (wp + winch_anchor) * 0.5)
	_rope.look_at(winch_anchor, Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.RIGHT)
	_rope.rotate_object_local(Vector3.RIGHT, PI / 2.0)
	_rope.scale = Vector3(1, dist, 1)


func reset_car(to_safe: bool) -> void:
	var src := _last_safe if to_safe else global_transform
	var f := src.basis.z
	f.y = 0.0
	if f.length() < 0.1:
		f = Vector3(0, 0, 1)
	f = f.normalized()
	var p := src.origin
	var h := terrain.get_height(p.x, p.z) if terrain else p.y
	p.y = maxf(h, 0.0) + 1.0 + float((spec["wheel"] as Dictionary)["y"])
	_teleport(Transform3D(Basis.looking_at(-f, Vector3.UP), p))


## Out of fuel or flooded: back to the start with a quarter tank.
func tow_home() -> void:
	if not terrain:
		return
	var t := terrain.spawn_transform
	t.origin.y += float((spec["wheel"] as Dictionary)["y"])
	_teleport(t)
	fuel = maxf(fuel, float(spec["fuel"]) * 0.25)
	engine_on = true
	message.emit("Towed back to the garage")


## The bed that takes cargo: the trailer if there is one, else this vehicle.
func carrier() -> Object:
	if trailer:
		return trailer
	return self if int(Cargo.bed(spec).get("slots", 0)) > 0 else null


func carrier_spec() -> Dictionary:
	return trailer.spec if trailer else spec


func carrier_load() -> Array:
	return trailer.load if trailer else load


func set_carrier_load(l: Array) -> void:
	if trailer:
		trailer.set_load(l)
	else:
		set_load(l)


func set_load(l: Array) -> void:
	load = l
	if cargo_holder:
		Cargo.show(cargo_holder, spec, load)
	var extra := Cargo.load_mass(load)
	mass = _base_mass + extra
	var bed_y: float = (Cargo.bed(spec).get("start", Vector3.ZERO) as Vector3).y
	center_of_mass = _base_com + Vector3(0, (bed_y + 0.5 - _base_com.y) * extra / mass, 0)


func _teleport(t: Transform3D) -> void:
	var rid := get_rid()
	if trailer:
		var off := (spec["hitch"] as Vector3) - ((trailer.spec["hitch"]) as Vector3)
		var tt := Transform3D(t.basis, t * off)
		var trid := trailer.get_rid()
		PhysicsServer3D.body_set_state(trid, PhysicsServer3D.BODY_STATE_TRANSFORM, tt)
		PhysicsServer3D.body_set_state(trid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
		PhysicsServer3D.body_set_state(trid, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, t)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)
	_flip_t = 0.0
	_steer = 0.0
	_sinks.fill(0.0)
	winch_anchor = Vector3.INF
	_rope.visible = false
	if not is_auto():
		gear = 1
	resets += 1
	was_reset.emit()


var _darkness := 0.0
var _lamp_state := ""


func set_night(darkness: float) -> void:
	_darkness = darkness
	for l in lights:
		l.visible = lights_mode > 0
		l.light_energy = (1.0 + darkness * 3.0) * (1.6 if lights_mode == 2 else 1.0)
		l.spot_range = 70.0 if lights_mode == 2 else 38.0
		l.spot_angle = 26.0 if lights_mode == 2 else 40.0


func _update_lamps() -> void:
	var blink := hazards and fmod(Time.get_ticks_msec() / 1000.0, 0.8) < 0.4
	var state := "%d%s%s%s" % [lights_mode, braking, gear < 0 and engine_on, blink]
	if state == _lamp_state:
		return
	_lamp_state = state
	for m in lamp_mats["light"]:
		(m as StandardMaterial3D).emission_energy_multiplier = [0.15, 2.2, 3.5][lights_mode]
	for m in lamp_mats["tail"]:
		(m as StandardMaterial3D).emission_energy_multiplier = 1.6 if braking else (0.6 if lights_mode > 0 else 0.1)
	for m in lamp_mats["reverse"]:
		(m as StandardMaterial3D).emission_energy_multiplier = 2.5 if gear < 0 and engine_on else 0.1
	for m in lamp_mats["amber"]:
		(m as StandardMaterial3D).emission_energy_multiplier = 1.8 if blink else 0.1


func _make_exhaust() -> void:
	_exhaust = _puffs(10, 0.9, Color(0.55, 0.55, 0.6, 0.35), 0.3)
	_exhaust.position = spec.get("exhaust", Vector3(0, 0.1, -1.8))
	_exhaust.direction = Vector3(0, 0.3, -1) if (_exhaust.position as Vector3).y < 1.5 else Vector3(0, 1, 0)
	_exhaust.initial_velocity_min = 0.6
	_exhaust.initial_velocity_max = 1.2


func _make_splash() -> void:
	_splash = _puffs(40, 0.7, Color(0.9, 0.97, 1.0, 0.7), 0.35)
	_splash.position = Vector3(0, -0.2, 0)
	_splash.emission_box_extents = Vector3(0.9, 0.05, 1.6)
	_splash.direction = Vector3(0, 1, 0)
	_splash.spread = 50.0
	_splash.gravity = Vector3(0, -9.8, 0)
	_splash.initial_velocity_min = 2.0
	_splash.initial_velocity_max = 4.0


func _make_dust() -> void:
	var rear_z: float = ((spec["axles"] as Array)[-1] as Dictionary)["z"]
	_dust = _puffs(28, 1.4, Color(0.93, 0.88, 0.8, 0.45), 0.7)
	_dust.position = Vector3(0, -0.1, rear_z - 0.4)
	_dust.emission_box_extents = Vector3(float((spec["wheel"] as Dictionary)["x"]), 0.05, 0.2)
	_dust.direction = Vector3(0, 0.6, -1)
	_dust.spread = 35.0
	_dust.gravity = Vector3(0, 0.4, 0)
	_dust.initial_velocity_min = 0.5
	_dust.initial_velocity_max = 2.0
	_dust.damping_min = 1.5
	_dust.damping_max = 2.5
	_dust.scale_amount_min = 0.6
	_dust.scale_amount_max = 1.6


func _puffs(amount: int, life: float, color: Color, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.emitting = false
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.05, 0.05, 0.05)
	p.spread = 20.0
	p.gravity = Vector3(0, 0.6, 0)
	p.damping_min = 1.0
	p.damping_max = 2.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.5))
	curve.add_point(Vector2(1, 1.8))
	p.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color, 0.0))
	p.color_ramp = ramp
	p.mesh = _soft_quad(size)
	add_child(p)
	return p


static func _soft_quad(size: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
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
	return q


func net_state() -> Array:
	return [global_position, global_basis.get_rotation_quaternion(), linear_velocity, _steer, rpm, throttle, gear, braking]
