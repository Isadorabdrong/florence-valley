extends TestCase

const SPRING := 0
const SUMMER := 1
var soil: SoilGrid
var flowers: Dictionary = {}


func _flower(id: StringName, seasons: Array[int], days: Array, water: FlowerData.WaterNeed,
		regrows := false, special := FlowerData.Special.NONE, drop := 0.0) -> FlowerData:
	var f := FlowerData.new()
	f.id = id
	f.name_key = "X"
	f.seasons = seasons
	f.stage_days = PackedInt32Array(days)
	f.water_need = water
	f.regrows = regrows
	f.regrow_stage = 3
	f.special = special
	f.seed_drop_chance = drop
	f.sell_price = 10
	return f


func before_each() -> void:
	flowers = {
		&"quick": _flower(&"quick", [SPRING], [1, 1, 1, 1, 1], FlowerData.WaterNeed.MEDIUM),
		&"hardy": _flower(&"hardy", [SPRING, SUMMER], [1, 1, 1, 1, 1], FlowerData.WaterNeed.LOW),
		&"thirsty": _flower(&"thirsty", [SPRING], [1, 1, 1, 1, 1], FlowerData.WaterNeed.HIGH),
		&"regrow": _flower(&"regrow", [SPRING], [1, 1, 1, 2, 1], FlowerData.WaterNeed.MEDIUM, true),
		&"picky": _flower(&"picky", [SPRING], [1, 1, 1, 1, 1], FlowerData.WaterNeed.MEDIUM, false, FlowerData.Special.NEEDS_FERTILIZER),
		&"pond": _flower(&"pond", [SPRING], [2, 2, 2, 2, 2], FlowerData.WaterNeed.MEDIUM, false, FlowerData.Special.LOVES_WATER),
		&"seedy": _flower(&"seedy", [SPRING], [1, 1, 1, 1, 1], FlowerData.WaterNeed.MEDIUM, false, FlowerData.Special.NONE, 1.0),
	}
	soil = SoilGrid.new()
	soil.flower_lookup = func(id: StringName) -> FlowerData: return flowers.get(id)


func _grow_watered(cell: Vector2i, days: int, season := SPRING) -> void:
	for i in days:
		soil.water(cell)
		soil.advance_day(season)


func test_till_water_and_reset_overnight() -> void:
	var c := Vector2i(2, 3)
	assert_true(soil.till(c))
	assert_false(soil.till(c), "already tilled")
	assert_true(soil.water(c))
	assert_false(soil.water(c), "already watered")
	soil.advance_day(SPRING)
	assert_false(soil.is_watered(c), "dries overnight")


func test_plant_requires_tilled_free_and_season() -> void:
	var c := Vector2i.ZERO
	assert_eq(soil.plant(c, &"quick", SPRING), SoilGrid.PlantError.NOT_TILLED)
	soil.till(c)
	assert_eq(soil.plant(c, &"quick", SUMMER), SoilGrid.PlantError.OUT_OF_SEASON)
	assert_eq(soil.plant(c, &"nope", SPRING), SoilGrid.PlantError.UNKNOWN_FLOWER)
	assert_eq(soil.plant(c, &"quick", SPRING), SoilGrid.PlantError.NONE)
	assert_eq(soil.plant(c, &"quick", SPRING), SoilGrid.PlantError.OCCUPIED)


func test_six_stages_with_daily_water() -> void:
	var c := Vector2i.ZERO
	soil.till(c)
	soil.plant(c, &"quick", SPRING)
	for expected in [1, 2, 3, 4, 5]:
		_grow_watered(c, 1)
		assert_eq(soil.get_crop(c).stage, expected, "stage after %d days" % expected)
	assert_true(soil.is_harvestable(c))
	_grow_watered(c, 2)
	assert_eq(soil.get_crop(c).stage, FlowerData.STAGE_BLOOM, "blooms wait for harvest")


func test_no_growth_without_water_then_withers() -> void:
	var c := Vector2i.ZERO
	soil.till(c)
	soil.plant(c, &"quick", SPRING) # MEDIUM: tolerates 2 dry days
	soil.advance_day(SPRING)
	soil.advance_day(SPRING)
	assert_eq(soil.get_crop(c).stage, 0, "medium flowers don't grow dry")
	assert_false(soil.is_withered(c))
	soil.advance_day(SPRING)
	assert_true(soil.is_withered(c), "third dry day withers it")


func test_low_water_flowers_grow_slowly_when_dry() -> void:
	var c := Vector2i.ZERO
	soil.till(c)
	soil.plant(c, &"hardy", SPRING)
	soil.advance_day(SPRING)
	soil.advance_day(SPRING)
	assert_eq(soil.get_crop(c).stage, 1, "two dry half-days = one stage")


func test_high_water_flowers_wither_fast() -> void:
	var c := Vector2i.ZERO
	soil.till(c)
	soil.plant(c, &"thirsty", SPRING)
	soil.advance_day(SPRING)
	assert_false(soil.is_withered(c))
	soil.advance_day(SPRING)
	assert_true(soil.is_withered(c))


func test_rain_waters_everything() -> void:
	var c := Vector2i.ZERO
	soil.till(c)
	soil.plant(c, &"quick", SPRING)
	soil.advance_day(SPRING, true)
	assert_eq(soil.get_crop(c).stage, 1)


func test_out_of_season_withers() -> void:
	var c := Vector2i.ZERO
	soil.till(c)
	soil.plant(c, &"quick", SPRING)
	soil.water(c)
	var stats := soil.advance_day(SUMMER)
	assert_true(soil.is_withered(c))
	assert_eq(stats["withered"], 1)
	assert_true(soil.clear_crop(c))
	assert_true(soil.is_tilled(c), "soil stays tilled")


func test_fertilizer_speeds_growth_and_doubles_harvest() -> void:
	var a := Vector2i(0, 0)
	var b := Vector2i(5, 0)
	for c in [a, b]:
		soil.till(c)
		soil.plant(c, &"pond", SPRING) # 10 growth points; no water nearby
	soil.fertilize(b)
	for i in 8:
		soil.water(a)
		soil.water(b)
		soil.advance_day(SPRING)
	assert_eq(soil.get_crop(a).stage, 4, "8 points")
	assert_eq(soil.get_crop(b).stage, 5, "8 x 1.25 = 10 points")
	assert_eq(soil.harvest_yield(b), 2)


func test_loves_water_bonus() -> void:
	var near := Vector2i(0, 0)
	var far := Vector2i(10, 0)
	soil.water_cells = {Vector2i(1, 1): true}
	assert_true(soil.is_near_water(near))
	assert_false(soil.is_near_water(far))
	for c in [near, far]:
		soil.till(c)
		soil.plant(c, &"pond", SPRING)
	for i in 4:
		soil.water(near)
		soil.water(far)
		soil.advance_day(SPRING)
	assert_eq(soil.get_crop(near).stage, 3, "6 points near water")
	assert_eq(soil.get_crop(far).stage, 2, "4 points far from water")


func test_needs_fertilizer_stalls_at_developed() -> void:
	var c := Vector2i.ZERO
	soil.till(c)
	soil.plant(c, &"picky", SPRING)
	_grow_watered(c, 6)
	assert_eq(soil.get_crop(c).stage, FlowerData.STAGE_DEVELOPED)
	soil.fertilize(c)
	_grow_watered(c, 2)
	assert_eq(soil.get_crop(c).stage, FlowerData.STAGE_BLOOM)


func test_harvest_non_regrowing_clears_crop() -> void:
	var c := Vector2i.ZERO
	soil.till(c)
	soil.plant(c, &"seedy", SPRING)
	var rng := RandomNumberGenerator.new()
	assert_eq(soil.harvest(c, rng), {}, "not ready yet")
	_grow_watered(c, 5)
	var result := soil.harvest(c, rng)
	assert_eq(result["flower_id"], &"seedy")
	assert_eq(result["flowers"], 1)
	assert_eq(result["seeds"], 1, "seed_drop_chance 1.0 always reproduces")
	assert_false(soil.has_crop(c))
	assert_true(soil.is_tilled(c))


func test_harvest_regrowing_returns_to_regrow_stage() -> void:
	var c := Vector2i.ZERO
	soil.till(c)
	soil.plant(c, &"regrow", SPRING)
	_grow_watered(c, 6)
	assert_true(soil.is_harvestable(c))
	soil.harvest(c, RandomNumberGenerator.new())
	assert_eq(soil.get_crop(c).stage, 3)
	_grow_watered(c, 3)
	assert_true(soil.is_harvestable(c), "regrows in stage_days[3] + stage_days[4] days")


func test_untill_only_without_crop() -> void:
	var c := Vector2i.ZERO
	soil.till(c)
	soil.plant(c, &"quick", SPRING)
	assert_false(soil.untill(c))
	soil.clear_crop(c)
	assert_true(soil.untill(c))
	assert_false(soil.is_tilled(c))


func test_dict_roundtrip() -> void:
	var c := Vector2i(4, 7)
	soil.till(c)
	soil.fertilize(c)
	soil.plant(c, &"quick", SPRING)
	_grow_watered(c, 2)
	soil.water(c)
	var data := soil.to_dict()
	var other := SoilGrid.new()
	other.flower_lookup = soil.flower_lookup
	assert_eq(other.load_dict(data), 0)
	assert_eq(other.to_dict(), data)
	data["cells"][0]["crop"]["flower"] = "ghost"
	assert_eq(other.load_dict(data), 1, "unknown flower reported")
	assert_true(other.is_tilled(c), "soil kept even if crop dropped")


func after_each() -> void:
	# The injected lambda references this test; drop it to break the cycle.
	soil.flower_lookup = Callable()
	soil = null
