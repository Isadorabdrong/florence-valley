extends TestCase

var shop: Shop
var wallet: Wallet
var inv: Inventory


func before_each() -> void:
	shop = Shop.load_from_file("res://data/shops/flora_cart.json")
	wallet = Wallet.new()
	wallet.add(200)
	inv = Inventory.new(4)


func test_loads_and_filters_by_season() -> void:
	assert_ne(shop, null)
	var spring := shop.available_items(Calendar.Season.SPRING).map(func(i: ItemData) -> StringName: return i.id)
	assert_true(spring.has(&"seed_tulip"))
	assert_true(spring.has(&"fertilizer"))
	var summer := shop.available_items(Calendar.Season.SUMMER).map(func(i: ItemData) -> StringName: return i.id)
	assert_false(summer.has(&"seed_tulip"), "tulips are spring-only")
	var winter := shop.available_items(Calendar.Season.WINTER).map(func(i: ItemData) -> StringName: return i.id)
	for id: StringName in winter:
		var item := ItemRegistry.item(id)
		if item.flower_id != &"":
			assert_true(ItemRegistry.flower(item.flower_id).grows_in(Calendar.Season.WINTER),
				"%s sold in winter must grow in winter" % id)
	assert_true(winter.has(&"fertilizer"))
	assert_false(winter.has(&"seed_tulip"))


func test_buy() -> void:
	var price := ItemRegistry.item(&"seed_daisy").buy_price
	assert_eq(shop.buy(&"seed_daisy", 3, 0, wallet, inv), Shop.Result.OK)
	assert_eq(wallet.amount, 200 - price * 3)
	assert_eq(inv.count_of(&"seed_daisy"), 3)
	assert_eq(shop.buy(&"seed_rose", 99, 0, wallet, inv), Shop.Result.NOT_ENOUGH_MONEY)
	assert_eq(shop.buy(&"hoe", 1, 0, wallet, inv), Shop.Result.NOT_SOLD_HERE)
	assert_eq(shop.buy(&"seed_tulip", 1, Calendar.Season.SUMMER, wallet, inv), Shop.Result.NOT_SOLD_HERE)


func test_buy_fails_cleanly_when_inventory_full() -> void:
	for id in [&"hoe", &"scythe", &"pickaxe", &"watering_can"]:
		inv.add_item(id, 1)
	var before := wallet.amount
	assert_eq(shop.buy(&"fertilizer", 1, 0, wallet, inv), Shop.Result.INVENTORY_FULL)
	assert_eq(wallet.amount, before, "no money taken")


func test_sell() -> void:
	inv.add_item(&"flower_rose", 3)
	inv.add_item(&"hoe", 1)
	var price := ItemRegistry.flower(&"rose").sell_price
	assert_eq(shop.sell(&"flower_rose", 2, wallet, inv), Shop.Result.OK)
	assert_eq(wallet.amount, 200 + price * 2)
	assert_eq(inv.count_of(&"flower_rose"), 1)
	assert_eq(shop.sell(&"flower_rose", 10, wallet, inv), Shop.Result.OK, "sells what is there")
	assert_eq(inv.count_of(&"flower_rose"), 0)
	assert_eq(shop.sell(&"hoe", 1, wallet, inv), Shop.Result.NOTHING_TO_SELL, "tools can't be sold")
	assert_eq(shop.sell(&"flower_rose", 1, wallet, inv), Shop.Result.NOTHING_TO_SELL)


func test_economy_is_profitable_but_gradual() -> void:
	for f in ItemRegistry.all_flowers():
		var profit := f.sell_price - f.seed_price
		assert_gt(profit, 0, "%s must be profitable" % f.id)
		if f.rarity == FlowerData.Rarity.RARE:
			continue # rewards, never sold: see test_rare_seeds_are_never_sold
		var per_day := float(profit) / f.total_growth_days()
		assert_lt(per_day, 15.0, "%s profit/day should stay modest" % f.id)


func test_rare_seeds_are_never_sold() -> void:
	for shop_id in ["flora_cart", "market", "workshop"]:
		var s := Shop.load_from_file("res://data/shops/%s.json" % shop_id)
		for entry in s.stock:
			var item := ItemRegistry.item(entry["item"])
			if item.flower_id != &"":
				assert_ne(ItemRegistry.flower(item.flower_id).rarity, FlowerData.Rarity.RARE, "%s sells %s" % [shop_id, item.id])
