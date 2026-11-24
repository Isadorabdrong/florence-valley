class_name InventoryPanel
extends Control
## Inventory window (Tab / I), also used for chests.
##  • drag a stack onto another slot (or between chest and backpack) to move,
##    merge or swap it; click one slot then another does the same
##  • right-click splits a stack in half
##  • drop on the bin to discard (click the bin to undo)

signal closed

var _chest: Inventory = null

@onready var _title: Label = %Title
@onready var _chest_section: Control = %ChestSection
@onready var _chest_grid: SlotGridView = %ChestGrid
@onready var _grid: SlotGridView = %Grid
@onready var _trash: TrashSlot = %Trash
@onready var _icon: TextureRect = %DetailIcon
@onready var _name: Label = %DetailName
@onready var _category: Label = %DetailCategory
@onready var _description: Label = %DetailDescription
@onready var _value: Label = %DetailValue
@onready var _feedback: Label = %Feedback


func _ready() -> void:
	visible = false
	_grid.rows = GameState.inventory.size() / _grid.columns
	_grid.custom_minimum_size = _grid.grid_size()
	_grid.drag_enabled = true
	_grid.bind(GameState.inventory)
	_chest_grid.rows = GameState.CHEST_SIZE / _chest_grid.columns
	_chest_grid.custom_minimum_size = _chest_grid.grid_size()
	_chest_grid.drag_enabled = true
	for grid: SlotGridView in [_grid, _chest_grid]:
		grid.slot_pressed.connect(_on_slot_pressed.bind(grid))
		grid.slot_hovered.connect(_on_slot_hovered.bind(grid))
		grid.slot_dropped.connect(func(_i: int) -> void: AudioManager.play(&"pickup", -6.0))
		grid.slot_split.connect(func(_a: int, _b: int) -> void: AudioManager.play(&"pickup", -6.0))
	_trash.discarded.connect(_on_discarded)
	_trash.restored.connect(func(id: StringName, count: int) -> void:
		_say(tr("INV_RESTORED") % [count, ItemRegistry.item(id).display_name()]))
	_trash.rejected.connect(func() -> void: _say(tr("INV_CANT_DISCARD_TOOL"), true))


## Opens the backpack, optionally next to a chest's contents.
func open(chest: Inventory = null) -> void:
	_chest = chest
	_chest_section.visible = chest != null
	if chest:
		_chest_grid.bind(chest)
	_title.text = tr("INV_TITLE")
	_grid.marked_index = -1
	_chest_grid.marked_index = -1
	_grid.selected_index = GameState.selected_slot
	_trash.clear_memory()
	_feedback.text = ""
	_show_detail(GameState.inventory, GameState.selected_slot)
	visible = true
	UiKit.pop_in(self)
	AudioManager.play(&"open", -6.0)


func close() -> void:
	if not visible:
		return
	visible = false
	_grid.marked_index = -1
	_chest_grid.marked_index = -1
	_trash.clear_memory()
	_chest = null
	closed.emit()


func is_chest_open() -> bool:
	return visible and _chest != null


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(InputBindings.INVENTORY) or event.is_action_pressed(InputBindings.PAUSE) \
			or event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(InputBindings.INTERACT):
		close()
		get_viewport().set_input_as_handled()


func _on_slot_pressed(index: int, grid: SlotGridView) -> void:
	var inv := grid.inventory
	if grid.marked_index == -1:
		if not inv.is_slot_empty(index):
			grid.marked_index = index
	else:
		inv.move_slot(grid.marked_index, index)
		grid.marked_index = -1
	grid.queue_redraw()
	_show_detail(inv, index)


func _on_slot_hovered(index: int, grid: SlotGridView) -> void:
	if index >= 0:
		_show_detail(grid.inventory, index)


func _on_discarded(id: StringName, count: int) -> void:
	_say(tr("INV_DISCARDED") % [count, ItemRegistry.item(id).display_name()])


func _say(text: String, warn: bool = false) -> void:
	_feedback.text = text
	_feedback.add_theme_color_override(&"font_color", Color("b0465f") if warn else Color("6a7f4e"))


func _show_detail(inv: Inventory, index: int) -> void:
	var id := inv.item_at(index)
	var item := ItemRegistry.item(id) if id != &"" else null
	if item == null:
		_icon.texture = null
		_name.text = ""
		_category.text = ""
		_description.text = tr("INV_EMPTY_SLOT")
		_value.text = ""
		return
	_icon.texture = ItemRegistry.icon(id)
	_name.text = item.display_name()
	_category.text = tr(ItemData.CATEGORY_KEYS[item.category])
	_description.text = ItemRegistry.describe(id)
	_value.text = tr("INV_VALUE") % item.sell_price if item.sell_price > 0 else ""
