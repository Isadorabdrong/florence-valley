class_name SoilView
extends Node
## Draws a SoilGrid: tilled/wet tiles and fertiliser specks on TileMapLayers,
## and one y-sorted Sprite2D per crop. Listens to SoilGrid.cell_changed, so
## any change to the data shows up immediately.

const CROP_ATLAS := preload("res://assets/flowers/flower_atlas.png")
const SWAY_MATERIAL := preload("res://resources/materials/crop_sway.tres")
const FRAME := Vector2i(16, 32)
const WITHERED_COLUMN := 6
const SOURCE_ID := 0
const DRY_ROW := 0
const WET_ROW := 1
const FERTILIZER_COORDS := Vector2i(0, 2)
## Plants sit slightly above the bottom edge of their tile.
const CROP_BASE_OFFSET := Vector2(0, -2)

var soil: SoilGrid
var _soil_layer: TileMapLayer
var _decor_layer: TileMapLayer
var _crop_parent: Node2D
var _sprites: Dictionary = {} # Vector2i -> Sprite2D
var _stages: Dictionary = {} # Vector2i -> int (last drawn frame, for pop animation)


func setup(soil_grid: SoilGrid, soil_layer: TileMapLayer, decor_layer: TileMapLayer, crop_parent: Node2D) -> void:
	soil = soil_grid
	_soil_layer = soil_layer
	_decor_layer = decor_layer
	_crop_parent = crop_parent
	soil.cell_changed.connect(_on_cell_changed)
	refresh_all()


func _exit_tree() -> void:
	# The SoilGrid outlives this scene (it lives in GameState).
	if soil and soil.cell_changed.is_connected(_on_cell_changed):
		soil.cell_changed.disconnect(_on_cell_changed)


func refresh_all() -> void:
	_soil_layer.clear()
	_decor_layer.clear()
	for sprite: Sprite2D in _sprites.values():
		sprite.queue_free()
	_sprites.clear()
	_stages.clear()
	for cell in soil.tilled_cells():
		_paint(cell)
		_update_crop(cell, false)


func crop_sprite_at(cell: Vector2i) -> Sprite2D:
	return _sprites.get(cell)


func _on_cell_changed(cell: Vector2i) -> void:
	_paint(cell)
	for offset: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		_paint(cell + offset)
	_update_crop(cell, true)


func _paint(cell: Vector2i) -> void:
	if not soil.is_tilled(cell):
		_soil_layer.erase_cell(cell)
		_decor_layer.erase_cell(cell)
		return
	var mask := 0
	if soil.is_tilled(cell + Vector2i.UP):
		mask |= MapLayout.NORTH
	if soil.is_tilled(cell + Vector2i.RIGHT):
		mask |= MapLayout.EAST
	if soil.is_tilled(cell + Vector2i.DOWN):
		mask |= MapLayout.SOUTH
	if soil.is_tilled(cell + Vector2i.LEFT):
		mask |= MapLayout.WEST
	var row := WET_ROW if soil.is_watered(cell) else DRY_ROW
	_soil_layer.set_cell(cell, SOURCE_ID, Vector2i(mask, row))
	if soil.is_fertilized(cell):
		_decor_layer.set_cell(cell, SOURCE_ID, FERTILIZER_COORDS)
	else:
		_decor_layer.erase_cell(cell)


func _update_crop(cell: Vector2i, animate: bool) -> void:
	var crop := soil.get_crop(cell)
	if crop == null:
		if _sprites.has(cell):
			(_sprites[cell] as Sprite2D).queue_free()
			_sprites.erase(cell)
			_stages.erase(cell)
		return
	var fl := ItemRegistry.flower(crop.flower_id)
	if fl == null:
		return
	var sprite: Sprite2D = _sprites.get(cell)
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.texture = CROP_ATLAS
		sprite.centered = false
		sprite.offset = Vector2(-FRAME.x / 2.0, -FRAME.y)
		sprite.region_enabled = true
		sprite.position = Vector2(cell.x * 16 + 8, (cell.y + 1) * 16) + CROP_BASE_OFFSET
		_crop_parent.add_child(sprite)
		_sprites[cell] = sprite
	var column := WITHERED_COLUMN if crop.withered else crop.stage
	sprite.region_rect = Rect2(column * FRAME.x, fl.atlas_row * FRAME.y, FRAME.x, FRAME.y)
	sprite.material = SWAY_MATERIAL if (column >= FlowerData.STAGE_YOUNG and not crop.withered) else null
	if animate and _stages.get(cell, -1) != column:
		FarmEffects.pop(sprite)
	_stages[cell] = column
