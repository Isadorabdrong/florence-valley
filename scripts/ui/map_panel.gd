class_name MapPanel
extends Control
## World map window (M).

signal closed

@onready var _graph: MapGraphView = %Graph
@onready var _summary: Label = %MapSummary
@onready var _close: Button = %CloseMap


func _ready() -> void:
	visible = false
	_close.pressed.connect(close)


func open(current_map: StringName) -> void:
	_graph.current_map = current_map
	_graph.queue_redraw()
	var total := WorldGraph.landmarks().size()
	var visited := 0
	for id in WorldGraph.map_ids():
		if WorldGraph.is_outdoor(id) and GameState.visited_maps.has(String(id)):
			visited += 1
	var outdoor := WorldGraph.map_ids().filter(func(id: StringName) -> bool: return WorldGraph.is_outdoor(id)).size()
	_summary.text = tr("MAP_SUMMARY") % [visited, outdoor, GameState.discoveries.size(), total]
	visible = true
	UiKit.pop_in(self)
	_close.grab_focus()
	AudioManager.play(&"open", -6.0)


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(InputBindings.PAUSE) \
			or event.is_action_pressed(InputBindings.MAP)):
		close()
		get_viewport().set_input_as_handled()
