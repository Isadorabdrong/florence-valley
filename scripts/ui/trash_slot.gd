class_name TrashSlot
extends Control
## Drop a stack here to discard it. The last discarded stack can be
## recovered by clicking the bin until something else is discarded or the
## window closes. Tools can't be discarded.

signal discarded(item_id: StringName, count: int)
signal restored(item_id: StringName, count: int)
signal rejected

const SIZE := Vector2(22, 22)

var _last: Dictionary = {}


func _ready() -> void:
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = tr("INV_TRASH_TIP")


func clear_memory() -> void:
	_last = {}
	queue_redraw()


func has_restorable() -> bool:
	return not _last.is_empty()


func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	return SlotGridView.is_slot_drag(data)


func _drop_data(_pos: Vector2, data: Variant) -> void:
	var inv: Inventory = data["inventory"]
	var index: int = data["index"]
	var item := ItemRegistry.item(inv.item_at(index))
	if item == null or item.is_tool():
		rejected.emit()
		return
	var slot := inv.take_slot(index)
	_last = {"inventory": inv, "index": index, "id": slot["id"], "count": slot["count"]}
	discarded.emit(slot["id"], slot["count"])
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		restore()
		accept_event()


## Puts the last discarded stack back (original slot if free, else anywhere).
func restore() -> bool:
	if _last.is_empty():
		return false
	var inv: Inventory = _last["inventory"]
	var ok := inv.put_in_slot(_last["index"], _last["id"], _last["count"])
	if not ok:
		var left := inv.add_item(_last["id"], _last["count"])
		if left > 0:
			_last["count"] = left
			return false
	restored.emit(_last["id"], _last["count"])
	_last = {}
	queue_redraw()
	return true


func _draw() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("f3dde2")
	box.border_color = Color("b0465f")
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	draw_style_box(box, Rect2(Vector2.ZERO, SIZE))
	if not _last.is_empty():
		var icon := ItemRegistry.icon(_last["id"])
		if icon:
			draw_texture(icon, Vector2(3, 3), Color(1, 1, 1, 0.55))
		return
	# little bin
	var c := Color("9c5f7e")
	draw_rect(Rect2(6, 8, 10, 10), c, false, 1.0)
	draw_line(Vector2(5, 7), Vector2(17, 7), c, 1.0)
	draw_line(Vector2(9, 5), Vector2(13, 5), c, 1.0)
	for x in [9, 11, 13]:
		draw_line(Vector2(x, 10), Vector2(x, 16), c, 1.0)
