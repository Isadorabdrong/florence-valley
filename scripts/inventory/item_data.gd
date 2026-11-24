class_name ItemData
extends Resource
## Definition of an inventory item. Tools and materials are .tres files in
## resources/tools and resources/items; seeds and cut flowers are generated
## from FlowerData by ItemRegistry.

enum Category { TOOL, SEED, FLOWER, MATERIAL, FERTILIZER, FOOD, DECORATION, SPECIAL, BOUQUET }
enum ToolKind { NONE, HOE, WATERING_CAN, SCYTHE, PICKAXE }

const CATEGORY_KEYS: Array[String] = ["CAT_TOOL", "CAT_SEED", "CAT_FLOWER", "CAT_MATERIAL",
	"CAT_FERTILIZER", "CAT_FOOD", "CAT_DECORATION", "CAT_SPECIAL", "CAT_BOUQUET"]

@export var id: StringName = &""
@export var name_key := ""
## Optional format key, e.g. "ITEM_SEEDS_OF" = "Sementes de %s".
@export var name_format_key := ""
@export var description_key := ""
@export var category: Category = Category.MATERIAL
@export var tool_kind: ToolKind = ToolKind.NONE
@export_range(1, 999) var max_stack := 99
@export var sell_price := 0
@export var buy_price := 0
## Cell (column, row) in assets/ui/item_icons.png
@export var icon_coords := Vector2i.ZERO
## For seeds and cut flowers: the FlowerData id.
@export var flower_id: StringName = &""
## Free-form tags used by bouquet recipes and customers ("flower", "wild",
## "romantic", "rare", "decor"…).
@export var tags: PackedStringArray = PackedStringArray()

@export_group("Building")
## Scene placed on the map (fences, benches, trees…), or…
@export_file("*.tscn") var place_scene := ""
## …a floor build drawn on a tile layer: &"path" or &"pond".
@export var place_floor: StringName = &""
## Cells covered, relative to the target cell (position = top-left offset).
@export var footprint := Rect2i(0, 0, 1, 1)
## &"outdoor" (farm), &"indoor" (house, greenhouse) or &"both".
@export var place_where: StringName = &"outdoor"

@export_group("Tools")
## Cells affected in a line in front of the player (upgraded tools).
@export_range(1, 5) var area := 1
## Watering can capacity (0 = default).
@export var capacity := 0


func display_name() -> String:
	var base := TranslationServer.translate(name_key)
	if name_format_key.is_empty():
		return base
	return TranslationServer.translate(name_format_key) % base


func is_tool() -> bool:
	return category == Category.TOOL


func is_placeable() -> bool:
	return not place_scene.is_empty() or place_floor != &""


## Footprint cells for a build placed at `cell`.
func footprint_cells(cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in footprint.size.y:
		for x in footprint.size.x:
			out.append(cell + footprint.position + Vector2i(x, y))
	return out
