class_name SlotGridView
extends Control
## Draws a block of inventory slots (icons, stack counts, optional key hints
## and tool meters) and reports clicks/hover. Used by the hotbar and the
## inventory panel.

signal slot_pressed(index: int)
signal slot_hovered(index: int) ## -1 when the mouse leaves
signal slot_split(index: int, new_index: int)
signal slot_dropped(index: int)

const DRAG_TYPE := "fv_slot"

## Allow dragging stacks out of / into this grid.
@export var drag_enabled := false

const KEY_HINTS: Array[String] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "="]
const ICON_SIZE := 16

@export var columns := 12
@export var rows := 1
@export var first_index := 0
@export var slot_size := 22
@export var gap := 2
@export var show_key_hints := false

var inventory: Inventory
var selected_index := -1
var marked_index := -1
## (StringName) -> float in [0, 1], or -1 for no meter.
var meter_for: Callable

var _hover := -1
var _styles: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = grid_size()
	_styles = {
		&"normal": _box(Color("f6e7d4"), Color("b08a68"), 1),
		&"hover": _box(Color("fbf1e4"), Color("d0809f"), 1),
		&"selected": _box(Color("fde3ea"), Color("e07a9a"), 2),
		&"marked": _box(Color("e6f0d8"), Color("6aa35a"), 2),
	}
	mouse_exited.connect(_set_hover.bind(-1))


func bind(inv: Inventory) -> void:
	if inventory and inventory.changed.is_connected(_on_inventory_changed):
		inventory.changed.disconnect(_on_inventory_changed)
	inventory = inv
	inventory.changed.connect(_on_inventory_changed)
	queue_redraw()


func _exit_tree() -> void:
	if inventory and inventory.changed.is_connected(_on_inventory_changed):
		inventory.changed.disconnect(_on_inventory_changed)


func grid_size() -> Vector2:
	return Vector2(columns * slot_size + (columns - 1) * gap, rows * slot_size + (rows - 1) * gap)


func slot_rect(local_index: int) -> Rect2:
	var c := local_index % columns
	var r := local_index / columns
	return Rect2(c * (slot_size + gap), r * (slot_size + gap), slot_size, slot_size)


## Absolute inventory index under a local position, or -1.
func index_at(pos: Vector2) -> int:
	for i in columns * rows:
		if slot_rect(i).has_point(pos):
			return first_index + i
	return -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_set_hover(index_at(event.position))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := index_at(event.position)
		if i >= 0:
			slot_pressed.emit(i)
			accept_event()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT \
			and drag_enabled and inventory:
		var i := index_at(event.position)
		if i >= 0:
			var new_index := inventory.split_slot(i)
			if new_index >= 0:
				slot_split.emit(i, new_index)
			accept_event()


func _get_drag_data(at_position: Vector2) -> Variant:
	if not drag_enabled or inventory == null:
		return null
	var i := index_at(at_position)
	if i < 0 or inventory.is_slot_empty(i):
		return null
	var preview := TextureRect.new()
	preview.texture = ItemRegistry.icon(inventory.item_at(i))
	preview.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	preview.modulate.a = 0.85
	set_drag_preview(preview)
	return {"type": DRAG_TYPE, "inventory": inventory, "index": i}


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return drag_enabled and inventory != null and is_slot_drag(data) and index_at(at_position) >= 0


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var to := index_at(at_position)
	if Inventory.transfer(data["inventory"], data["index"], inventory, to):
		marked_index = -1
		slot_dropped.emit(to)
		queue_redraw()


static func is_slot_drag(data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.get("type") == DRAG_TYPE


func _set_hover(index: int) -> void:
	if index == _hover:
		return
	_hover = index
	slot_hovered.emit(index)
	queue_redraw()


func _on_inventory_changed(_index: int) -> void:
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	for i in columns * rows:
		var index := first_index + i
		var rect := slot_rect(i)
		var style: StyleBox = _styles[&"normal"]
		if index == marked_index:
			style = _styles[&"marked"]
		elif index == selected_index:
			style = _styles[&"selected"]
		elif index == _hover:
			style = _styles[&"hover"]
		draw_style_box(style, rect)
		if show_key_hints and i < KEY_HINTS.size():
			draw_string(font, rect.position + Vector2(2, 7), KEY_HINTS[i], HORIZONTAL_ALIGNMENT_LEFT,
				-1, 6, Color("9c5f7e", 0.8))
		if inventory == null:
			continue
		var slot := inventory.get_slot(index)
		if slot.is_empty():
			continue
		var icon := ItemRegistry.icon(slot["id"])
		if icon:
			var offset := (rect.size - Vector2(ICON_SIZE, ICON_SIZE)) / 2.0
			draw_texture(icon, (rect.position + offset).floor())
		var count := int(slot["count"])
		if count > 1:
			var base := rect.position + Vector2(0, rect.size.y - 2)
			draw_string_outline(font, base, str(count), HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 2, 8, 3, Color("3d2b3d"))
			draw_string(font, base, str(count), HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 2, 8, Color("fbf3e3"))
		if meter_for.is_valid():
			var v := float(meter_for.call(slot["id"]))
			if v >= 0.0:
				var bar := Rect2(rect.position + Vector2(3, rect.size.y - 4), Vector2(rect.size.x - 6, 2))
				draw_rect(bar, Color("3d2b3d", 0.6))
				draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(v, 0, 1), bar.size.y)), Color("86bcd8"))


static func _box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(3)
	return s
