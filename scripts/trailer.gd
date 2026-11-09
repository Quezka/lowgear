class_name Trailer
extends VehicleBody3D
## An unpowered trailer on a ball hitch. Carries cargo like a truck bed.

signal spilled(at: Vector3, load: Array)

var spec: Dictionary
var load: Array = []
var holder: Node3D
var base_mass := 1000.0
var _flip_t := 0.0


func set_load(l: Array) -> void:
	load = l
	Cargo.show(holder, spec, load)
	mass = base_mass + Cargo.load_mass(load)


func _physics_process(delta: float) -> void:
	if global_transform.basis.y.y < 0.3:
		_flip_t += delta
		if _flip_t > 0.6 and not load.is_empty():
			spilled.emit(global_position, load.duplicate())
			set_load([])
	else:
		_flip_t = 0.0


func brake_all(v: float) -> void:
	for c in get_children():
		if c is VehicleWheel3D:
			(c as VehicleWheel3D).brake = v
