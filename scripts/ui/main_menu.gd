extends Node
## Title screen: Continue, New Game, Load, Settings, Credits, Quit.
## Continue and Load only appear when there is at least one save.

const CREATION_SCENE := "res://scenes/main/character_creation.tscn"
const FARM_SCENE := "res://scenes/farm/farm.tscn"

@onready var _title_group: Control = %TitleGroup
@onready var _menu_box: Control = %MenuBox
@onready var _continue: Button = %ContinueButton
@onready var _new_game: Button = %NewGameButton
@onready var _load: Button = %LoadButton
@onready var _settings: Button = %SettingsButton
@onready var _credits: Button = %CreditsButton
@onready var _quit: Button = %QuitButton
@onready var _credits_panel: Control = %CreditsPanel
@onready var _close_credits: Button = %CloseCreditsButton
@onready var _version: Label = %VersionLabel
@onready var _load_panel: LoadPanel = %LoadPanel
@onready var _settings_panel: SettingsPanel = %SettingsPanel


func _ready() -> void:
	AudioManager.play_music("title")
	AudioManager.play_ambience("")
	_continue.pressed.connect(_on_continue)
	_new_game.pressed.connect(_on_new_game)
	_load.pressed.connect(_open_panel.bind(_load_panel))
	_settings.pressed.connect(_open_panel.bind(_settings_panel))
	_credits.pressed.connect(_set_credits_open.bind(true))
	_close_credits.pressed.connect(_set_credits_open.bind(false))
	_quit.pressed.connect(SceneManager.quit_game)
	_load_panel.load_requested.connect(_load_slot)
	_load_panel.closed.connect(_on_panel_closed)
	_settings_panel.closed.connect(_on_panel_closed)
	if OS.has_feature("web"):
		_quit.hide()
	_version.text = tr("MENU_VERSION") % ProjectSettings.get_setting("application/config/version", "0.0.0")
	_credits_panel.hide()
	_refresh_save_buttons()
	_play_intro()
	(_continue if _continue.visible else _new_game).grab_focus()


func _refresh_save_buttons() -> void:
	var has_save := SaveSystem.most_recent_slot() != -1
	_continue.visible = has_save
	_load.visible = has_save or SaveSystem.list_slots().any(func(e: Dictionary) -> bool: return e["state"] != "empty")


func _unhandled_input(event: InputEvent) -> void:
	if _credits_panel.visible and (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(InputBindings.PAUSE)):
		_set_credits_open(false)
		get_viewport().set_input_as_handled()


func _play_intro() -> void:
	for node: Control in [_title_group, _menu_box]:
		node.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_title_group, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_title_group, "position:y", _title_group.position.y, 1.0) \
		.from(_title_group.position.y - 10.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_menu_box, "modulate:a", 1.0, 0.8).set_delay(0.5)


func _set_credits_open(open: bool) -> void:
	_credits_panel.visible = open
	_menu_box.visible = not open
	if open:
		_close_credits.grab_focus()
	else:
		_credits.grab_focus()


func _open_panel(panel: Control) -> void:
	_menu_box.visible = false
	panel.call(&"open")


func _on_panel_closed() -> void:
	_menu_box.visible = true
	_refresh_save_buttons()
	(_continue if _continue.visible else _new_game).grab_focus()


func _on_new_game() -> void:
	SceneManager.change_scene(CREATION_SCENE)


func _on_continue() -> void:
	var slot := SaveSystem.most_recent_slot()
	if slot != -1:
		_load_slot(slot)


func _load_slot(slot: int) -> void:
	var result := GameState.load_game(slot)
	if result["error"] != SaveSystem.LoadError.NONE:
		if not _load_panel.visible:
			_open_panel(_load_panel)
		_load_panel.show_error(tr(SaveSystem.error_key(result["error"])))
		return
	SceneManager.change_scene(GameState.MAP_SCENE)
