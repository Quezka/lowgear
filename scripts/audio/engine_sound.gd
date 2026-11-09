class_name EngineSound
extends AudioStreamPlayer
## Live engine note: pitch follows the fake gearbox rpm, timbre per car.

const SR := 22050.0

var car: Car
var base := 38.0
var harsh := 0.5
var _pb: AudioStreamGeneratorPlayback
var _ph := 0.0
var _ph2 := 0.0
var _lp := 0.0
var _amp := 0.0
var _rumble_lp := 0.0
var _hiss_lp := 0.0
var _rumble_amp := 0.0
var _hiss_amp := 0.0
var _rng := RandomNumberGenerator.new()


func setup(c: Car) -> void:
	car = c
	var es: Dictionary = c.spec["engine_sound"]
	base = es["base"]
	harsh = es["harsh"]
	var g := AudioStreamGenerator.new()
	g.mix_rate = SR
	g.buffer_length = 0.12
	stream = g
	apply_volume()
	play()
	_pb = get_stream_playback()


func apply_volume() -> void:
	volume_db = linear_to_db(maxf(float(GameState.settings["engine"]) * 0.9, 0.0001))


func _process(_delta: float) -> void:
	if not _pb or not car:
		return
	var n := _pb.get_frames_available()
	if n <= 0:
		return
	var inc := base * (0.55 + car.rpm * 2.4) / SR
	var target := 0.10 + 0.16 * car.throttle + 0.05 * car.rpm
	var cutoff := 0.12 + 0.35 * car.throttle
	var noise := 0.08 * car.throttle
	# Tyres: low rumble from the ground (rougher on rock and sand), hiss when sliding.
	var rough: float = [0.5, 0.75, 1.0, 0.35, 0.9][car.surface]
	var speed := car.linear_velocity.length()
	var rumble_target := clampf(speed / 20.0, 0.0, 1.0) * rough * 0.5 if car.grounded else 0.0
	var hiss_target := clampf(car.skid * 1.4, 0.0, 1.0) * clampf(speed / 6.0, 0.0, 1.0) * 0.35
	var buf := PackedVector2Array()
	buf.resize(n)
	for i in n:
		_amp += (target - _amp) * 0.002
		_ph = fmod(_ph + inc, 1.0)
		_ph2 = fmod(_ph2 + inc * 0.5, 1.0)
		var pulse := 1.0 if _ph2 < 0.35 else -0.6
		var s := sin(_ph * TAU) * (1.0 - harsh) + (_ph * 2.0 - 1.0) * harsh * 0.6 + pulse * 0.25 + _rng.randf_range(-1.0, 1.0) * noise
		_lp += (s - _lp) * cutoff
		_rumble_amp += (rumble_target - _rumble_amp) * 0.001
		_hiss_amp += (hiss_target - _hiss_amp) * 0.002
		var nz := _rng.randf_range(-1.0, 1.0)
		_rumble_lp += (nz - _rumble_lp) * 0.04
		_hiss_lp += (nz - _hiss_lp) * 0.5
		var v := _lp * _amp + _rumble_lp * _rumble_amp * 1.6 + (nz - _hiss_lp) * _hiss_amp
		buf[i] = Vector2(v, v)
	_pb.push_buffer(buf)
