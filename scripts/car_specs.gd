class_name CarSpecs
extends RefCounted
## The cars. Each car faces +Z; parts are [shape, dims, position, colour key, rotation_degrees?].
## Shapes: "box" dims=size, "cyl" dims=(top_r, bottom_r, height), "label" dims=text.

const ORDER := ["panda4x4", "niva", "mini_rally"]


static func get_spec(id: String) -> Dictionary:
	var all := all_specs()
	if all.has(id):
		return all[id]
	return all["panda4x4"]


static func all_specs() -> Dictionary:
	return {"panda4x4": _panda(), "niva": _niva(), "mini_rally": _mini()}


static func _panda() -> Dictionary:
	return {
		"id": "panda4x4",
		"name": "Panda 4x4",
		"blurb": "Small, light and stubborn. Climbs steep grass like a goat, but it is never in a hurry.",
		"stats": {"Speed": 2, "Climbing": 5, "Grip": 4, "Comfort": 3},
		"mass": 800.0, "engine_force": 6200.0, "top_speed": 21.0, "drive": "awd",
		"brake": 32.0, "steer_max": 0.55,
		"drivetrain": {"gears": [3.91, 2.16, 1.48, 1.12, 0.89], "final": 4.46, "high": 1.0, "low": 1.6,
			"torque": 100.0, "peak_rpm": 3000.0, "idle": 850.0, "redline": 6000.0, "cda": 0.8},
		"wheel": {
			"radius": 0.32, "width": 0.2, "x": 0.68, "front_z": 1.08, "rear_z": -1.08, "y": 0.35,
			"rest": 0.26, "travel": 0.26, "stiffness": 38.0, "comp": 1.8, "relax": 2.6, "slip": 4.6, "roll": 0.5,
		},
		"com": Vector3(0, -0.15, 0.1),
		"collision": [
			[Vector3(1.46, 0.5, 3.3), Vector3(0, 0.32, 0)],
			[Vector3(1.3, 0.5, 1.9), Vector3(0, 0.84, -0.25)],
		],
		"engine_sound": {"base": 38.0, "harsh": 0.55},
		"colors": {
			"body": Color("#9ed9c5"), "accent": Color("#fff1d6"), "trim": Color("#6c6f86"),
			"glass": Color("#4a5578"), "light": Color("#fff6c2"), "tail": Color("#f28b9b"),
			"tyre": Color("#3d405b"), "hub": Color("#f4ead5"),
		},
		"parts": [
			["box", Vector3(1.5, 0.55, 3.35), Vector3(0, 0.3, 0), "body"],
			["box", Vector3(1.38, 0.55, 2.0), Vector3(0, 0.85, -0.25), "body"],
			["box", Vector3(1.4, 0.34, 2.02), Vector3(0, 0.9, -0.25), "glass"],
			["box", Vector3(1.4, 0.06, 1.95), Vector3(0, 1.15, -0.25), "accent"],
			["box", Vector3(1.54, 0.2, 3.39), Vector3(0, 0.12, 0), "trim"],
			["box", Vector3(1.2, 0.05, 1.4), Vector3(0, 1.22, -0.3), "trim"],
			["cyl", Vector3(0.28, 0.28, 0.18), Vector3(0, 1.34, -0.35), "tyre"],
			["box", Vector3(0.9, 0.16, 0.04), Vector3(0, 0.45, 1.68), "trim"],
			["box", Vector3(0.24, 0.12, 0.04), Vector3(-0.56, 0.45, 1.68), "light"],
			["box", Vector3(0.24, 0.12, 0.04), Vector3(0.56, 0.45, 1.68), "light"],
			["box", Vector3(0.16, 0.22, 0.04), Vector3(-0.62, 0.5, -1.68), "tail"],
			["box", Vector3(0.16, 0.22, 0.04), Vector3(0.62, 0.5, -1.68), "tail"],
			["box", Vector3(0.12, 0.1, 0.06), Vector3(-0.77, 0.78, 0.72), "trim"],
			["box", Vector3(0.12, 0.1, 0.06), Vector3(0.77, 0.78, 0.72), "trim"],
			["box", Vector3(1.52, 0.46, 0.02), Vector3(0, 0.33, 0.05), "trim"],
			["cyl", Vector3(0.035, 0.035, 0.25), Vector3(0.45, 0.08, -1.75), "trim", Vector3(90, 0, 0)],
			["box", Vector3(0.25, 0.22, 0.02), Vector3(-0.68, 0.02, -1.45), "trim"],
			["box", Vector3(0.25, 0.22, 0.02), Vector3(0.68, 0.02, -1.45), "trim"],
		],
		"exhaust": Vector3(0.45, 0.08, -1.9),
	}


static func _niva() -> Dictionary:
	return {
		"id": "niva",
		"name": "Lada Niva",
		"blurb": "Heavy, tall and soft as a sofa. Shrugs off rough ground and keeps going.",
		"stats": {"Speed": 3, "Climbing": 4, "Grip": 3, "Comfort": 5},
		"mass": 1150.0, "engine_force": 8600.0, "top_speed": 25.0, "drive": "awd",
		"brake": 45.0, "steer_max": 0.5,
		"drivetrain": {"gears": [3.67, 2.1, 1.36, 1.0, 0.82], "final": 3.9, "high": 1.2, "low": 2.135,
			"torque": 129.0, "peak_rpm": 4000.0, "idle": 800.0, "redline": 5400.0, "cda": 0.95},
		"wheel": {
			"radius": 0.37, "width": 0.24, "x": 0.74, "front_z": 1.1, "rear_z": -1.1, "y": 0.42,
			"rest": 0.34, "travel": 0.36, "stiffness": 30.0, "comp": 1.6, "relax": 2.1, "slip": 4.0, "roll": 0.45,
		},
		"com": Vector3(0, -0.2, 0.15),
		"collision": [
			[Vector3(1.62, 0.55, 3.66), Vector3(0, 0.42, 0)],
			[Vector3(1.5, 0.55, 1.9), Vector3(0, 0.98, -0.52)],
		],
		"engine_sound": {"base": 30.0, "harsh": 0.75},
		"colors": {
			"body": Color("#f7dc8c"), "accent": Color("#b5c99a"), "trim": Color("#5d5f73"),
			"glass": Color("#4a5578"), "light": Color("#fff6c2"), "tail": Color("#f28b9b"),
			"tyre": Color("#3d405b"), "hub": Color("#e9e4d4"),
		},
		"parts": [
			["box", Vector3(1.66, 0.6, 3.7), Vector3(0, 0.38, 0), "body"],
			["box", Vector3(1.56, 0.6, 1.95), Vector3(0, 0.98, -0.52), "body"],
			["box", Vector3(1.58, 0.38, 1.97), Vector3(0, 1.0, -0.52), "glass"],
			["box", Vector3(1.4, 0.08, 1.6), Vector3(0, 1.36, -0.55), "trim"],
			["box", Vector3(1.72, 0.24, 0.2), Vector3(0, 0.22, 1.86), "trim"],
			["box", Vector3(1.72, 0.24, 0.2), Vector3(0, 0.22, -1.86), "trim"],
			["box", Vector3(1.72, 0.12, 2.0), Vector3(0, 0.12, 0), "trim"],
			["box", Vector3(1.1, 0.26, 0.04), Vector3(0, 0.52, 1.86), "trim"],
			["cyl", Vector3(0.12, 0.12, 0.05), Vector3(-0.62, 0.52, 1.86), "light", Vector3(90, 0, 0)],
			["cyl", Vector3(0.12, 0.12, 0.05), Vector3(0.62, 0.52, 1.86), "light", Vector3(90, 0, 0)],
			["box", Vector3(0.14, 0.26, 0.04), Vector3(-0.7, 0.55, -1.86), "tail"],
			["box", Vector3(0.14, 0.26, 0.04), Vector3(0.7, 0.55, -1.86), "tail"],
			["cyl", Vector3(0.06, 0.06, 1.0), Vector3(0.86, 0.95, 0.5), "trim"],
			["box", Vector3(0.16, 0.12, 0.22), Vector3(0.86, 1.48, 0.55), "trim"],
			["box", Vector3(0.36, 0.46, 0.16), Vector3(0.45, 0.62, -1.93), "accent"],
			["box", Vector3(0.12, 0.12, 0.06), Vector3(-0.85, 0.86, 0.43), "trim"],
			["box", Vector3(0.12, 0.12, 0.06), Vector3(0.85, 0.86, 0.43), "trim"],
			["box", Vector3(1.68, 0.56, 0.02), Vector3(0, 0.38, 0.2), "trim"],
			["cyl", Vector3(0.04, 0.04, 0.3), Vector3(-0.5, 0.12, -1.9), "trim", Vector3(90, 0, 0)],
			["box", Vector3(0.28, 0.26, 0.02), Vector3(-0.74, 0.08, -1.5), "trim"],
			["box", Vector3(0.28, 0.26, 0.02), Vector3(0.74, 0.08, -1.5), "trim"],
		],
		"exhaust": Vector3(-0.5, 0.12, -2.05),
	}


static func _mini() -> Dictionary:
	return {
		"id": "mini_rally",
		"name": "Mini Rally",
		"blurb": "Tiny, quick and a little nervous. Front-wheel drive, so steep climbs need a run-up.",
		"stats": {"Speed": 5, "Climbing": 2, "Grip": 3, "Comfort": 2},
		"mass": 720.0, "engine_force": 6400.0, "top_speed": 33.0, "drive": "fwd",
		"brake": 30.0, "steer_max": 0.6,
		"drivetrain": {"gears": [2.69, 1.75, 1.29, 1.0], "final": 4.2, "high": 1.0, "low": 0.0,
			"torque": 115.0, "peak_rpm": 4500.0, "idle": 950.0, "redline": 7000.0, "cda": 0.6},
		"wheel": {
			"radius": 0.29, "width": 0.2, "x": 0.62, "front_z": 1.02, "rear_z": -1.02, "y": 0.3,
			"rest": 0.19, "travel": 0.16, "stiffness": 55.0, "comp": 3.0, "relax": 3.6, "slip": 3.4, "roll": 0.55,
		},
		"com": Vector3(0, -0.12, 0.25),
		"collision": [
			[Vector3(1.38, 0.45, 3.0), Vector3(0, 0.32, 0)],
			[Vector3(1.26, 0.45, 1.7), Vector3(0, 0.79, -0.3)],
		],
		"engine_sound": {"base": 46.0, "harsh": 0.65},
		"colors": {
			"body": Color("#f4978e"), "accent": Color("#fff6ee"), "trim": Color("#5b5e75"),
			"glass": Color("#4a5578"), "light": Color("#fff3b0"), "tail": Color("#f28b9b"),
			"tyre": Color("#3d405b"), "hub": Color("#fff6ee"),
		},
		"parts": [
			["box", Vector3(1.42, 0.5, 3.05), Vector3(0, 0.3, 0), "body"],
			["box", Vector3(1.3, 0.48, 1.75), Vector3(0, 0.79, -0.3), "body"],
			["box", Vector3(1.32, 0.3, 1.77), Vector3(0, 0.82, -0.3), "glass"],
			["box", Vector3(1.34, 0.07, 1.68), Vector3(0, 1.05, -0.3), "accent"],
			["box", Vector3(0.22, 0.02, 1.0), Vector3(-0.3, 0.56, 1.0), "accent"],
			["box", Vector3(0.22, 0.02, 1.0), Vector3(0.3, 0.56, 1.0), "accent"],
			["box", Vector3(1.46, 0.14, 0.12), Vector3(0, 0.14, 1.55), "trim"],
			["box", Vector3(1.46, 0.14, 0.12), Vector3(0, 0.14, -1.55), "trim"],
			["cyl", Vector3(0.1, 0.1, 0.04), Vector3(-0.48, 0.45, 1.535), "light", Vector3(90, 0, 0)],
			["cyl", Vector3(0.1, 0.1, 0.04), Vector3(0.48, 0.45, 1.535), "light", Vector3(90, 0, 0)],
			["box", Vector3(1.0, 0.05, 0.05), Vector3(0, 0.62, 1.48), "trim"],
			["cyl", Vector3(0.11, 0.11, 0.06), Vector3(-0.33, 0.7, 1.5), "light", Vector3(90, 0, 0)],
			["cyl", Vector3(0.11, 0.11, 0.06), Vector3(-0.11, 0.7, 1.5), "light", Vector3(90, 0, 0)],
			["cyl", Vector3(0.11, 0.11, 0.06), Vector3(0.11, 0.7, 1.5), "light", Vector3(90, 0, 0)],
			["cyl", Vector3(0.11, 0.11, 0.06), Vector3(0.33, 0.7, 1.5), "light", Vector3(90, 0, 0)],
			["cyl", Vector3(0.24, 0.24, 0.02), Vector3(-0.715, 0.36, 0.1), "accent", Vector3(0, 0, 90)],
			["cyl", Vector3(0.24, 0.24, 0.02), Vector3(0.715, 0.36, 0.1), "accent", Vector3(0, 0, 90)],
			["label", "37", Vector3(0.73, 0.36, 0.1), "trim", Vector3(0, 90, 0)],
			["label", "37", Vector3(-0.73, 0.36, 0.1), "trim", Vector3(0, -90, 0)],
			["box", Vector3(0.14, 0.18, 0.04), Vector3(-0.58, 0.45, -1.535), "tail"],
			["box", Vector3(0.14, 0.18, 0.04), Vector3(0.58, 0.45, -1.535), "tail"],
			["box", Vector3(0.1, 0.09, 0.05), Vector3(-0.71, 0.7, 0.55), "trim"],
			["box", Vector3(0.1, 0.09, 0.05), Vector3(0.71, 0.7, 0.55), "trim"],
			["box", Vector3(1.44, 0.44, 0.02), Vector3(0, 0.3, 0.45), "trim"],
			["cyl", Vector3(0.035, 0.035, 0.22), Vector3(-0.4, 0.07, -1.6), "trim", Vector3(90, 0, 0)],
			["box", Vector3(0.24, 0.2, 0.02), Vector3(-0.62, 0.0, -1.36), "trim"],
			["box", Vector3(0.24, 0.2, 0.02), Vector3(0.62, 0.0, -1.36), "trim"],
		],
		"exhaust": Vector3(-0.4, 0.07, -1.75),
	}
