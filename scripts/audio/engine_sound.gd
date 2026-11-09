class_name EngineSound
extends Node
## Engine, tyre rumble and slide hiss. Each is a short loop rendered once at start-up and
## played back with pitch and volume following the car, so it costs almost no CPU per frame.

const SR := 22050
const LOOP := 1.0

var car: Car
var _engine: AudioStreamPlayer
var _rumble: AudioStreamPlayer
var _hiss: AudioStreamPlayer


func setup(c: Car) -> void:
	car = c
	var es: Dictionary = c.spec["engine_sound"]
	_engine = _player(_engine_loop(float(es["base"]), float(es["harsh"])))
	_rumble = _player(_noise_loop(0.04, 7))
	_hiss = _player(_noise_loop(-0.5, 8))


func _player(stream: AudioStreamWAV) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = -60.0
	add_child(p)
	p.play()
	return p


## One second of engine note at base_hz: pulse + saw + sine. Whole cycles, so it loops cleanly.
static func _engine_loop(base_hz: float, harsh: float) -> AudioStreamWAV:
	var n := int(SR * LOOP)
	var f := roundf(base_hz * LOOP) / LOOP
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp := 0.0
	for i in n:
		var ph := fmod(f * i / SR, 1.0)
		var ph2 := fmod(f * 0.5 * i / SR, 1.0)
		var pulse := 1.0 if ph2 < 0.35 else -0.6
		var s := sin(ph * TAU) * (1.0 - harsh) + (ph * 2.0 - 1.0) * harsh * 0.6 + pulse * 0.25
		lp += (s - lp) * 0.3
		buf[i] = lp * 0.5
	return AudioUtil.wav(AudioUtil.to_pcm(buf), SR, true)


## Filtered noise loop: positive cutoff = low-pass (rumble), negative = high-pass (hiss).
static func _noise_loop(cutoff: float, seed_value: int) -> AudioStreamWAV:
	var n := int(SR * LOOP)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var lp := 0.0
	var k := absf(cutoff)
	for i in n:
		var x := rng.randf_range(-1.0, 1.0)
		lp += (x - lp) * k
		buf[i] = (lp * 3.0 if cutoff > 0.0 else (x - lp)) * 0.5
	var fade := 600
	for i in fade:
		var a := float(i) / fade
		buf[i] = buf[i] * a + buf[n - fade + i] * (1.0 - a)
	return AudioUtil.wav(AudioUtil.to_pcm(buf.slice(0, n - fade)), SR, true)


func _process(delta: float) -> void:
	if not car or not _engine:
		return
	var master := maxf(float(GameState.settings["engine"]), 0.0001)
	var k := 1.0 - exp(-delta * 10.0)
	_engine.pitch_scale = lerpf(_engine.pitch_scale, 0.55 + car.rpm * 2.4, k)
	var eng := (0.25 + 0.5 * car.throttle + 0.15 * car.rpm) * master
	_engine.volume_db = lerpf(_engine.volume_db, linear_to_db(maxf(eng, 0.0001)) - 4.0, k)
	var rough: float = [0.5, 0.75, 1.0, 0.35, 0.9, 0.6, 0.85][car.surface]
	var speed := car.linear_velocity.length()
	var rum := clampf(speed / 20.0, 0.0, 1.0) * rough * master if car.grounded else 0.0
	_rumble.volume_db = lerpf(_rumble.volume_db, linear_to_db(maxf(rum, 0.0001)) - 8.0, k)
	_rumble.pitch_scale = 0.7 + clampf(speed / 30.0, 0.0, 0.8)
	var hiss := clampf(car.skid * 1.4, 0.0, 1.0) * clampf(speed / 6.0, 0.0, 1.0) * master
	_hiss.volume_db = lerpf(_hiss.volume_db, linear_to_db(maxf(hiss, 0.0001)) - 12.0, k)
