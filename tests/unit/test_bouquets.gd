extends TestCase


func _find(ids: Array) -> String:
	var items: Array[StringName] = []
	for id in ids:
		items.append(StringName(id))
	return str(BouquetBook.find(items).get("id", ""))


func test_recipes_valid_and_all_five_types_exist() -> void:
	var problems := BouquetBook.validate()
	assert_true(problems.is_empty(), "\n".join(problems))
	var types := {}
	for r in BouquetBook.recipes():
		types[r["type"]] = true
		assert_ne(ItemRegistry.item(StringName(str(r["id"]))), null, "item for %s" % r["id"])
	for t in ["simple", "romantic", "sophisticated", "seasonal", "rare"]:
		assert_true(types.has(t), "type %s" % t)


func test_specific_recipes() -> void:
	assert_eq(_find(["flower_daisy", "flower_daisy", "flower_daisy"]), "bouquet_daisy")
	assert_eq(_find(["flower_rose", "flower_tulip", "flower_rose"]), "bouquet_romantic", "order doesn't matter")
	assert_eq(_find(["flower_lavender", "flower_rose", "flower_lily"]), "bouquet_elegant")
	assert_eq(_find(["flower_lily", "forage_glow_moss", "forage_lotus"]), "bouquet_rare")
	assert_eq(_find(["forage_violet", "flower_daisy", "flower_tulip"]), "bouquet_spring")
	assert_eq(_find(["forage_poppy", "flower_sunflower", "flower_lavender"]), "bouquet_summer")
	assert_eq(_find(["forage_snowdrop", "forage_pinecone", "forage_snowdrop"]), "bouquet_winter")
	assert_eq(_find(["forage_violet", "forage_poppy", "forage_wild_lavender"]), "bouquet_wild")


func test_fallback_and_invalid() -> void:
	assert_eq(_find(["flower_daisy", "flower_sunflower", "flower_lily"]), "bouquet_simple")
	assert_eq(_find(["flower_daisy", "flower_daisy"]), "", "needs three items")
	assert_eq(_find(["flower_daisy", "flower_daisy", "forage_shell"]), "", "a shell is not a flower")
	assert_eq(_find(["hoe", "flower_daisy", "flower_daisy"]), "")


func test_designed_recipes_add_value() -> void:
	var combos := {
		"bouquet_daisy": ["flower_daisy", "flower_daisy", "flower_daisy"],
		"bouquet_romantic": ["flower_rose", "flower_rose", "flower_tulip"],
		"bouquet_elegant": ["flower_lily", "flower_lavender", "flower_rose"],
		"bouquet_rare": ["forage_lotus", "flower_lily", "forage_glow_moss"],
		"bouquet_spring": ["flower_tulip", "flower_daisy", "forage_violet"],
		"bouquet_summer": ["flower_sunflower", "flower_lavender", "forage_poppy"],
		"bouquet_winter": ["forage_snowdrop", "forage_snowdrop", "forage_pinecone"],
		"bouquet_wild": ["forage_violet", "forage_poppy", "forage_violet"],
	}
	for id: String in combos:
		var items: Array[StringName] = []
		for i in combos[id]:
			items.append(StringName(i))
		var value := ItemRegistry.item(StringName(id)).sell_price
		assert_gt(value, BouquetBook.ingredients_value(items), "%s is worth more than its flowers" % id)


func test_bouquet_items_have_icons_and_tags() -> void:
	for r in BouquetBook.recipes():
		var item := ItemRegistry.item(StringName(str(r["id"])))
		assert_eq(item.category, ItemData.Category.BOUQUET)
		assert_true(item.tags.has("bouquet") and item.tags.has(str(r["type"])))
		assert_ne(ItemRegistry.icon(item.id), null)
