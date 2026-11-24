class_name SoilGrid
extends RefCounted
## State of every tilled cell on a farm map and the growth simulation.
## Pure data + rules (no nodes): SoilView draws it, FarmController edits it,
## and the save system (Phase 3) serialises it with to_dict()/load_dict().

signal cell_changed(cell: Vector2i)

enum PlantError { NONE, NOT_TILLED, OCCUPIED, OUT_OF_SEASON, UNKNOWN_FLOWER, NEEDS_GREENHOUSE }

const FERTILIZER_BONUS := 0.25
const LOVES_WATER_BONUS := 0.5
const WATER_RADIUS := 2


class Crop:
	var flower_id: StringName
	var stage := 0
	var growth := 0.0
	var days_dry := 0
	var withered := false


class SoilCell:
	var watered := false
	var fertilized := false
	var crop: Crop = null


var _cells: Dictionary = {} # Vector2i -> SoilCell
## Cells containing open water (for LOVES_WATER); set by the map on load.
var water_cells: Dictionary = {}
## Greenhouse soil: every flower grows in every season, and
## GREENHOUSE_ONLY flowers may be planted.
var all_seasons := false
## (StringName) -> FlowerData. Unset = ItemRegistry.flower; tests may inject.
var flower_lookup: Callable


func _flower(id: StringName) -> FlowerData:
	if flower_lookup.is_valid():
		return flower_lookup.call(id)
	return ItemRegistry.flower(id)


func clear() -> void:
	var old := _cells.keys()
	_cells.clear()
	for cell: Vector2i in old:
		cell_changed.emit(cell)


func tilled_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in _cells:
		out.append(cell)
	return out


func is_tilled(cell: Vector2i) -> bool:
	return _cells.has(cell)


func is_watered(cell: Vector2i) -> bool:
	return _cells.has(cell) and (_cells[cell] as SoilCell).watered


func is_fertilized(cell: Vector2i) -> bool:
	return _cells.has(cell) and (_cells[cell] as SoilCell).fertilized


func get_crop(cell: Vector2i) -> Crop:
	return (_cells[cell] as SoilCell).crop if _cells.has(cell) else null


func has_crop(cell: Vector2i) -> bool:
	return get_crop(cell) != null


func is_harvestable(cell: Vector2i) -> bool:
	var crop := get_crop(cell)
	return crop != null and not crop.withered and crop.stage == FlowerData.STAGE_BLOOM


func is_withered(cell: Vector2i) -> bool:
	var crop := get_crop(cell)
	return crop != null and crop.withered


func till(cell: Vector2i) -> bool:
	if _cells.has(cell):
		return false
	_cells[cell] = SoilCell.new()
	cell_changed.emit(cell)
	return true


## Returns tilled soil to its natural state. Only possible without a crop.
func untill(cell: Vector2i) -> bool:
	if not _cells.has(cell) or has_crop(cell):
		return false
	_cells.erase(cell)
	cell_changed.emit(cell)
	return true


func water(cell: Vector2i) -> bool:
	if not _cells.has(cell) or is_watered(cell):
		return false
	(_cells[cell] as SoilCell).watered = true
	cell_changed.emit(cell)
	return true


## Waters every tilled cell (rainy days). Returns how many changed.
func water_all() -> int:
	var count := 0
	for cell: Vector2i in _cells:
		if water(cell):
			count += 1
	return count


func fertilize(cell: Vector2i) -> bool:
	if not _cells.has(cell) or is_fertilized(cell):
		return false
	(_cells[cell] as SoilCell).fertilized = true
	cell_changed.emit(cell)
	return true


func can_plant(cell: Vector2i, flower_id: StringName, season: int) -> PlantError:
	var fl: FlowerData = _flower(flower_id)
	if fl == null:
		return PlantError.UNKNOWN_FLOWER
	if not _cells.has(cell):
		return PlantError.NOT_TILLED
	if has_crop(cell):
		return PlantError.OCCUPIED
	if fl.special == FlowerData.Special.GREENHOUSE_ONLY and not all_seasons:
		return PlantError.NEEDS_GREENHOUSE
	if not all_seasons and not fl.grows_in(season):
		return PlantError.OUT_OF_SEASON
	return PlantError.NONE


func plant(cell: Vector2i, flower_id: StringName, season: int) -> PlantError:
	var err := can_plant(cell, flower_id, season)
	if err != PlantError.NONE:
		return err
	var crop := Crop.new()
	crop.flower_id = flower_id
	(_cells[cell] as SoilCell).crop = crop
	cell_changed.emit(cell)
	return PlantError.NONE


## Removes any crop (used for withered plants). Fertiliser stays in the soil.
func clear_crop(cell: Vector2i) -> bool:
	if not has_crop(cell):
		return false
	(_cells[cell] as SoilCell).crop = null
	cell_changed.emit(cell)
	return true


## How many cut flowers a harvest of this cell would give (0 = not ready).
func harvest_yield(cell: Vector2i) -> int:
	if not is_harvestable(cell):
		return 0
	return 2 if is_fertilized(cell) else 1


## Harvests a blooming crop. Returns {} if nothing to harvest, otherwise
## {"flower_id", "flowers", "seeds"}. Regrowing flowers go back to their
## regrow stage; others leave the soil empty (still tilled).
func harvest(cell: Vector2i, rng: RandomNumberGenerator) -> Dictionary:
	if not is_harvestable(cell):
		return {}
	var crop := get_crop(cell)
	var fl: FlowerData = _flower(crop.flower_id)
	var result := {
		"flower_id": crop.flower_id,
		"flowers": harvest_yield(cell),
		"seeds": 1 if rng.randf() < fl.seed_drop_chance else 0,
	}
	if fl.regrows:
		crop.stage = fl.regrow_stage
		crop.growth = 0.0
		crop.days_dry = 0
	else:
		(_cells[cell] as SoilCell).crop = null
	cell_changed.emit(cell)
	return result


## Simulates one night. `season` is the season of the new day; `rained`
## waters everything (weather arrives in Phase 3).
## Returns counts: {"grew", "bloomed", "withered"}.
func advance_day(season: int, rained: bool = false) -> Dictionary:
	var stats := {"grew": 0, "bloomed": 0, "withered": 0}
	for cell: Vector2i in _cells:
		var soil := _cells[cell] as SoilCell
		var watered := soil.watered or rained
		var crop := soil.crop
		if crop != null and not crop.withered:
			_grow(cell, soil, crop, watered, season, stats)
		soil.watered = false
		cell_changed.emit(cell)
	return stats


func growth_multiplier(cell: Vector2i, fl: FlowerData) -> float:
	var mult := 1.0
	if is_fertilized(cell):
		mult += FERTILIZER_BONUS
	if fl.special == FlowerData.Special.LOVES_WATER and is_near_water(cell):
		mult += LOVES_WATER_BONUS
	return mult


func is_near_water(cell: Vector2i) -> bool:
	for dy in range(-WATER_RADIUS, WATER_RADIUS + 1):
		for dx in range(-WATER_RADIUS, WATER_RADIUS + 1):
			if water_cells.has(cell + Vector2i(dx, dy)):
				return true
	return false


func _grow(cell: Vector2i, soil: SoilCell, crop: Crop, watered: bool, season: int, stats: Dictionary) -> void:
	var fl: FlowerData = _flower(crop.flower_id)
	if fl == null or (not all_seasons and not fl.grows_in(season)):
		crop.withered = true
		stats["withered"] += 1
		return
	if crop.stage >= FlowerData.STAGE_BLOOM:
		return # blooms wait for harvest
	var gain := 1.0
	if watered:
		crop.days_dry = 0
	else:
		crop.days_dry += 1
		if crop.days_dry > fl.drought_tolerance():
			crop.withered = true
			stats["withered"] += 1
			return
		gain = fl.dry_growth()
	if fl.special == FlowerData.Special.NEEDS_FERTILIZER and not soil.fertilized \
			and crop.stage >= FlowerData.STAGE_DEVELOPED:
		gain = 0.0
	gain *= growth_multiplier(cell, fl)
	if gain <= 0.0:
		return
	crop.growth += gain
	stats["grew"] += 1
	while crop.stage < FlowerData.STAGE_BLOOM and crop.growth >= fl.stage_days[crop.stage] - 0.0001:
		crop.growth -= fl.stage_days[crop.stage]
		crop.stage += 1
		if crop.stage == FlowerData.STAGE_BLOOM:
			stats["bloomed"] += 1


## Debug/tools only: forces a crop's growth stage (used by demo scenarios).
func debug_set_stage(cell: Vector2i, stage: int) -> void:
	var crop := get_crop(cell)
	if crop == null:
		return
	crop.stage = clampi(stage, 0, FlowerData.STAGE_BLOOM)
	crop.growth = 0.0
	cell_changed.emit(cell)


func to_dict() -> Dictionary:
	var cells: Array = []
	for cell: Vector2i in _cells:
		var soil := _cells[cell] as SoilCell
		var entry := {"x": cell.x, "y": cell.y, "watered": soil.watered, "fertilized": soil.fertilized}
		if soil.crop:
			entry["crop"] = {"flower": String(soil.crop.flower_id), "stage": soil.crop.stage,
				"growth": soil.crop.growth, "days_dry": soil.crop.days_dry, "withered": soil.crop.withered}
		cells.append(entry)
	return {"cells": cells}


## Restores saved soil. Crops of unknown flowers are dropped.
## Returns the number of entries that had to be discarded or corrected.
func load_dict(data: Dictionary) -> int:
	clear()
	var issues := 0
	for entry in data.get("cells", []):
		if typeof(entry) != TYPE_DICTIONARY:
			issues += 1
			continue
		var cell := Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
		var soil := SoilCell.new()
		soil.watered = bool(entry.get("watered", false))
		soil.fertilized = bool(entry.get("fertilized", false))
		var c: Variant = entry.get("crop")
		if typeof(c) == TYPE_DICTIONARY:
			var id := StringName(str(c.get("flower", "")))
			if _flower(id) == null:
				issues += 1
			else:
				var crop := Crop.new()
				crop.flower_id = id
				crop.stage = clampi(int(c.get("stage", 0)), 0, FlowerData.STAGE_BLOOM)
				crop.growth = maxf(float(c.get("growth", 0.0)), 0.0)
				crop.days_dry = maxi(int(c.get("days_dry", 0)), 0)
				crop.withered = bool(c.get("withered", false))
				soil.crop = crop
		_cells[cell] = soil
		cell_changed.emit(cell)
	return issues
