class_name LoadPanel
extends Control
## Lists the save slots with a summary; load or delete each one.

signal load_requested(slot: int)
signal closed

@onready var _slots: VBoxContainer = %SlotList
@onready var _message: Label = %LoadMessage
@onready var _close: Button = %CloseLoad
@onready var _dialog: ConfirmDialog = $ConfirmDialog


func _ready() -> void:
	visible = false
	_close.pressed.connect(close)


func open() -> void:
	_message.text = ""
	_rebuild()
	visible = true
	UiKit.pop_in(self)
	_close.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func show_error(text: String) -> void:
	_message.text = text


func _input(event: InputEvent) -> void:
	if visible and not _dialog.visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _rebuild() -> void:
	for child in _slots.get_children():
		child.queue_free()
	var first_button: Button = null
	for entry in SaveSystem.list_slots():
		var box := PanelContainer.new()
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 8)
		box.add_child(row)
		var info := Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_font_size_override(&"font_size", 9)
		info.text = describe_slot(entry)
		row.add_child(info)
		if entry["state"] == "ok":
			var load_button := Button.new()
			load_button.text = tr("LOAD_BUTTON")
			load_button.pressed.connect(func() -> void: load_requested.emit(entry["slot"]))
			row.add_child(load_button)
			if first_button == null:
				first_button = load_button
		if entry["state"] != "empty":
			var delete_button := Button.new()
			delete_button.text = tr("DELETE_BUTTON")
			delete_button.pressed.connect(_confirm_delete.bind(int(entry["slot"])))
			row.add_child(delete_button)
		_slots.add_child(box)
	if first_button:
		first_button.grab_focus.call_deferred()


static func describe_slot(entry: Dictionary) -> String:
	var title: String = TranslationServer.translate("SLOT_FMT") % entry["slot"]
	match entry["state"]:
		"empty":
			return "%s — %s" % [title, TranslationServer.translate("SLOT_EMPTY")]
		"corrupt":
			return "%s — %s" % [title, TranslationServer.translate("SLOT_CORRUPT")]
	var s: Dictionary = entry["summary"]
	var minutes := int(s.get("playtime", 0)) / 60
	var line1: String = "%s — %s · %s" % [title, s.get("player", "?"),
		TranslationServer.translate("LOCATION_FARM") % s.get("farm", "?")]
	var line2: String = TranslationServer.translate("SLOT_DETAILS") % [int(s.get("day", 1)),
		TranslationServer.translate(Calendar.SEASON_KEYS[clampi(int(s.get("season", 0)), 0, 3)]),
		int(s.get("year", 1)), Wallet.format(int(s.get("money", 0))), minutes / 60, minutes % 60]
	if entry.get("from_backup", false):
		line2 += "  " + TranslationServer.translate("SLOT_FROM_BACKUP")
	return line1 + "\n" + line2


func _confirm_delete(slot: int) -> void:
	var yes: bool = await _dialog.ask(tr("DELETE_QUESTION") % slot)
	if yes:
		SaveSystem.delete(slot)
		_message.text = tr("SLOT_DELETED") % slot
		_rebuild()
