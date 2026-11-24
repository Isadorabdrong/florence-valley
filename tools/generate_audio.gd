extends SceneTree
## Synthesises Florence Valley's original sound effects and ambient loops
## (22.05 kHz mono WAV). Deterministic; run after changing a recipe:
##   godot --headless --path . --script res://tools/generate_audio.gd

const RATE := 22050
const SFX_DIR := "res://assets/audio/sfx/"
const AMBIENT_DIR := "res://assets/audio/ambient/"

var _rng := RandomNumberGenerator.new()
var _failed := false


func _initialize() -> void:
	_rng.seed = 4242
	_write(SFX_DIR + "click.wav", _click())
	_write(SFX_DIR + "open.wav", _sweep(560.0, 880.0, 0.12, 0.35))
	_write(SFX_DIR + "pickup.wav", _sweep(880.0, 1320.0, 0.1, 0.35))
	_write(SFX_DIR + "till.wav", _till())
	_write(SFX_DIR + "water.wav", _water())
	_write(SFX_DIR + "plant.wav", _sweep(620.0, 300.0, 0.12, 0.6))
	_write(SFX_DIR + "harvest.wav", _notes([1047.0, 1319.0, 1568.0], 0.085, 0.5))
	_write(SFX_DIR + "coin.wav", _notes([1319.0, 1760.0], 0.075, 0.45))
	_write(SFX_DIR + "rock.wav", _rock())
	_write(SFX_DIR + "weed.wav", _swish())
	_write(SFX_DIR + "error.wav", _notes([330.0, 247.0], 0.09, 0.35, true))
	_write(SFX_DIR + "sleep.wav", _chord([523.25, 659.25, 783.99], 1.4))
	_write(SFX_DIR + "thunder.wav", _thunder())
	# Phase 8: footsteps and more ambience
	_write(SFX_DIR + "step_grass.wav", _step(0.05, 0.12, 70.0))
	_write(SFX_DIR + "step_stone.wav", _step(0.35, 0.07, 900.0))
	_write(SFX_DIR + "step_wood.wav", _step(0.15, 0.09, 320.0))
	_write(AMBIENT_DIR + "birds_loop.wav", _birds(8.0))
	_write(AMBIENT_DIR + "water_loop.wav", _loop(_lapping, 5.0))
	_write(AMBIENT_DIR + "rain_loop.wav", _loop(_rain, 4.0))
	_write(AMBIENT_DIR + "wind_loop.wav", _loop(_wind, 6.0))
	if _failed:
		quit(1)
	else:
		print("[audio] all sounds generated")
		quit(0)


func _write(path: String, samples: PackedFloat32Array) -> void:
	var peak := 0.0001
	for s in samples:
		peak = maxf(peak, absf(s))
	var gain := 0.8 / peak
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i] * gain, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var err := wav.save_to_wav(path)
	if err != OK:
		push_error("[audio] could not save %s" % path)
		_failed = true
	else:
		print("[audio] wrote ", path)


func _buffer(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


func _click() -> PackedFloat32Array:
	var b := _buffer(0.04)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = (sin(TAU * 1400.0 * t) + 0.3 * sin(TAU * 2800.0 * t)) * exp(-t * 120.0)
	return b


func _sweep(f0: float, f1: float, seconds: float, decay: float) -> PackedFloat32Array:
	var b := _buffer(seconds)
	var phase := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var f := lerpf(f0, f1, t / seconds)
		phase += TAU * f / RATE
		b[i] = sin(phase) * exp(-t / (seconds * decay)) * minf(1.0, t * 400.0)
	return b


func _notes(freqs: Array, step: float, decay: float, square := false) -> PackedFloat32Array:
	var b := _buffer(step * freqs.size() + 0.35)
	for n in freqs.size():
		var start := int(n * step * RATE)
		for i in range(start, b.size()):
			var t := float(i - start) / RATE
			var w := TAU * float(freqs[n]) * t
			var v := signf(sin(w)) * 0.4 if square else sin(w) + 0.25 * sin(2.0 * w)
			b[i] += v * exp(-t / (decay * 0.3)) * minf(1.0, t * 600.0)
	return b


func _chord(freqs: Array, seconds: float) -> PackedFloat32Array:
	var b := _buffer(seconds)
	for i in b.size():
		var t := float(i) / RATE
		var v := 0.0
		for k in freqs.size():
			v += sin(TAU * float(freqs[k]) * t + k) * exp(-t * (1.6 + k * 0.4))
		b[i] = v * minf(1.0, t * 80.0)
	return b


func _till() -> PackedFloat32Array:
	var b := _buffer(0.24)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += 0.08 * (_rng.randf_range(-1.0, 1.0) - lp)
		b[i] = lp * 3.0 * exp(-t * 16.0) + sin(TAU * 90.0 * t) * exp(-t * 28.0) * 0.6
	return b


func _water() -> PackedFloat32Array:
	var b := _buffer(0.5)
	var lo := 0.0
	var hi := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var n := _rng.randf_range(-1.0, 1.0)
		hi += 0.35 * (n - hi)
		lo += 0.04 * (n - lo)
		var band := hi - lo
		var wobble := 0.6 + 0.4 * sin(TAU * 17.0 * t)
		b[i] = band * wobble * sin(PI * t / 0.5)
	return b


func _rock() -> PackedFloat32Array:
	var b := _buffer(0.26)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += 0.25 * (_rng.randf_range(-1.0, 1.0) - lp)
		b[i] = lp * exp(-t * 24.0) + sin(TAU * 210.0 * t) * exp(-t * 30.0) * 0.7
	return b


func _swish() -> PackedFloat32Array:
	var b := _buffer(0.2)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var n := _rng.randf_range(-1.0, 1.0)
		lp += 0.2 * (n - lp)
		b[i] = (n - lp) * sin(PI * t / 0.2) * 0.8
	return b


func _thunder() -> PackedFloat32Array:
	var b := _buffer(2.2)
	var lp := 0.0
	var lp2 := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += 0.02 * (_rng.randf_range(-1.0, 1.0) - lp)
		lp2 += 0.05 * (lp - lp2)
		var env := minf(1.0, t * 12.0) * exp(-t * 1.6) * (0.7 + 0.3 * sin(TAU * 3.0 * t))
		b[i] = lp2 * env
	return b


func _rain(i: int, state: Array) -> float:
	var n := _rng.randf_range(-1.0, 1.0)
	state[0] += 0.35 * (n - state[0])
	var drop := 0.0
	if _rng.randf() < 0.002:
		state[1] = 1.0
	state[1] *= 0.995
	drop = state[1] * sin(float(i) * 0.9)
	return state[0] * 0.8 + drop * 0.3


func _wind(i: int, state: Array) -> float:
	var t := float(i) / RATE
	var cutoff := 0.01 + 0.03 * (0.5 + 0.5 * sin(TAU * t / 3.0))
	state[0] += cutoff * (_rng.randf_range(-1.0, 1.0) - state[0])
	return state[0] * 4.0


## A soft footstep: filtered noise burst plus a low knock.
func _step(brightness: float, seconds: float, knock_hz: float) -> PackedFloat32Array:
	var b := _buffer(seconds)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += brightness * (_rng.randf_range(-1.0, 1.0) - lp)
		b[i] = (lp * 2.0 + sin(TAU * knock_hz * t) * 0.4) * exp(-t * 45.0) * minf(1.0, t * 800.0)
	return b


## Sparse bird chirps (frequency sweeps) over silence; starts/ends quiet so
## it loops cleanly.
func _birds(seconds: float) -> PackedFloat32Array:
	var b := _buffer(seconds)
	var t := 0.4
	while t < seconds - 0.6:
		var f0 := _rng.randf_range(2200.0, 3600.0)
		var notes := _rng.randi_range(2, 4)
		for k in notes:
			var start := int((t + k * 0.11) * RATE)
			var length := int(0.08 * RATE)
			var phase := 0.0
			for i in length:
				var idx := start + i
				if idx >= b.size():
					break
				var u := float(i) / length
				phase += TAU * (f0 + 900.0 * sin(u * PI)) / RATE
				b[idx] += sin(phase) * sin(u * PI) * 0.35
		t += _rng.randf_range(0.8, 2.2)
	return b


func _lapping(i: int, state: Array) -> float:
	var t := float(i) / RATE
	state[0] += 0.05 * (_rng.randf_range(-1.0, 1.0) - state[0])
	return state[0] * 2.0 * (0.55 + 0.45 * sin(TAU * t / 2.5))


## Renders `seconds` + 0.5 s and crossfades the tail into the head so the
## sample loops seamlessly.
func _loop(gen: Callable, seconds: float) -> PackedFloat32Array:
	var fade := int(0.5 * RATE)
	var total := int(seconds * RATE)
	var raw := PackedFloat32Array()
	raw.resize(total + fade)
	var state := [0.0, 0.0]
	for i in raw.size():
		raw[i] = gen.call(i, state)
	var out := PackedFloat32Array()
	out.resize(total)
	for i in total:
		out[i] = raw[i]
	for i in fade:
		var t := float(i) / fade
		out[i] = raw[total + i] * (1.0 - t) + raw[i] * t
	return out
