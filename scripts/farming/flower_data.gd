class_name FlowerData
extends Resource
## Definition of a flower species. One .tres per species in resources/flowers/.
## Seed and cut-flower items are generated from this by ItemRegistry.

enum WaterNeed { LOW, MEDIUM, HIGH }
enum Rarity { COMMON, SPECIAL, RARE }
## Special growing conditions:
##  NEEDS_FERTILIZER — stalls at the "developed" stage unless the soil is fertilised.
##  LOVES_WATER      — grows 50% faster within 2 tiles of open water.
##  GREENHOUSE_ONLY  — can only be planted in the greenhouse.
enum Special { NONE, NEEDS_FERTILIZER, LOVES_WATER, GREENHOUSE_ONLY }

const STAGE_SEED := 0
const STAGE_SPROUT := 1
const STAGE_YOUNG := 2
const STAGE_DEVELOPED := 3
const STAGE_BUDDING := 4
const STAGE_BLOOM := 5
const STAGE_KEYS: Array[String] = ["STAGE_SEED", "STAGE_SPROUT", "STAGE_YOUNG",
	"STAGE_DEVELOPED", "STAGE_BUDDING", "STAGE_BLOOM"]

@export var id: StringName = &""
@export var name_key := ""
@export var description_key := ""
## Calendar.Season values in which this flower can grow outdoors.
@export var seasons: Array[int] = []
## Growth points needed to leave stages 0..4 (one watered day = 1 point).
@export var stage_days: PackedInt32Array = PackedInt32Array([1, 1, 1, 1, 1])
@export var water_need: WaterNeed = WaterNeed.MEDIUM
@export var sell_price := 0
@export var seed_price := 0
@export var rarity: Rarity = Rarity.COMMON
@export var regrows := false
## Stage a regrowing flower returns to after harvest.
@export_range(0, 4) var regrow_stage := STAGE_DEVELOPED
@export var special: Special = Special.NONE
## Chance that a harvest also yields one seed (reproduction).
@export_range(0.0, 1.0) var seed_drop_chance := 0.0
## Row in assets/flowers/flower_atlas.png and column in the icon atlas.
@export var atlas_row := 0
## Gardening level needed before shops sell its seeds.
@export var min_level := 1
## Tags copied to the cut-flower item (used by bouquets and customers).
@export var tags: PackedStringArray = PackedStringArray()


func total_growth_days() -> int:
	var total := 0
	for d in stage_days:
		total += d
	return total


func days_to_regrow() -> int:
	var total := 0
	for i in range(regrow_stage, stage_days.size()):
		total += stage_days[i]
	return total


func grows_in(season: int) -> bool:
	return seasons.has(season)


## Consecutive dry days a crop survives before withering.
func drought_tolerance() -> int:
	match water_need:
		WaterNeed.LOW:
			return 3
		WaterNeed.HIGH:
			return 1
	return 2


## Growth on a day without water (hardy flowers still grow a little).
func dry_growth() -> float:
	return 0.5 if water_need == WaterNeed.LOW else 0.0


## Returns a list of problems; empty when the definition is valid.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id == &"":
		errors.append("missing id")
	if name_key.is_empty():
		errors.append("%s: missing name_key" % id)
	if seasons.is_empty():
		errors.append("%s: no seasons" % id)
	for s in seasons:
		if s < 0 or s > 3:
			errors.append("%s: invalid season %d" % [id, s])
	if stage_days.size() != STAGE_BLOOM:
		errors.append("%s: stage_days needs %d entries" % [id, STAGE_BLOOM])
	for d in stage_days:
		if d < 1:
			errors.append("%s: stage_days must be >= 1" % id)
	if sell_price <= seed_price:
		errors.append("%s: sell_price should exceed seed_price" % id)
	return errors
