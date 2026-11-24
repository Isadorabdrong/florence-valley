extends TestCase

const A := FarmActionResolver.Action
var r: FarmActionResolver
var objects: Dictionary = {}
var terrain: Dictionary = {}
var charges := 5


func _tool(kind: ItemData.ToolKind) -> ItemData:
	var item := ItemData.new()
	item.category = ItemData.Category.TOOL
	item.tool_kind = kind
	return item


func before_each() -> void:
	objects = {}
	terrain = {}
	charges = 5
	r = FarmActionResolver.new()
	r.soil = SoilGrid.new()
	r.soil.flower_lookup = func(id: StringName) -> FlowerData: return ItemRegistry.flower(id)
	r.season = func() -> int: return Calendar.Season.SPRING
	r.terrain_at = func(c: Vector2i) -> String: return terrain.get(c, "grass")
	r.object_kind_at = func(c: Vector2i) -> StringName: return objects.get(c, &"")
	r.can_charges = func() -> int: return charges
	r.can_capacity = func() -> int: return 20


func test_hoe() -> void:
	var hoe := _tool(ItemData.ToolKind.HOE)
	assert_eq(r.resolve_use(Vector2i.ZERO, hoe)["action"], A.TILL)
	terrain[Vector2i(1, 0)] = "path"
	assert_eq(r.resolve_use(Vector2i(1, 0), hoe)["reason"], "MSG_CANT_TILL")
	objects[Vector2i(2, 0)] = &"weed"
	assert_eq(r.resolve_use(Vector2i(2, 0), hoe)["reason"], "MSG_CLEAR_FIRST")
	objects[Vector2i(3, 0)] = &"solid"
	assert_eq(r.resolve_use(Vector2i(3, 0), hoe)["reason"], "MSG_BLOCKED")
	r.soil.till(Vector2i.ZERO)
	assert_eq(r.resolve_use(Vector2i.ZERO, hoe)["reason"], "MSG_ALREADY_TILLED")


func test_watering_can() -> void:
	var can := _tool(ItemData.ToolKind.WATERING_CAN)
	assert_eq(r.resolve_use(Vector2i.ZERO, can)["reason"], "MSG_NOTHING_TO_WATER")
	r.soil.till(Vector2i.ZERO)
	assert_eq(r.resolve_use(Vector2i.ZERO, can)["action"], A.WATER)
	charges = 0
	assert_eq(r.resolve_use(Vector2i.ZERO, can)["reason"], "MSG_CAN_EMPTY")
	terrain[Vector2i(5, 5)] = "water"
	assert_eq(r.resolve_use(Vector2i(5, 5), can)["action"], A.REFILL)
	objects[Vector2i(6, 6)] = &"well"
	assert_eq(r.resolve_use(Vector2i(6, 6), can)["action"], A.REFILL)
	charges = 20
	assert_eq(r.resolve_use(Vector2i(6, 6), can)["reason"], "MSG_CAN_FULL")


func test_seed_and_fertilizer() -> void:
	var seed := ItemRegistry.item(&"seed_daisy")
	var fert := ItemRegistry.item(&"fertilizer")
	assert_eq(r.resolve_use(Vector2i.ZERO, seed)["reason"], "MSG_NEEDS_TILLED")
	assert_eq(r.resolve_use(Vector2i.ZERO, fert)["reason"], "MSG_NEEDS_TILLED")
	r.soil.till(Vector2i.ZERO)
	assert_eq(r.resolve_use(Vector2i.ZERO, seed)["action"], A.PLANT)
	assert_eq(r.resolve_use(Vector2i.ZERO, fert)["action"], A.FERTILIZE)
	r.season = func() -> int: return Calendar.Season.WINTER
	assert_eq(r.resolve_use(Vector2i.ZERO, seed)["reason"], "MSG_OUT_OF_SEASON")


func test_scythe_and_pickaxe() -> void:
	var scythe := _tool(ItemData.ToolKind.SCYTHE)
	var pick := _tool(ItemData.ToolKind.PICKAXE)
	objects[Vector2i(1, 1)] = &"weed"
	objects[Vector2i(2, 2)] = &"rock"
	assert_eq(r.resolve_use(Vector2i(1, 1), scythe)["action"], A.CLEAR_WEED)
	assert_eq(r.resolve_use(Vector2i(2, 2), pick)["action"], A.BREAK_ROCK)
	assert_eq(r.resolve_use(Vector2i(2, 2), scythe)["reason"], "MSG_NOTHING_TO_CUT")
	r.soil.till(Vector2i.ZERO)
	assert_eq(r.resolve_use(Vector2i.ZERO, pick)["action"], A.UNTILL)


func test_interact() -> void:
	objects[Vector2i(0, 1)] = &"bed"
	objects[Vector2i(0, 2)] = &"interact"
	objects[Vector2i(0, 3)] = &"forage"
	assert_eq(r.resolve_interact(Vector2i(0, 1))["action"], A.SLEEP)
	assert_eq(r.resolve_interact(Vector2i(0, 2))["action"], A.INTERACT)
	assert_eq(r.resolve_interact(Vector2i(0, 3))["action"], A.FORAGE)
	assert_eq(r.resolve_interact(Vector2i(9, 9))["action"], A.NONE)
	assert_eq(r.resolve_use(Vector2i(0, 1), null)["action"], A.SLEEP, "empty hand = interact")
	var hoe := _tool(ItemData.ToolKind.HOE)
	assert_eq(r.resolve_use(Vector2i(0, 2), hoe)["action"], A.INTERACT, "doors win over held tools")


func test_no_farming_outside_the_farm() -> void:
	r.farming_allowed = func() -> bool: return false
	assert_eq(r.resolve_use(Vector2i.ZERO, _tool(ItemData.ToolKind.HOE))["reason"], "MSG_NO_FARMING_HERE")
	assert_eq(r.resolve_use(Vector2i.ZERO, ItemRegistry.item(&"seed_daisy"))["reason"], "MSG_NO_FARMING_HERE")
	terrain[Vector2i(5, 5)] = "water"
	assert_eq(r.resolve_use(Vector2i(5, 5), _tool(ItemData.ToolKind.WATERING_CAN))["action"], A.REFILL,
		"refilling still works everywhere")


func after_each() -> void:
	# Injected lambdas reference this test; drop them to break the cycle.
	r.season = Callable()
	r.terrain_at = Callable()
	r.object_kind_at = Callable()
	r.can_charges = Callable()
	r.can_capacity = Callable()
	r.farming_allowed = Callable()
	r.soil.flower_lookup = Callable()
	r = null
