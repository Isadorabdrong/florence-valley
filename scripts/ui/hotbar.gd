class_name Hotbar
extends VBoxContainer
## The 12-slot hotbar at the bottom of the screen, bound to GameState.

const NAME_HOLD := 1.4

@onready var _grid: SlotGridView = %Grid
@onready var _name_label: Label = %ItemName

var _name_tween: Tween


func _ready() -> void:
	_grid.columns = GameState.HOTBAR_SIZE
	_grid.custom_minimum_size = _grid.grid_size()
	_grid.bind(GameState.inventory)
	_grid.meter_for = _meter_for
	_grid.slot_pressed.connect(GameState.select_slot)
	GameState.selected_slot_changed.connect(_on_selected)
	GameState.tool_state_changed.connect(_grid.queue_redraw)
	GameState.inventory.changed.connect(_on_inventory_changed)
	_name_label.modulate.a = 0.0
	_grid.selected_index = GameState.selected_slot


func _meter_for(id: StringName) -> float:
	if id == &"watering_can" or id == &"watering_can_copper":
		return float(GameState.watering_can_charges) / float(GameState.can_capacity())
	return -1.0


func _on_inventory_changed(index: int) -> void:
	if index == GameState.selected_slot or index == -1:
		_show_name()


func _on_selected(index: int) -> void:
	_grid.selected_index = index
	_grid.queue_redraw()
	_show_name()


func _show_name() -> void:
	var item := GameState.selected_item()
	_name_label.text = item.display_name() if item else ""
	if _name_tween:
		_name_tween.kill()
	_name_label.modulate.a = 1.0
	_name_tween = create_tween()
	_name_tween.tween_interval(NAME_HOLD)
	_name_tween.tween_property(_name_label, "modulate:a", 0.0, 0.5)
