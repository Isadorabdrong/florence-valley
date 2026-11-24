class_name TerrainAtlas
extends RefCounted
## Maps terrain types to tiles in assets/environments/terrain_atlas.png.
## See tools/generate_assets.gd and tools/art/terrain_art.gd for the layout.

const SOURCE_ID := 0
const GRASS_VARIANTS := 4
const WATER := "water"
## Terrains drawn with 16 neighbour-mask variants (column = mask).
const MASKED_ROWS := {"path": 1, "water": 2, "soil": 3, "cobble": 4, "sand": 5, "cliff": 6}
## Terrains with 4 random variants: first cell of the run.
const VARIANT_BASE := {
	"grass": Vector2i(0, 0), "grass_flowers": Vector2i(4, 0),
	"forest": Vector2i(0, 7), "lavender": Vector2i(4, 7), "meadow": Vector2i(8, 7), "grove": Vector2i(12, 7),
	"wood": Vector2i(0, 8), "rug": Vector2i(4, 8),
}
const WALL_FACE := Vector2i(8, 8)
const WALL_TOP := Vector2i(9, 8)
const DOORMAT := Vector2i(10, 8)
## Terrains that block movement (collision lives in the TileSet).
const SOLID: Array[String] = ["water", "cliff", "wall"]


static func uses_mask(terrain: String) -> bool:
	return MASKED_ROWS.has(terrain) or terrain == "wall"


static func is_water(terrain: String) -> bool:
	return terrain == WATER


static func is_solid(terrain: String) -> bool:
	return SOLID.has(terrain)


static func coords_for(terrain: String, mask: int, cell: Vector2i) -> Vector2i:
	if MASKED_ROWS.has(terrain):
		return Vector2i(clampi(mask, 0, 15), MASKED_ROWS[terrain])
	if terrain == "wall":
		# Wall continuing south = top of the wall; otherwise its visible face.
		return WALL_TOP if (mask & MapLayout.SOUTH) != 0 else WALL_FACE
	if terrain == "doormat":
		return DOORMAT
	var base: Vector2i = VARIANT_BASE.get(terrain, VARIANT_BASE["grass"])
	return base + Vector2i(variant(cell), 0)


## Stable pseudo-random variant per cell, so grass looks natural but the map
## is identical every time it loads.
static func variant(cell: Vector2i) -> int:
	var h: int = (cell.x * 73856093) ^ (cell.y * 19349663)
	return absi(h) % GRASS_VARIANTS
