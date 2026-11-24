extends Node
## Character creation: player name, farm name and outfit colour, with a live
## animated preview of the character.

const FARM_SCENE := "res://scenes/farm/farm.tscn"
const MENU_SCENE := "res://scenes/main/main_menu.tscn"
const SHEET := preload("res://assets/characters/player_sheet.png")
const FRAME := Vector2i(16, 24)
const PREVIEW_FPS := 6.0
const TURN_SECONDS := 2.2
## [sheet row, flip_h] — down, right, up, left
const PREVIEW_FACINGS := [[0, false], [2, false], [1, false], [2, true]]

var _outfit := 0
var _anim_time := 0.0
var _frame_atlas: AtlasTexture
var _outfit_buttons: Array[Button] = []

@onready var _name_edit: LineEdit = %NameEdit
@onready var _farm_edit: LineEdit = %FarmEdit
@onready var _outfit_grid: GridContainer = %OutfitGrid
@onready var _preview: TextureRect = %Preview
@onready var _error: Label = %ErrorLabel
@onready var _start: Button = %StartButton
@onready var _back: Button = %BackButton


func _ready() -> void:
	AudioManager.play_music("title")
	AudioManager.play_ambience("")
	_frame_atlas = AtlasTexture.new()
	_frame_atlas.atlas = SHEET
	_frame_atlas.region = Rect2(Vector2.ZERO, FRAME)
	_preview.texture = _frame_atlas
	_build_outfit_buttons()
	_name_edit.max_length = ProfileRules.NAME_MAX_LENGTH
	_farm_edit.max_length = ProfileRules.NAME_MAX_LENGTH
	if GameState.has_profile():
		_name_edit.text = GameState.player_name
		_farm_edit.text = GameState.farm_name
	_select_outfit(GameState.outfit_index)
	_name_edit.text_submitted.connect(func(_t: String) -> void: _farm_edit.grab_focus())
	_farm_edit.text_submitted.connect(func(_t: String) -> void: _try_start())
	_name_edit.text_changed.connect(func(_t: String) -> void: _error.text = "")
	_farm_edit.text_changed.connect(func(_t: String) -> void: _error.text = "")
	_start.pressed.connect(_try_start)
	_back.pressed.connect(SceneManager.change_scene.bind(MENU_SCENE))
	_error.text = ""
	_name_edit.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		SceneManager.change_scene(MENU_SCENE)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_anim_time += delta
	var facing: Array = PREVIEW_FACINGS[int(_anim_time / TURN_SECONDS) % PREVIEW_FACINGS.size()]
	var seq := CharacterSpriteFrames.WALK_SEQUENCE
	var col: int = seq[int(_anim_time * PREVIEW_FPS) % seq.size()]
	_frame_atlas.region = Rect2(col * FRAME.x, int(facing[0]) * FRAME.y, FRAME.x, FRAME.y)
	_preview.flip_h = facing[1]


func _build_outfit_buttons() -> void:
	var group := ButtonGroup.new()
	for i in OutfitPalette.count():
		var data := OutfitPalette.outfit(i)
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.text = data.get("name_key", "")
		button.icon = _swatch(Color(data.get("main", "ffffff")))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_select_outfit.bind(i))
		_outfit_grid.add_child(button)
		_outfit_buttons.append(button)


func _swatch(color: Color) -> ImageTexture:
	var img := Image.create_empty(9, 9, false, Image.FORMAT_RGBA8)
	img.fill(Color("5b3a4f"))
	img.fill_rect(Rect2i(1, 1, 7, 7), color)
	img.fill_rect(Rect2i(2, 2, 2, 2), color.lightened(0.3))
	return ImageTexture.create_from_image(img)


func _select_outfit(index: int) -> void:
	_outfit = clampi(index, 0, maxi(OutfitPalette.count() - 1, 0))
	_preview.material = OutfitPalette.make_material(_outfit)
	if _outfit < _outfit_buttons.size():
		_outfit_buttons[_outfit].set_pressed_no_signal(true)


func _try_start() -> void:
	var name_error := ProfileRules.validate_name(_name_edit.text)
	if name_error != ProfileRules.NameError.NONE:
		_error.text = tr(ProfileRules.error_key(name_error))
		_name_edit.grab_focus()
		return
	var farm_error := ProfileRules.validate_name(_farm_edit.text)
	if farm_error != ProfileRules.NameError.NONE:
		_error.text = tr("ERR_FARM_PREFIX") + tr(ProfileRules.error_key(farm_error))
		_farm_edit.grab_focus()
		return
	var slot := SaveSystem.first_free_slot()
	if slot == -1:
		_error.text = tr("ERR_NO_FREE_SLOT")
		return
	if GameState.start_new_profile(_name_edit.text, _farm_edit.text, _outfit):
		_start.disabled = true
		GameState.save_game(slot)
		SceneManager.change_scene(FARM_SCENE)
