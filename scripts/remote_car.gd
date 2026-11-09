class_name RemoteCar
extends AnimatableBody3D
## Another player's car: replays their streamed state ~120 ms behind, so it moves smoothly.
## It is solid (you can bump into it) but never picks up your coins.

const DELAY := 0.12
const LAYER := 4

var peer_id := 0
var spec: Dictionary
var _snaps: Array = []  ## [time, pos, quat, vel, steer, rpm, gear, braking]
var _front: Array[Node3D] = []
var _spinners: Array[Node3D] = []
var _label: Label3D
var _radius := 0.3
var _drop := 0.3


func setup(id: int, info: Dictionary, tint: Color) -> void:
	peer_id = id
	spec = CarSpecs.get_spec(str(info.get("car", "panda4x4")))
	name = "Remote%d" % id
	collision_layer = LAYER
	collision_mask = 0
	sync_to_physics = true
	var w: Dictionary = spec["wheel"]
	_radius = w["radius"]
	_drop = float(w["rest"]) + 0.06
	for c in spec["collision"]:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = c[0]
		cs.shape = box
		cs.position = c[1]
		add_child(cs)
	add_child(CarBuilder.build_visual(spec))
	var positions := CarBuilder.wheel_positions(spec)
	for i in positions.size():
		var pivot := Node3D.new()
		pivot.position = positions[i] - Vector3(0, _drop, 0)
		add_child(pivot)
		var wv := CarBuilder.build_wheel_visual(spec)
		pivot.add_child(wv)
		_spinners.append(wv)
		if i < 2:
			_front.append(pivot)
	_label = Label3D.new()
	_label.text = str(info.get("name", "Driver"))
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.fixed_size = true
	_label.pixel_size = 0.0012
	_label.font_size = 40
	_label.outline_size = 14
	_label.modulate = tint.lightened(0.35)
	_label.outline_modulate = Color("#2b2d42")
	_label.no_depth_test = true
	_label.position = Vector3(0, 2.4, 0)
	add_child(_label)


func set_player_name(n: String) -> void:
	_label.text = n


func push(data: Array) -> void:
	if data.size() < 8:
		return
	var snap: Array = [Time.get_ticks_msec() / 1000.0]
	snap.append_array(data)
	_snaps.append(snap)
	if _snaps.size() > 30:
		_snaps.pop_front()
	if _snaps.size() == 1:
		global_transform = Transform3D(Basis(data[1] as Quaternion), data[0] as Vector3)
		reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	if _snaps.is_empty():
		return
	var t := Time.get_ticks_msec() / 1000.0 - DELAY
	var a: Array = _snaps[0]
	var b: Array = _snaps[-1]
	var pos: Vector3
	var rot: Quaternion
	if t >= float(b[0]):
		# No newer data yet: coast along the last velocity for a moment.
		var ahead := minf(t - float(b[0]), 0.3)
		pos = (b[1] as Vector3) + (b[3] as Vector3) * ahead
		rot = b[2]
	else:
		for i in range(_snaps.size() - 1, -1, -1):
			if float(_snaps[i][0]) <= t:
				a = _snaps[i]
				b = _snaps[mini(i + 1, _snaps.size() - 1)]
				break
		var span := float(b[0]) - float(a[0])
		var f := 0.0 if span <= 0.0 else clampf((t - float(a[0])) / span, 0.0, 1.0)
		pos = (a[1] as Vector3).lerp(b[1] as Vector3, f)
		rot = (a[2] as Quaternion).slerp(b[2] as Quaternion, f)
	global_transform = Transform3D(Basis(rot.normalized()), pos)
	var steer: float = b[4]
	for p in _front:
		p.rotation.y = steer
	var speed := (b[3] as Vector3).dot(global_transform.basis.z)
	for s in _spinners:
		s.rotate_x(speed / _radius * delta)
