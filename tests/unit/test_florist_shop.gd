extends TestCase

var shop: FloristShop
var wallet: Wallet
var inv: Inventory
var rng: RandomNumberGenerator


func before_each() -> void:
	shop = FloristShop.new()
	wallet = Wallet.new()
	wallet.add(5000)
	inv = Inventory.new(36)
	rng = RandomNumberGenerator.new()
	rng.seed = 7


func _restore() -> void:
	inv.add_item(&"stone", 10)
	inv.add_item(&"fiber", 10)
	assert_true(shop.restore(wallet, inv))


func test_restoration_costs_money_and_materials() -> void:
	assert_false(shop.restore(wallet, inv), "no materials yet")
	assert_false(shop.restored)
	_restore()
	assert_eq(wallet.amount, 5000 - int(shop.restoration_cost()["money"]))
	assert_eq(inv.count_of(&"stone"), 0)
	assert_eq(shop.slots.size(), 4)
	assert_false(shop.restore(wallet, inv), "only once")


func test_stock_unstock_and_prices() -> void:
	_restore()
	inv.add_item(&"flower_rose", 12)
	assert_eq(shop.stock_slot(0, &"flower_rose", 99, inv), 10, "capacity 10")
	assert_eq(inv.count_of(&"flower_rose"), 2)
	assert_eq(shop.slots[0]["price"], 95, "defaults to market value")
	assert_eq(shop.stock_slot(0, &"flower_daisy", 1, inv), 0, "one item type per slot")
	assert_eq(shop.stock_slot(1, &"hoe", 1, inv), 0, "tools can't be displayed")
	shop.adjust_price(0, 4)
	assert_eq(shop.slots[0]["price"], 95 + 19)
	shop.set_price(0, 9999)
	assert_eq(shop.slots[0]["price"], 285, "max 300%")
	shop.set_price(0, 1)
	assert_eq(shop.slots[0]["price"], 48, "min 50%")
	assert_eq(shop.unstock_slot(0, inv), 10)
	assert_eq(shop.slots[0]["item"], &"")
	assert_eq(inv.count_of(&"flower_rose"), 12)


func test_accept_chance_falls_with_price() -> void:
	var cheap := FloristShop.accept_chance(80, 100, 1.15)
	var fair := FloristShop.accept_chance(100, 100, 1.15)
	var pricey := FloristShop.accept_chance(150, 100, 1.15)
	assert_gt(cheap, fair)
	assert_gt(fair, pricey)
	assert_gt(FloristShop.accept_chance(150, 100, 1.5), pricey, "collectors tolerate more")


func _run_day(inside: bool, ticks: int = 48) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for i in ticks:
		events.append_array(shop.tick(540 + i * 10, 2, 0, 0, inside, wallet, rng))
	return events


func test_closed_or_unrestored_shop_sells_nothing() -> void:
	assert_true(_run_day(false).is_empty(), "not restored")
	_restore()
	inv.add_item(&"flower_daisy", 10)
	shop.stock_slot(0, &"flower_daisy", 10, inv)
	assert_true(_run_day(false).is_empty(), "closed")
	shop.is_open = true
	assert_true(shop.tick(400, 2, 0, 0, false, wallet, rng).is_empty(), "before opening hours")


func test_open_shop_sells_to_customers() -> void:
	_restore()
	inv.add_item(&"flower_daisy", 10)
	shop.stock_slot(0, &"flower_daisy", 10, inv)
	shop.is_open = true
	var before := wallet.amount
	var events := _run_day(false, 96)
	var sales := events.filter(func(e: Dictionary) -> bool: return e["type"] == "sale")
	assert_gt(sales.size(), 0, "some customers bought")
	assert_eq(wallet.amount - before, sales.size() * 30, "paid the display price")
	assert_eq(shop.slots[0]["count"] if shop.slots[0]["item"] != &"" else 0, 10 - sales.size())
	assert_gt(shop.reputation, 0, "fair prices build reputation")


func test_serving_in_person_gives_tips() -> void:
	_restore()
	inv.add_item(&"flower_lily", 10)
	shop.stock_slot(0, &"flower_lily", 10, inv)
	shop.is_open = true
	var waiting := 0
	for i in 200:
		for e in shop.tick(600, 2, 0, 0, true, wallet, rng):
			if e["type"] == "waiting":
				waiting += 1
		if shop.has_waiting():
			break
	assert_true(shop.has_waiting(), "a customer is waiting at the counter")
	var before := wallet.amount
	var rep := shop.reputation
	var sale := shop.serve_next(wallet)
	assert_eq(sale["tip"], 10, "10% tip on 100")
	assert_eq(wallet.amount - before, 110)
	assert_gt(shop.reputation, rep + 1)


func test_unserved_customers_pay_after_waiting() -> void:
	_restore()
	inv.add_item(&"flower_lily", 10)
	shop.stock_slot(0, &"flower_lily", 10, inv)
	shop.is_open = true
	for i in 200:
		shop.tick(600, 2, 0, 0, true, wallet, rng)
		if shop.has_waiting():
			break
	var due := int(shop.pending[0]["due"])
	var before := wallet.amount
	shop.tick(due, 2, 0, 0, true, wallet, RandomNumberGenerator.new())
	assert_gt(wallet.amount, before - 1)
	assert_eq(shop.pending.filter(func(s: Dictionary) -> bool: return int(s["due"]) <= due).size(), 0)


func test_overpricing_hurts_reputation() -> void:
	_restore()
	shop.reputation = 100
	inv.add_item(&"flower_daisy", 10)
	shop.stock_slot(0, &"flower_daisy", 10, inv)
	shop.set_price(0, 90)
	shop.is_open = true
	_run_day(false, 96)
	assert_lt(shop.reputation, 100, "300% prices drive customers away")


func test_orders_generate_expire_and_deliver() -> void:
	_restore()
	var created := 0
	for day in 10:
		created += shop.generate_orders(day + 1, 0, 0, rng)
	assert_gt(created, 0)
	assert_lt(shop.orders.size(), 4, "max 3 active")
	var order: Dictionary = shop.orders[0]
	assert_false(shop.deliver_order(int(order["id"]), wallet, inv), "don't have the items")
	inv.add_item(order["item"], int(order["count"]))
	var before := wallet.amount
	assert_true(shop.deliver_order(int(order["id"]), wallet, inv))
	assert_eq(wallet.amount - before, int(order["reward"]))
	var rep := shop.reputation
	var remaining := shop.orders.size()
	var summary := shop.end_day(wallet, 999, 2, 0, rng)
	assert_eq(summary["expired"], remaining, "late orders expire")
	assert_lt(shop.reputation, rep + 1)


func test_upgrades_and_decorations() -> void:
	_restore()
	assert_eq(shop.purchase_state("upgrades", "display_3", wallet, inv), "locked", "needs 2 stars")
	assert_true(shop.buy("upgrades", "display_2", wallet, inv))
	assert_eq(shop.slot_count(), 6)
	assert_eq(shop.slots.size(), 6)
	assert_eq(shop.purchase_state("upgrades", "display_2", wallet, inv), "owned")
	assert_eq(shop.purchase_state("decorations", "deco_vase", wallet, inv), "locked")
	shop.reputation = 50
	assert_eq(shop.stars(), 1)
	assert_eq(shop.purchase_state("decorations", "deco_vase", wallet, inv), "unaffordable", "needs clay")
	inv.add_item(&"forage_clay", 3)
	var rate := shop.customer_rate(0, 2)
	assert_true(shop.buy("decorations", "deco_vase", wallet, inv))
	assert_gt(shop.customer_rate(0, 2), rate, "decorations attract customers")


func test_crafting_consumes_and_discovers() -> void:
	inv.add_item(&"flower_rose", 2)
	inv.add_item(&"flower_tulip", 1)
	var items: Array[StringName] = [&"flower_rose", &"flower_rose", &"flower_tulip"]
	var result := shop.craft(items, inv)
	assert_eq(result["recipe"]["id"], "bouquet_romantic")
	assert_true(result["new"])
	assert_eq(inv.count_of(&"bouquet_romantic"), 1)
	assert_eq(inv.count_of(&"flower_rose"), 0)
	assert_true(shop.craft(items, inv).is_empty(), "no roses left")


func test_dict_roundtrip() -> void:
	_restore()
	inv.add_item(&"flower_tulip", 5)
	shop.stock_slot(1, &"flower_tulip", 5, inv)
	shop.adjust_price(1, 2)
	shop.is_open = true
	shop.reputation = 130
	shop.generate_orders(3, 0, 0, rng)
	shop.known_recipes["bouquet_simple"] = true
	shop.buy("upgrades", "sign", wallet, inv)
	var data: Dictionary = JSON.parse_string(JSON.stringify(shop.to_dict()))
	var other := FloristShop.new()
	assert_eq(other.load_dict(data), 0)
	assert_eq(JSON.stringify(other.to_dict()), JSON.stringify(shop.to_dict()))
	data["upgrades"].append("rocket")
	data["slots"][0] = {"item": "hoe", "count": 3, "price": 1}
	assert_eq(other.load_dict(data), 2, "unknown upgrade and invalid stock dropped")


func test_seasonal_orders_only_in_season() -> void:
	_restore()
	shop.reputation = 300
	var items := {}
	for day in 60:
		shop.orders.clear()
		shop.generate_orders(day + 1, 0, Calendar.Season.SUMMER, rng)
		for o in shop.orders:
			items[o["item"]] = true
	assert_false(items.has(&"bouquet_spring"), "spring-only orders not in summer")
	assert_false(items.has(&"flower_tulip"), "tulips are spring-only")
	assert_true(items.has(&"bouquet_summer"), "summer orders do appear (JSON numbers are floats)")
