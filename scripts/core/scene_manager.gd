extends CanvasLayer
## Autoload "SceneManager": scene changes with a soft fade transition.

signal scene_changed(path: String)

const FADE_TIME := 0.35
const FADE_COLOR := Color("2b1f2e")

var _veil: ColorRect
var _busy := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_veil = ColorRect.new()
	_veil.color = FADE_COLOR
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.modulate.a = 0.0
	add_child(_veil)


func is_busy() -> bool:
	return _busy


func change_scene(path: String) -> void:
	if _busy:
		return
	if not ResourceLoader.exists(path):
		push_error("SceneManager: scene not found: %s" % path)
		return
	_busy = true
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	await _fade_to(1.0)
	get_tree().paused = false
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("SceneManager: failed to change to %s (error %d)" % [path, err])
	await get_tree().process_frame
	await get_tree().process_frame
	await _fade_to(0.0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
	scene_changed.emit(path)


## Fades to the veil colour without changing scene (e.g. sleeping).
## Pair with fade_in().
func fade_out() -> void:
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	await _fade_to(1.0)


func fade_in() -> void:
	await _fade_to(0.0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE


func quit_game() -> void:
	if _busy:
		return
	_busy = true
	await _fade_to(1.0)
	get_tree().quit()


func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_veil, "modulate:a", alpha, FADE_TIME).set_trans(Tween.TRANS_SINE)
	await tween.finished
