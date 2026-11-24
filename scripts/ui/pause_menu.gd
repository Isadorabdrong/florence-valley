extends CanvasLayer
## Pause menu (Esc / Start). Pauses the scene tree while open.

const MAIN_MENU_SCENE := "res://scenes/main/main_menu.tscn"

@onready var _root: Control = $Root
@onready var _panel: Control = $Root/Center
@onready var _resume: Button = %ResumeButton
@onready var _save: Button = %SaveButton
@onready var _settings: Button = %SettingsButton
@onready var _main_menu: Button = %MainMenuButton
@onready var _quit: Button = %QuitButton
@onready var _status: Label = %SaveStatus
@onready var _settings_panel: SettingsPanel = %SettingsPanel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.visible = false
	_resume.pressed.connect(set_open.bind(false))
	_save.pressed.connect(_on_save)
	_settings.pressed.connect(_on_settings)
	_settings_panel.closed.connect(_on_settings_closed)
	_main_menu.pressed.connect(_on_main_menu)
	_quit.pressed.connect(_on_quit)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputBindings.PAUSE) and not _settings_panel.visible:
		set_open(not _root.visible)
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _root.visible


func set_open(open: bool) -> void:
	if SceneManager.is_busy():
		return
	_root.visible = open
	_panel.visible = true
	UiKit.pop_in(_panel)
	_status.text = ""
	get_tree().paused = open
	if open:
		_resume.grab_focus()


## Saves to the session slot; a session started without one (debug launch)
## takes the first free slot.
func save_now() -> bool:
	var slot := GameState.current_slot
	if slot <= 0:
		slot = SaveSystem.first_free_slot()
	if slot <= 0:
		_status.text = tr("SAVE_NO_SLOT")
		return false
	var ok := GameState.save_game(slot) == OK
	_status.text = tr("SAVE_DONE") % slot if ok else tr("SAVE_FAILED")
	return ok


func _on_save() -> void:
	if save_now():
		AudioManager.play(&"coin", -6.0)


func _on_settings() -> void:
	_panel.visible = false
	_settings_panel.open()


func _on_settings_closed() -> void:
	_panel.visible = true
	UiKit.pop_in(_panel)
	_settings.grab_focus()


func _on_main_menu() -> void:
	SceneManager.change_scene(MAIN_MENU_SCENE)


func _on_quit() -> void:
	SceneManager.quit_game()
