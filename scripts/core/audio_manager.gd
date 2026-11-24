extends Node
## Autoload "AudioManager": one-shot sound effects on the SFX bus, and a
## click sound for every button in the game (hooked automatically).

const SFX_DIR := "res://assets/audio/sfx/"
const SOUNDS: Array[StringName] = [&"click", &"open", &"pickup", &"till", &"water", &"plant",
	&"harvest", &"coin", &"rock", &"weed", &"error", &"sleep", &"thunder",
	&"step_grass", &"step_stone", &"step_wood"]
const MUSIC_DIR := "res://assets/audio/music/"
const AMBIENT_DIR := "res://assets/audio/ambient/"
const MUSIC_FADE := 1.6
## Volume offset per context (indoors the music is a little softer).
const MUSIC_INDOOR_DB := -4.0
const POOL_SIZE := 8

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: Array[AudioStreamPlayer] = []
var _music_index := 0
var _music_track := ""
var _ambience: AudioStreamPlayer
var _ambience_track := ""
var _loops: Dictionary = {}
## Headless runs (tests, CI) have no audio output; skip playback there.
var _headless := DisplayServer.get_name() == "headless"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameSettings.ensure_audio_buses()
	for sound in SOUNDS:
		var stream := load(SFX_DIR + String(sound) + ".wav") as AudioStream
		if stream:
			_streams[sound] = stream
		else:
			push_warning("AudioManager: missing sound %s" % sound)
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = GameSettings.BUS_SFX
		add_child(player)
		_players.append(player)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = GameSettings.BUS_MUSIC
		m.volume_db = -80.0
		add_child(m)
		_music.append(m)
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = GameSettings.BUS_AMBIENT
	add_child(_ambience)
	get_tree().node_added.connect(_on_node_added)


## Crossfades to a music track ("spring", "summer", "autumn", "winter",
## "title"). Calling it again with the same track only adjusts the volume.
func play_music(track: String, volume_db: float = 0.0) -> void:
	var current := _music[_music_index]
	if track == _music_track:
		create_tween().tween_property(current, "volume_db", volume_db, MUSIC_FADE)
		return
	_music_track = track
	var stream := _loop_stream(MUSIC_DIR + track + ".wav")
	if stream == null:
		return
	var old := current
	_music_index = 1 - _music_index
	var player := _music[_music_index]
	player.stream = stream
	player.volume_db = -40.0
	if not _headless:
		player.play()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(player, "volume_db", volume_db, MUSIC_FADE)
	tween.tween_property(old, "volume_db", -60.0, MUSIC_FADE)
	tween.chain().tween_callback(old.stop)


func current_music() -> String:
	return _music_track


## Background ambience loop ("birds", "water") or "" for none.
func play_ambience(track: String, volume_db: float = -6.0) -> void:
	if track == _ambience_track:
		return
	_ambience_track = track
	_ambience.stop()
	if track.is_empty():
		return
	_ambience.stream = _loop_stream(AMBIENT_DIR + track + "_loop.wav")
	_ambience.volume_db = volume_db
	if not _headless and _ambience.stream:
		_ambience.play()


func current_ambience() -> String:
	return _ambience_track


func _loop_stream(path: String) -> AudioStream:
	if _loops.has(path):
		return _loops[path]
	var stream := load(path) as AudioStream if ResourceLoader.exists(path) else null
	if stream:
		stream = make_loop(stream)
	_loops[path] = stream
	return stream


func play(sound: StringName, volume_db: float = 0.0, pitch_jitter: float = 0.06) -> void:
	var stream: AudioStream = _streams.get(sound)
	if stream == null or _headless:
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	player.play()


func stop_all() -> void:
	for player in _players + _music + [_ambience]:
		player.stop()
		player.stream = null


## Makes a looping copy of an ambient WAV (loop points aren't stored in
## the generated files).
static func make_loop(stream: AudioStream) -> AudioStream:
	var wav := stream as AudioStreamWAV
	if wav == null:
		return stream
	var copy := wav.duplicate() as AudioStreamWAV
	copy.loop_mode = AudioStreamWAV.LOOP_FORWARD
	copy.loop_begin = 0
	copy.loop_end = copy.data.size() / 2
	return copy


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		var button := node as BaseButton
		var cb := play.bind(&"click", -6.0, 0.03)
		if not button.pressed.is_connected(cb):
			button.pressed.connect(cb)
