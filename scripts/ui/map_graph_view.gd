class_name MapGraphView
extends Control
## Draws the valley as a graph of outdoor areas: visited areas show their
## name and discoveries, unvisited ones are "???"; the current area is
## highlighted with a heart.

const NODE_SIZE := Vector2(124, 30)

var current_map: StringName = &""


func _ready() -> void:
	custom_minimum_size = Vector2(470, 230)


func _node_center(map_id: String) -> Vector2:
	var pos: Array = WorldGraph.map_def(StringName(map_id)).get("pos", [0.5, 0.5])
	var area := size - NODE_SIZE
	return NODE_SIZE / 2.0 + Vector2(float(pos[0]) * area.x, float(pos[1]) * area.y)


func _outdoor_ids() -> Array[String]:
	var out: Array[String] = []
	for id in WorldGraph.map_ids():
		if WorldGraph.is_outdoor(id):
			out.append(String(id))
	return out


## The outdoor area a map belongs to (interiors map to their door's area).
static func area_of(map_id: StringName) -> String:
	if WorldGraph.is_outdoor(map_id):
		return String(map_id)
	for e in WorldGraph.exits(map_id):
		return String(e["to"])
	return String(map_id)


func _draw() -> void:
	var font := get_theme_default_font()
	var ids := _outdoor_ids()
	var drawn := {}
	for id in ids:
		for e in WorldGraph.exits(StringName(id)):
			var to := String(e["to"])
			var key := [id, to] if id < to else [to, id]
			if ids.has(to) and not drawn.has(str(key)):
				drawn[str(key)] = true
				var both := GameState.visited_maps.has(id) and GameState.visited_maps.has(to)
				draw_line(_node_center(id), _node_center(to),
					Color("a8774f") if both else Color("a8774f", 0.35), 3.0 if both else 2.0)
	var landmarks := WorldGraph.landmarks()
	var here := area_of(current_map)
	for id in ids:
		var visited := GameState.visited_maps.has(id)
		var rect := Rect2(_node_center(id) - NODE_SIZE / 2.0, NODE_SIZE)
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(6)
		box.set_border_width_all(2)
		box.bg_color = Color("fde3ea") if id == here else (Color("e6f0d8") if visited else Color("e6dfe0"))
		box.border_color = Color("e07a9a") if id == here else (Color("6aa35a") if visited else Color("b8a9ad"))
		draw_style_box(box, rect)
		var name: String = tr(str(WorldGraph.map_def(StringName(id)).get("name_key", ""))) if visited else "???"
		draw_string(font, rect.position + Vector2(0, 13), name, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 8,
			Color("5b3a4f") if visited else Color("9c8f94"))
		var total := 0
		var found := 0
		for lm: String in landmarks:
			if landmarks[lm] == id:
				total += 1
				if GameState.discoveries.has(lm):
					found += 1
		if total > 0 and visited:
			draw_string(font, rect.position + Vector2(0, 25), "✦ %d/%d" % [found, total],
				HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 8, Color("9c5f7e"))
		if id == here:
			var c := rect.position + Vector2(rect.size.x - 4, 2)
			draw_circle(c + Vector2(-2, 0), 3, Color("e07a9a"))
			draw_circle(c + Vector2(2, 0), 3, Color("e07a9a"))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-5, 1), c + Vector2(5, 1), c + Vector2(0, 6)]), Color("e07a9a"))
