class_name ChaseCamera
extends Camera3D
## Follows the car. C cycles: near chase, far chase, cinematic. Drag the mouse to look around.

const MODES := ["near", "far", "cinematic"]

var target: Car
var terrain: Terrain
var mode := 0

var _heading := Vector3(0, 0, 1)
var _yaw_off := 0.0
var _mouse_t := 0.0
var _cine_pos := Vector3.ZERO
var _shake := 0.0
var zoom := 1.0
var _touches: Dictionary = {}
var _pinch_d := 0.0


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var saved := float(GameState.settings.get("cam_zoom", -1.0))
	zoom = saved if saved > 0.0 else (0.68 if TouchControls.wanted() else 1.0)
	fov = 68.0
	near = 0.1
	far = 900.0


func snap() -> void:
	if not target:
		return
	var f := target.global_transform.basis.z
	f.y = 0.0
	_heading = f.normalized() if f.length() > 0.01 else Vector3(0, 0, 1)
	global_position = target.global_position - _heading * 7.0 + Vector3.UP * 2.6
	look_at(target.global_position + Vector3.UP, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_by(0.9)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_by(1.1)
	elif event is InputEventMagnifyGesture:
		_zoom_by(1.0 / (event as InputEventMagnifyGesture).factor)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		var vs := get_viewport().get_visible_rect().size
		if st.pressed and st.position.y < vs.y * 0.62 and st.position.x > vs.x * 0.22 and st.position.x < vs.x * 0.78:
			_touches[st.index] = st.position
		else:
			_touches.erase(st.index)
		_pinch_d = 0.0
	elif event is InputEventScreenDrag and _touches.has((event as InputEventScreenDrag).index):
		var sd := event as InputEventScreenDrag
		_touches[sd.index] = sd.position
		if _touches.size() >= 2:
			var pts := _touches.values()
			var d := (pts[0] as Vector2).distance_to(pts[1])
			if _pinch_d > 0.0:
				_zoom_by(_pinch_d / maxf(d, 1.0))
			_pinch_d = d
		else:
			_yaw_off -= sd.relative.x * 0.008
			_mouse_t = 2.0
	elif event.is_action_pressed("zoom_in"):
		_zoom_by(0.85)
	elif event.is_action_pressed("zoom_out"):
		_zoom_by(1.15)
	elif event.is_action_pressed("camera"):
		mode = (mode + 1) % MODES.size()
		_cine_pos = Vector3.ZERO
	elif event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask != 0:
		_yaw_off -= (event as InputEventMouseMotion).relative.x * 0.006
		_mouse_t = 2.0


func _zoom_by(f: float) -> void:
	zoom = clampf(zoom * f, 0.35, 2.2)
	GameState.settings["cam_zoom"] = zoom


func _process(delta: float) -> void:
	if not target or not target.is_inside_tree():
		return
	var ct := target.get_global_transform_interpolated()
	var car_pos := ct.origin
	var fwd := ct.basis.z
	fwd.y = 0.0
	var vel := target.linear_velocity
	vel.y = 0.0
	if vel.length() > 3.0 and target.fwd_speed > 0.0:
		fwd = fwd.normalized().lerp(vel.normalized(), 0.5)
	if fwd.length() < 0.01:
		fwd = _heading
	fwd = fwd.normalized()
	_heading = _heading.slerp(fwd, 1.0 - exp(-delta * 2.5)).normalized()
	if _mouse_t > 0.0:
		_mouse_t -= delta
	else:
		_yaw_off = lerp_angle(_yaw_off, 0.0, 1.0 - exp(-delta * 1.5))
	var h := _heading.rotated(Vector3.UP, _yaw_off)

	if mode == 2:
		if _cine_pos == Vector3.ZERO or _cine_pos.distance_to(car_pos) > 60.0:
			var side := h.cross(Vector3.UP).normalized() * (10.0 if randf() < 0.5 else -10.0)
			_cine_pos = car_pos + h * 38.0 + side
			_cine_pos.y = terrain.get_height(_cine_pos.x, _cine_pos.z) + 2.5
			_cine_pos.y = maxf(_cine_pos.y, 1.5)
		global_position = _cine_pos
		look_at(car_pos + Vector3.UP * 0.8, Vector3.UP)
		return

	var axles: Array = target.spec["axles"]
	var length := float(axles[0]["z"]) - float(axles[-1]["z"]) + 2.2
	if target.trailer:
		length += 4.5
	var size := maxf(1.0, length / 3.2)
	var dist := (7.0 if mode == 0 else 13.0) * size * zoom
	var height := (2.6 if mode == 0 else 5.0) * lerpf(1.0, size, 0.8) * lerpf(0.75, 1.0, clampf(zoom, 0.0, 1.0))
	var desired := car_pos - h * dist + Vector3.UP * height
	var ground := terrain.get_height(desired.x, desired.z) + 1.2
	desired.y = maxf(desired.y, maxf(ground, 0.6))
	global_position = global_position.lerp(desired, 1.0 - exp(-delta * 5.0))
	_shake = lerpf(_shake, clampf(target.jolt, 0.0, 1.0), 1.0 - exp(-delta * 8.0))
	if _shake > 0.02:
		global_position += Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * _shake * 0.12
	var look := car_pos + Vector3.UP * 1.0 + h * 2.0
	if global_position.distance_to(look) > 0.5:
		look_at(look, Vector3.UP)
	var speed_fov := 66.0 + clampf(target.linear_velocity.length() * 0.35, 0.0, 12.0)
	fov = lerpf(fov, speed_fov, 1.0 - exp(-delta * 2.0))
