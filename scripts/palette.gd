class_name Palette
extends RefCounted
## Pastel colours for each time of day. t: 0 = midnight, 0.25 = sunrise, 0.5 = noon, 0.75 = sunset.

const NIGHT := {
	"top": Color("#2e3a6b"), "horizon": Color("#5b5f97"), "fog": Color("#4c5487"),
	"light": Color("#a9b8ff"), "energy": 0.22, "ambient": 0.3,
}
const DAWN := {
	"top": Color("#8fa3d9"), "horizon": Color("#ffc4b8"), "fog": Color("#f5c6c0"),
	"light": Color("#ffc9a3"), "energy": 0.6, "ambient": 0.3,
}
const MORNING := {
	"top": Color("#a9cdf0"), "horizon": Color("#fde7d3"), "fog": Color("#ece3e6"),
	"light": Color("#fff0dc"), "energy": 0.8, "ambient": 0.32,
}
const NOON := {
	"top": Color("#9ccbf2"), "horizon": Color("#e6f0f7"), "fog": Color("#dde9f2"),
	"light": Color("#fff8ec"), "energy": 0.88, "ambient": 0.34,
}
const GOLDEN := {
	"top": Color("#b7b6e8"), "horizon": Color("#ffd2a6"), "fog": Color("#f7d4bd"),
	"light": Color("#ffd29a"), "energy": 0.78, "ambient": 0.32,
}
const DUSK := {
	"top": Color("#7d79c2"), "horizon": Color("#f7a8b8"), "fog": Color("#c79bbf"),
	"light": Color("#ff9eaa"), "energy": 0.5, "ambient": 0.3,
}

static var KEYS: Array = [
	[0.0, NIGHT], [0.2, NIGHT], [0.25, DAWN], [0.32, MORNING], [0.5, NOON],
	[0.64, MORNING], [0.71, GOLDEN], [0.77, DUSK], [0.82, NIGHT], [1.0, NIGHT],
]


static func sample(t: float) -> Dictionary:
	t = fposmod(t, 1.0)
	for i in KEYS.size() - 1:
		var k0: Array = KEYS[i]
		var k1: Array = KEYS[i + 1]
		var t0: float = k0[0]
		var t1: float = k1[0]
		if t >= t0 and t <= t1:
			var f := 0.0 if t1 == t0 else (t - t0) / (t1 - t0)
			f = f * f * (3.0 - 2.0 * f)
			return _mix(k0[1], k1[1], f)
	return NIGHT


static func _mix(a: Dictionary, b: Dictionary, f: float) -> Dictionary:
	var out := {}
	for k in a:
		var va: Variant = a[k]
		var vb: Variant = b[k]
		if va is Color:
			out[k] = (va as Color).lerp(vb as Color, f)
		else:
			out[k] = lerpf(float(va), float(vb), f)
	return out
