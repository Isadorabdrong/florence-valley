class_name MapLayout
extends RefCounted
## Parsed, validated map layout: a grid of characters plus a legend that maps
## each character to a terrain type or an object scene.
## Pure data — no nodes — so it is fully unit-testable.

const NORTH := 1
const EAST := 2
const SOUTH := 4
const WEST := 8
const _DIRS := [
	[Vector2i(0, -1), NORTH], [Vector2i(1, 0), EAST],
	[Vector2i(0, 1), SOUTH], [Vector2i(-1, 0), WEST],
]

var width := 0
var height := 0
var rows: PackedStringArray = PackedStringArray()
var terrain_chars: Dictionary = {}
var object_chars: Dictionary = {}
var default_terrain := "grass"
var spawn_char := "P"
var spawn_cell := Vector2i(-1, -1)
var warnings: PackedStringArray = PackedStringArray()


## Returns null when the text has no rows.
static func parse(text: String, legend: Dictionary) -> MapLayout:
	var lines := text.replace("\r", "").split("\n")
	while lines.size() > 0 and lines[lines.size() - 1].strip_edges().is_empty():
		lines.remove_at(lines.size() - 1)
	if lines.is_empty():
		return null

	var layout := MapLayout.new()
	layout.terrain_chars = legend.get("terrain", {})
	layout.object_chars = legend.get("objects", {})
	layout.default_terrain = legend.get("default_terrain", "grass")
	layout.spawn_char = legend.get("spawn", "P")
	var pad: String = legend.get("pad_char", ".")

	for line in lines:
		layout.width = maxi(layout.width, line.length())
	layout.height = lines.size()

	for y in lines.size():
		var line := lines[y]
		if line.length() < layout.width:
			layout.warnings.append("row %d padded from %d to %d columns" % [y, line.length(), layout.width])
			line = line + pad.repeat(layout.width - line.length())
		for x in line.length():
			var ch := line[x]
			if ch == layout.spawn_char:
				if layout.spawn_cell.x >= 0:
					layout.warnings.append("duplicate spawn at (%d, %d) ignored" % [x, y])
				else:
					layout.spawn_cell = Vector2i(x, y)
			elif not layout.terrain_chars.has(ch) and not layout.object_chars.has(ch):
				layout.warnings.append("unknown char '%s' at (%d, %d) treated as %s" % [ch, x, y, layout.default_terrain])
		layout.rows.append(line)

	if layout.spawn_cell.x < 0:
		layout.spawn_cell = Vector2i(layout.width / 2, layout.height / 2)
		layout.warnings.append("no spawn '%s' found; using map centre" % layout.spawn_char)
	return layout


static func load_from_files(layout_path: String, legend_path: String) -> MapLayout:
	var legend_text := _read_text(legend_path)
	var layout_text := _read_text(layout_path)
	if legend_text.is_empty() or layout_text.is_empty():
		return null
	var legend: Variant = JSON.parse_string(legend_text)
	if typeof(legend) != TYPE_DICTIONARY:
		push_error("MapLayout: invalid legend JSON in %s" % legend_path)
		return null
	return parse(layout_text, legend)


static func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("MapLayout: cannot open %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return ""
	return file.get_as_text()


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func char_at(cell: Vector2i) -> String:
	if not in_bounds(cell):
		return ""
	return rows[cell.y][cell.x]


## Terrain under a cell. Object and spawn cells take the most common terrain
## of their 4 neighbours (never water), so a rock on the field sits on soil
## and the spawn point on a path stays a path. Falls back to default_terrain.
func terrain_at(cell: Vector2i) -> String:
	var raw := _raw_terrain(cell)
	if not raw.is_empty():
		return raw
	var counts: Dictionary = {}
	var best := default_terrain
	var best_count := 0
	for d: Array in _DIRS:
		var t := _raw_terrain(cell + d[0])
		if t.is_empty() or TerrainAtlas.is_solid(t):
			continue
		counts[t] = int(counts.get(t, 0)) + 1
		# On a tie, a specific terrain (path, soil…) beats the default, so
		# objects placed inside a run continue it instead of breaking it.
		if counts[t] > best_count or (counts[t] == best_count and best == default_terrain):
			best = t
			best_count = counts[t]
	return best


## Terrain for cells whose character is a terrain char; "" otherwise.
func _raw_terrain(cell: Vector2i) -> String:
	return terrain_chars.get(char_at(cell), "")


## Scene path for the object in this cell, or "" if none.
func object_at(cell: Vector2i) -> String:
	return object_chars.get(char_at(cell), "")


## Bitmask of neighbours with the same terrain. Off-map counts as connected,
## so terrain running into the map edge does not draw a border.
func terrain_mask(cell: Vector2i) -> int:
	var mine := terrain_at(cell)
	var mask := 0
	for d: Array in _DIRS:
		var n: Vector2i = cell + d[0]
		if not in_bounds(n) or terrain_at(n) == mine:
			mask |= d[1]
	return mask


## Bitmask of neighbours with the exact same character (e.g. fence runs).
## Off-map never connects.
func char_mask(cell: Vector2i) -> int:
	var mine := char_at(cell)
	var mask := 0
	for d: Array in _DIRS:
		if char_at(cell + d[0]) == mine:
			mask |= d[1]
	return mask


func count_char(ch: String) -> int:
	var total := 0
	for row in rows:
		total += row.count(ch)
	return total
