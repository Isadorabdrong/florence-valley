class_name SettingsPanel
extends Control
## Settings window (main menu and pause menu). Changes apply immediately and
## are saved to user://settings.cfg when the window closes.

signal closed

const LOCALE_NAMES := {"pt_BR": "Português (Brasil)", "en": "English"}

@onready var _music: HSlider = %MusicSlider
@onready var _sfx: HSlider = %SfxSlider
@onready var _ambient: HSlider = %AmbientSlider
@onready var _fullscreen: CheckButton = %FullscreenCheck
@onready var _language: OptionButton = %LanguageOption
@onready var _close: Button = %CloseSettings


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	for loc in GameSettings.LOCALES:
		_language.add_item(LOCALE_NAMES.get(loc, loc))
	_music.value_changed.connect(_on_music)
	_sfx.value_changed.connect(_on_sfx)
	_ambient.value_changed.connect(_on_ambient)
	_fullscreen.toggled.connect(_on_fullscreen)
	_language.item_selected.connect(_on_language)
	_close.pressed.connect(close)


func open() -> void:
	var s := GameState.settings
	_music.set_value_no_signal(s.music_volume * 100.0)
	_sfx.set_value_no_signal(s.sfx_volume * 100.0)
	_ambient.set_value_no_signal(s.ambient_volume * 100.0)
	_fullscreen.set_pressed_no_signal(s.fullscreen)
	_language.select(maxi(GameSettings.LOCALES.find(s.locale), 0))
	visible = true
	UiKit.pop_in(self)
	_music.grab_focus()


func close() -> void:
	if not visible:
		return
	GameState.save_settings()
	visible = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(InputBindings.PAUSE)):
		close()
		get_viewport().set_input_as_handled()


func _on_music(value: float) -> void:
	GameState.settings.music_volume = value / 100.0
	GameState.settings.apply()


func _on_sfx(value: float) -> void:
	GameState.settings.sfx_volume = value / 100.0
	GameState.settings.apply()
	AudioManager.play(&"click")


func _on_ambient(value: float) -> void:
	GameState.settings.ambient_volume = value / 100.0
	GameState.settings.apply()


func _on_fullscreen(on: bool) -> void:
	GameState.settings.fullscreen = on
	GameState.settings.apply()


func _on_language(index: int) -> void:
	GameState.settings.locale = GameSettings.LOCALES[index]
	GameState.settings.apply()
