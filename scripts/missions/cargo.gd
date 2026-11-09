class_name Cargo
extends RefCounted
## Cargo types, their looks, and a "carrier": the bed slots of a truck or trailer.
## Slots are 1.25 m long, laid from bed_start towards the back of the vehicle.

const SLOT := 1.25
const TYPES := {
	"pallet": {"name": "Pallets", "slots": 1, "mass": 500.0, "icon": "inventory_2"},
	"parts": {"name": "Spare parts", "slots": 1, "mass": 350.0, "icon": "handyman"},
	"planks": {"name": "Planks", "slots": 2, "mass": 900.0, "icon": "carpenter"},
	"pipes": {"name": "Pipes", "slots": 2, "mass": 1300.0, "icon": "construction"},
	"logs": {"name": "Logs", "slots": 3, "mass": 2600.0, "icon": "forest"},
}

static var _mats: Dictionary = {}


static func type_name(t: String) -> String:
	return str((TYPES[t] as Dictionary)["name"]) if TYPES.has(t) else t


static func _mat(key: String, c: Color, rough := 0.8) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	_mats[key] = m
	return m


static func _mi(mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	return mi


## A model of one load, centred on the origin, sitting on y = 0, long side along Z.
static func model(t: String) -> Node3D:
	var root := Node3D.new()
	match t:
		"pallet":
			root.add_child(_mi(MeshKit.rbox(Vector3(1.1, 0.14, 1.1), 0.02), _mat("wood", Color("#b08a63")), Vector3(0, 0.07, 0)))
			root.add_child(_mi(MeshKit.rbox(Vector3(1.0, 0.8, 1.0), 0.06), _mat("box", Color("#d9c3a0"), 0.9), Vector3(0, 0.55, 0)))
			root.add_child(_mi(LowPoly.box(Vector3(1.02, 0.08, 1.02)), _mat("strap", Color("#e8707f")), Vector3(0, 0.55, 0)))
		"parts":
			root.add_child(_mi(MeshKit.rbox(Vector3(0.95, 0.75, 0.95), 0.06), _mat("crate", Color("#8f9a6a")), Vector3(0, 0.38, 0)))
			var l := Label3D.new()
			l.text = "PARTS"
			l.font_size = 64
			l.pixel_size = 0.004
			l.outline_size = 0
			l.modulate = Color("#f4efe6")
			l.position = Vector3(0, 0.42, 0.48)
			root.add_child(l)
		"planks":
			for i in 3:
				for k in 3:
					root.add_child(_mi(MeshKit.rbox(Vector3(0.28, 0.1, 2.4), 0.02), _mat("plank", Color("#d4b483")),
						Vector3(-0.3 + i * 0.3, 0.06 + k * 0.11, 0)))
		"pipes":
			var pm := LowPoly.cyl(0.13, 0.13, 2.4, 14)
			for i in 3:
				root.add_child(_mi(pm, _mat("pipe", Color("#9aa3ad"), 0.35), Vector3(-0.3 + i * 0.3, 0.14, 0), Vector3(90, 0, 0)))
			for i in 2:
				root.add_child(_mi(pm, _mat("pipe", Color("#9aa3ad"), 0.35), Vector3(-0.15 + i * 0.3, 0.39, 0), Vector3(90, 0, 0)))
		"logs":
			var lm := LowPoly.cyl(0.26, 0.28, 3.6, 12)
			for i in 3:
				root.add_child(_mi(lm, Props.bark_mat(), Vector3(-0.56 + i * 0.56, 0.28, 0), Vector3(90, 0, 0)))
			for i in 2:
				root.add_child(_mi(lm, Props.bark_mat(), Vector3(-0.28 + i * 0.56, 0.74, 0), Vector3(90, 0, 0)))
	return root


## Bed geometry for a vehicle or trailer spec: {"slots": int, "start": Vector3, "logs_only": bool, "any": bool}
static func bed(spec: Dictionary) -> Dictionary:
	return spec.get("cargo", {"slots": 0, "start": Vector3.ZERO})


static func used_slots(load: Array) -> int:
	var n := 0
	for t in load:
		n += int((TYPES[t] as Dictionary)["slots"])
	return n


static func fits(spec: Dictionary, load: Array, t: String) -> bool:
	var b := bed(spec)
	if int(b.get("slots", 0)) == 0 or not TYPES.has(t):
		return false
	if b.get("logs_only", false) != (t == "logs"):
		return false
	return used_slots(load) + int((TYPES[t] as Dictionary)["slots"]) <= int(b["slots"])


static func load_mass(load: Array) -> float:
	var m := 0.0
	for t in load:
		m += float((TYPES[t] as Dictionary)["mass"])
	return m


## Rebuilds the visual stack of cargo under `holder`.
static func show(holder: Node3D, spec: Dictionary, load: Array) -> void:
	for c in holder.get_children():
		c.queue_free()
	var b := bed(spec)
	var start: Vector3 = b.get("start", Vector3.ZERO)
	var slot := 0
	for t in load:
		var n := int((TYPES[t] as Dictionary)["slots"])
		var m := model(t)
		m.position = start - Vector3(0, 0, (slot + n * 0.5) * SLOT)
		holder.add_child(m)
		slot += n
