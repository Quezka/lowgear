extends AudioStreamPlayer
## Autoload "Music": a 16-bar lofi loop (Rhodes-ish chords, bass, lazy drums, vinyl crackle).
## Rendered once in a background thread, then cached in user:// so later starts are instant.

const SR := 22050
const BPM := 72.0
const BARS := 16
const CACHE := "user://lofi_v1.pcm"

var _thread: Thread
var _target_db := -8.0
var _buf := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.settings_changed.connect(_apply_volume)
	_apply_volume()
	if FileAccess.file_exists(CACHE):
		var data := FileAccess.get_file_as_bytes(CACHE)
		if data.size() > 100000:
			_start(data)
			return
	_thread = Thread.new()
	_thread.start(_render_thread)


func _apply_volume() -> void:
	var v: float = GameState.settings.get("music", 0.7)
	_target_db = linear_to_db(maxf(v, 0.0001)) - 6.0
	if playing:
		volume_db = _target_db


func _render_thread() -> void:
	var t0 := Time.get_ticks_msec()
	_render()
	var pcm := AudioUtil.to_pcm(_buf)
	_buf = PackedFloat32Array()
	print("[music] rendered in %d ms" % (Time.get_ticks_msec() - t0))
	call_deferred("_on_rendered", pcm)


func _on_rendered(pcm: PackedByteArray) -> void:
	_thread.wait_to_finish()
	var f := FileAccess.open(CACHE, FileAccess.WRITE)
	if f:
		f.store_buffer(pcm)
		f.close()
	_start(pcm)


func _start(pcm: PackedByteArray) -> void:
	stream = AudioUtil.wav(pcm, SR, true)
	volume_db = -60.0
	play()
	create_tween().tween_property(self, "volume_db", _target_db, 4.0)


# --- synthesis -----------------------------------------------------------------

func _render() -> void:
	var beat := 60.0 / BPM
	var bar := beat * 4.0
	var total := int(bar * BARS * SR)
	_buf.resize(total)
	_buf.fill(0.0)
	_rng.seed = 72
	# Bass note, then chord voicing (MIDI). Fmaj9 Em9 Dm9 Cmaj9 / Am9 Dm9 G13 Cmaj9
	var prog := [
		[41, [57, 60, 64, 67]], [40, [55, 59, 62, 66]], [38, [53, 57, 60, 64]], [36, [52, 55, 59, 62]],
		[33, [55, 60, 64, 67]], [38, [53, 57, 60, 64]], [43, [53, 57, 59, 64]], [36, [52, 55, 59, 64]],
	]
	var melody := [64, 67, 69, 72, 74, 76, 79]
	for b in BARS:
		var t0 := b * bar
		var ch: Array = prog[b % 8]
		var notes: Array = ch[1]
		var root: int = ch[0]
		_chord(t0 + 0.015, notes, 0.07)
		_chord(t0 + beat * 2.5 + 0.03, notes, 0.045)
		_tone(t0, AudioUtil.hz(root), 0.2, 1.7, 1.3, 1)
		_tone(t0 + beat * 2.5, AudioUtil.hz(root + (7 if b % 2 == 1 else 0)), 0.16, 1.2, 1.8, 1)
		_kick(t0)
		_kick(t0 + beat * 2.5)
		if b % 4 == 3:
			_kick(t0 + beat * 3.5)
		_snare(t0 + beat + 0.035)
		_snare(t0 + beat * 3.0 + 0.035)
		for e in 8:
			var swing := 0.09 if e % 2 == 1 else 0.0
			_hat(t0 + (e * 0.5 + swing) * beat, 0.05 if e % 2 == 0 else 0.032)
		if b >= 8 or b % 4 >= 2:
			for e in 8:
				if _rng.randf() < 0.3:
					var m: int = melody[_rng.randi_range(0, melody.size() - 1)]
					var swing := 0.09 if e % 2 == 1 else 0.0
					_tone(t0 + (e * 0.5 + swing) * beat, AudioUtil.hz(m), 0.05, 1.4, 2.4, 2)
	_vinyl()
	_master()


func _chord(t: float, notes: Array, amp: float) -> void:
	var k := 0
	for n in notes:
		_tone(t + k * 0.012 + _rng.randf_range(0.0, 0.006), AudioUtil.hz(n), amp * _rng.randf_range(0.85, 1.0), 2.2, 1.5, 0)
		k += 1


## kind: 0 keys, 1 bass, 2 bell
func _tone(start: float, freq: float, amp: float, dur: float, decay: float, kind: int) -> void:
	var total := _buf.size()
	var n := int(dur * SR)
	var s0 := int(start * SR)
	var ph := 0.0
	var env := 1.0
	var dmul := exp(-decay / SR)
	var fast := 1.0
	var fmul := exp(-8.0 / SR)
	var fade_start := int(n * 0.85)
	var inc := TAU * freq / SR
	for i in n:
		var t := start + float(i) / SR
		ph += inc * (1.0 + 0.0025 * sin(TAU * 0.33 * t))
		var s := sin(ph)
		var v: float
		if kind == 0:
			v = s + 0.22 * sin(2.0 * ph) * fast + 0.05 * sin(3.0 * ph)
		elif kind == 1:
			v = s + 0.15 * sin(2.0 * ph)
		else:
			v = s + 0.3 * sin(2.76 * ph) * fast
		var a := env * minf(1.0, float(i) / 60.0)
		if i > fade_start:
			a *= float(n - i) / float(n - fade_start)
		var k := (s0 + i) % total
		_buf[k] += v * a * amp
		env *= dmul
		fast *= fmul


func _kick(start: float) -> void:
	var total := _buf.size()
	var s0 := int(start * SR)
	var ph := 0.0
	for i in int(0.45 * SR):
		var t := float(i) / SR
		ph += TAU * (45.0 + 75.0 * exp(-t * 28.0)) / SR
		_buf[(s0 + i) % total] += sin(ph) * exp(-t * 8.0) * 0.5


func _snare(start: float) -> void:
	var total := _buf.size()
	var s0 := int(start * SR)
	var lp := 0.0
	for i in int(0.22 * SR):
		var t := float(i) / SR
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * 0.45
		_buf[(s0 + i) % total] += lp * exp(-t * 20.0) * 0.16 + sin(TAU * 185.0 * t) * exp(-t * 30.0) * 0.07


func _hat(start: float, amp: float) -> void:
	var total := _buf.size()
	var s0 := int(start * SR)
	var lp := 0.0
	for i in int(0.06 * SR):
		var t := float(i) / SR
		var x := _rng.randf_range(-1.0, 1.0)
		lp += (x - lp) * 0.3
		_buf[(s0 + i) % total] += (x - lp) * exp(-t * 80.0) * amp


func _vinyl() -> void:
	var total := _buf.size()
	for i in total:
		_buf[i] += _rng.randf_range(-1.0, 1.0) * 0.003
		if _rng.randf() < 0.0003:
			var a := _rng.randf_range(0.04, 0.12) * (1.0 if _rng.randf() < 0.5 else -1.0)
			for k in 10:
				_buf[(i + k) % total] += a * (1.0 - k / 10.0)


func _master() -> void:
	var lp := 0.0
	var peak := 0.001
	for i in _buf.size():
		lp += (_buf[i] - lp) * 0.55
		_buf[i] = lp
		peak = maxf(peak, absf(lp))
	var g := 0.85 / peak * 1.2
	for i in _buf.size():
		var x := _buf[i] * g
		_buf[i] = x / (1.0 + absf(x)) * 1.1
