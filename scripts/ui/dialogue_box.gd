class_name DialogueBox
extends Control
## Bottom-of-screen conversation box: portrait, name, hearts, typewriter
## text, multiple pages and optional choices.
## `var choice: int = await box.play(npc_id, pages, choices)`
## Returns the chosen index, 0 when there were no choices, -1 if cancelled.

signal finished(choice: int)

const CHARS_PER_SECOND := 55.0

var _pages: Array = []
var _choices: Array = []
var _page := 0
var _tween: Tween

@onready var _portrait: TextureRect = %Portrait
@onready var _name: Label = %SpeakerName
@onready var _hearts: Label = %SpeakerHearts
@onready var _text: Label = %DialogueText
@onready var _choice_row: HBoxContainer = %ChoiceRow
@onready var _more: Label = %MoreHint


func _ready() -> void:
	visible = false


func play(npc_id: String, pages: Array, choices: Array = []) -> int:
	var path := "res://assets/characters/portraits/%s.png" % npc_id
	_portrait.texture = load(path) if ResourceLoader.exists(path) else null
	_name.text = Villagers.display_name(npc_id)
	_hearts.text = "♥".repeat(GameState.relationships.hearts(npc_id)) + "♡".repeat(maxi(10 - GameState.relationships.hearts(npc_id), 0))
	_pages = pages if not pages.is_empty() else [""]
	_choices = choices
	_page = 0
	visible = true
	UiKit.pop_in(self)
	_show_page()
	var choice: int = await finished
	return choice


func is_typing() -> bool:
	return _tween != null and _tween.is_running()


func _show_page() -> void:
	UiKit.clear(_choice_row)
	_choice_row.visible = false
	_text.text = str(_pages[_page])
	_text.visible_ratio = 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_text, "visible_ratio", 1.0, maxf(_text.text.length() / CHARS_PER_SECOND, 0.05))
	_tween.finished.connect(_on_page_shown)
	_more.visible = false


func _on_page_shown() -> void:
	var last := _page == _pages.size() - 1
	_more.visible = not last or _choices.is_empty()
	if last and not _choices.is_empty():
		_choice_row.visible = true
		for i in _choices.size():
			var b := UiKit.button(str(_choices[i]), _finish.bind(i), true, 10)
			_choice_row.add_child(b)
		(_choice_row.get_child(0) as Button).grab_focus()


## Advances: completes the typing, turns the page or closes.
func advance() -> void:
	if not visible:
		return
	if is_typing():
		_tween.kill()
		_text.visible_ratio = 1.0
		_on_page_shown()
		return
	if _page < _pages.size() - 1:
		_page += 1
		_show_page()
	elif _choices.is_empty():
		_finish(0)


func _finish(choice: int) -> void:
	if not visible:
		return
	visible = false
	finished.emit(choice)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(InputBindings.PAUSE):
		_finish(-1)
		get_viewport().set_input_as_handled()
	elif (event.is_action_pressed(InputBindings.INTERACT) or event.is_action_pressed(InputBindings.USE_ITEM)) \
			and not _choice_row.visible:
		advance()
		get_viewport().set_input_as_handled()
