extends TestCase


func test_all_flowers_are_valid() -> void:
	var flowers := ItemRegistry.all_flowers()
	assert_eq(flowers.size(), 17, "6 common + 6 special + 5 rare")
	var rarities := {}
	for f in flowers:
		rarities[f.rarity] = int(rarities.get(f.rarity, 0)) + 1
	assert_eq(rarities, {FlowerData.Rarity.COMMON: 6, FlowerData.Rarity.SPECIAL: 6, FlowerData.Rarity.RARE: 5})
	var rows := {}
	for f in flowers:
		assert_true(f.validate().is_empty(), "%s: %s" % [f.id, f.validate()])
		assert_false(rows.has(f.atlas_row), "duplicate atlas row %d" % f.atlas_row)
		rows[f.atlas_row] = true
		for key in [f.name_key, f.description_key]:
			assert_ne(TranslationServer.translate(key), StringName(key), "missing translation %s" % key)


func test_seed_and_flower_items_generated() -> void:
	for f in ItemRegistry.all_flowers():
		var seed := ItemRegistry.item(ItemRegistry.seed_id(f.id))
		var cut := ItemRegistry.item(ItemRegistry.flower_item_id(f.id))
		assert_ne(seed, null, "seed item for %s" % f.id)
		assert_ne(cut, null, "flower item for %s" % f.id)
		if seed and cut:
			assert_eq(seed.category, ItemData.Category.SEED)
			assert_eq(cut.sell_price, f.sell_price)
			assert_true(seed.display_name().contains(cut.display_name()), seed.display_name())


func test_every_item_has_icon_and_translations() -> void:
	for id in ItemRegistry.all_item_ids():
		var item := ItemRegistry.item(id)
		assert_ne(ItemRegistry.icon(id), null, "icon for %s" % id)
		assert_ne(TranslationServer.translate(item.name_key), StringName(item.name_key), "name for %s" % id)
		assert_ne(TranslationServer.translate(item.description_key), StringName(item.description_key), "desc for %s" % id)
		assert_false(ItemRegistry.describe(id).is_empty())


func test_starter_items_exist() -> void:
	for entry: Array in GameState.STARTER_ITEMS:
		assert_true(ItemRegistry.has_item(entry[0]), "starter item %s" % entry[0])
	assert_lt(GameState.STARTER_ITEMS.size(), GameState.HOTBAR_SIZE + 1, "starter kit fits the hotbar")


func test_tools_do_not_stack() -> void:
	for id in [&"hoe", &"watering_can", &"scythe", &"pickaxe"]:
		assert_eq(ItemRegistry.max_stack(id), 1, String(id))
