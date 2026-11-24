class_name FloristShop
extends RefCounted
## The player's flower shop: restoration, display slots with prices,
## simulated customers, serving at the counter, orders, reputation,
## upgrades, decorations and bouquet crafting.
##
## Pure data + rules: GameState ticks it with the clock, the shop interior
## shows it (customers walking), and the panels edit it. Every random
## decision uses an injected RandomNumberGenerator, so tests are exact.
## Tuning lives in data/florist/florist.json.

signal changed
signal customer_arrived(customer: Dictionary)
signal customer_left(customer: Dictionary)
signal sale_completed(sale: Dictionary)
signal reputation_changed(value: int)

const CONFIG_PATH := "res://data/florist/florist.json"
const SERVE_WINDOW := 30 ## game minutes a customer waits at the counter
const TIP_RATE := 0.1
const PRICE_STEP := 0.05
const MIN_PRICE_RATIO := 0.5
const MAX_PRICE_RATIO := 3.0
const FAIR_RATIO := 1.15
const GREEDY_RATIO := 1.4
const DISPLAY_TAGS: Array[String] = ["wild", "decor", "rare", "greenery"]

static var _config: Dictionary = {}

var restored := false
var is_open := false
var reputation := 0
var upgrades: Dictionary = {}
var decorations: Dictionary = {}
## Display slots: {"item": StringName (&"" = empty), "count": int, "price": int}
var slots: Array[Dictionary] = []
## Orders: {"id", "customer", "note", "item", "count", "reward", "reputation", "deadline"}
var orders: Array[Dictionary] = []
var known_recipes: Dictionary = {}
## Customers waiting at the counter to be served.
var pending: Array[Dictionary] = []
var today := {}
var totals := {}
var _next_id := 1


static func config() -> Dictionary:
	if _config.is_empty():
		var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(file.get_as_text()) if file else null
		if typeof(parsed) != TYPE_DICTIONARY:
			push_error("FloristShop: invalid %s" % CONFIG_PATH)
			return {}
		_config = parsed
	return _config


func _init() -> void:
	reset()


func reset() -> void:
	restored = false
	is_open = false
	reputation = 0
	upgrades.clear()
	decorations.clear()
	slots.clear()
	orders.clear()
	known_recipes.clear()
	pending.clear()
	today = {"sales": 0, "income": 0, "customers": 0, "tips": 0}
	totals = {"sales": 0, "income": 0, "bouquets": 0, "orders": 0}
	_next_id = 1
	changed.emit()


# ------------------------------------------------------------- restoring ---

func restoration_cost() -> Dictionary:
	return config().get("restoration", {})


func can_afford(cost: int, items: Array, wallet: Wallet, inventory: Inventory) -> bool:
	if not wallet.can_afford(cost):
		return false
	for entry: Array in items:
		if inventory.count_of(StringName(str(entry[0]))) < int(entry[1]):
			return false
	return true


func _pay(cost: int, items: Array, wallet: Wallet, inventory: Inventory) -> bool:
	if not can_afford(cost, items, wallet, inventory):
		return false
	if cost > 0:
		wallet.spend(cost)
	for entry: Array in items:
		inventory.remove_item(StringName(str(entry[0])), int(entry[1]))
	return true


func restore(wallet: Wallet, inventory: Inventory) -> bool:
	if restored:
		return false
	var cost := restoration_cost()
	if not _pay(int(cost.get("money", 0)), cost.get("items", []), wallet, inventory):
		return false
	restored = true
	_ensure_slots()
	changed.emit()
	return true


# ---------------------------------------------------------------- stats ---

func stars() -> int:
	var thresholds: Array = config().get("star_thresholds", [0])
	var s := 0
	for i in range(1, thresholds.size()):
		if reputation >= int(thresholds[i]):
			s = i
	return s


func next_star_at() -> int:
	var thresholds: Array = config().get("star_thresholds", [0])
	var s := stars()
	return int(thresholds[s + 1]) if s + 1 < thresholds.size() else -1


func add_reputation(delta: int) -> void:
	var before := reputation
	reputation = clampi(reputation + delta, 0, int(config().get("max_reputation", 1000)))
	if reputation != before:
		reputation_changed.emit(reputation)


func slot_count() -> int:
	var count := int(config().get("base_slots", 4))
	for u in _owned(config().get("upgrades", []), upgrades):
		count += int(u.get("slots", 0))
	return count


func _ensure_slots() -> void:
	while slots.size() < slot_count():
		slots.append({"item": &"", "count": 0, "price": 0})


func _owned(defs: Array, owned: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for d: Dictionary in defs:
		if owned.has(str(d["id"])):
			out.append(d)
	return out


func _bonus(key: String) -> float:
	var total := 0.0
	for d in _owned(config().get("upgrades", []), upgrades):
		total += float(d.get(key, 0.0))
	for d in _owned(config().get("decorations", []), decorations):
		total += float(d.get(key, 0.0))
	return total


## Customers per 10-minute tick (probability).
func customer_rate(weather: int, weekday: int) -> float:
	var cfg := config()
	var rate := float(cfg.get("customer_rate", 0.13))
	rate *= 1.0 + stars() * 0.12
	rate *= 1.0 + _bonus("rate")
	rate *= float((cfg.get("weather_factor", {}) as Dictionary).get(str(weather), 1.0))
	if weekday >= 5:
		rate *= float(cfg.get("weekend_factor", 1.0))
	return clampf(rate, 0.0, 0.95)


# -------------------------------------------------------------- displays ---

static func can_display(item_id: StringName) -> bool:
	var item := ItemRegistry.item(item_id)
	if item == null or item.is_tool() or item.sell_price <= 0:
		return false
	if item.category == ItemData.Category.FLOWER or item.category == ItemData.Category.BOUQUET:
		return true
	for tag in DISPLAY_TAGS:
		if item.tags.has(tag):
			return true
	return false


static func base_value(item_id: StringName) -> int:
	var item := ItemRegistry.item(item_id)
	return item.sell_price if item else 0


func has_stock() -> bool:
	for s in slots:
		if int(s["count"]) > 0:
			return true
	return false


## Moves up to `count` items from the inventory into a display slot.
## Returns how many were moved.
func stock_slot(index: int, item_id: StringName, count: int, inventory: Inventory) -> int:
	if index < 0 or index >= slots.size() or not can_display(item_id):
		return 0
	var slot := slots[index]
	if int(slot["count"]) > 0 and slot["item"] != item_id:
		return 0
	var room := int(config().get("slot_capacity", 10)) - int(slot["count"])
	var moved := mini(mini(count, room), inventory.count_of(item_id))
	if moved <= 0:
		return 0
	inventory.remove_item(item_id, moved)
	if slot["item"] != item_id:
		slot["price"] = base_value(item_id)
	slot["item"] = item_id
	slot["count"] = int(slot["count"]) + moved
	changed.emit()
	return moved


## Returns a slot's stock to the inventory. Returns how many came back.
func unstock_slot(index: int, inventory: Inventory) -> int:
	if index < 0 or index >= slots.size():
		return 0
	var slot := slots[index]
	if int(slot["count"]) <= 0:
		return 0
	var left := inventory.add_item(slot["item"], int(slot["count"]))
	var returned := int(slot["count"]) - left
	slot["count"] = left
	if left == 0:
		slot["item"] = &""
	changed.emit()
	return returned


func set_price(index: int, price: int) -> void:
	if index < 0 or index >= slots.size() or slots[index]["item"] == &"":
		return
	var base := base_value(slots[index]["item"])
	slots[index]["price"] = clampi(price, ceili(base * MIN_PRICE_RATIO), floori(base * MAX_PRICE_RATIO))
	changed.emit()


## Moves a price by `steps` × 5% of the item's value.
func adjust_price(index: int, steps: int) -> void:
	if index < 0 or index >= slots.size() or slots[index]["item"] == &"":
		return
	var base := base_value(slots[index]["item"])
	set_price(index, int(slots[index]["price"]) + int(round(base * PRICE_STEP * steps)))


# ------------------------------------------------------------- customers ---

func _item_likes(item_id: StringName) -> PackedStringArray:
	var item := ItemRegistry.item(item_id)
	var likes := PackedStringArray(item.tags if item else PackedStringArray())
	var recipe := BouquetBook.recipe(item_id)
	if not recipe.is_empty():
		likes.append(str(recipe["type"]))
	return likes


func _pick_archetype(rng: RandomNumberGenerator) -> Dictionary:
	var pool: Array[Dictionary] = []
	var total := 0
	for a: Dictionary in config().get("archetypes", []):
		if stars() >= int(a.get("min_stars", 0)):
			pool.append(a)
			total += int(a["weight"])
	var pick := rng.randi_range(1, maxi(total, 1))
	for a in pool:
		pick -= int(a["weight"])
		if pick <= 0:
			return a
	return pool[0] if not pool.is_empty() else {"id": "casual", "tolerance": 1.15, "likes": []}


## Chance that a customer accepts `price` for an item worth `base`.
static func accept_chance(price: int, base: int, tolerance: float) -> float:
	if base <= 0:
		return 0.0
	var ratio := float(price) / float(base)
	return clampf((tolerance + 0.35 - ratio) / 0.8, 0.03, 0.97)


## Simulates one 10-minute tick. Returns event dictionaries (also emitted
## as signals) for the interior view and the tests.
func tick(minutes: int, weekday: int, weather: int, season: int, player_inside: bool,
		wallet: Wallet, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if not restored:
		return events
	# customers left waiting too long pay at the cash box and leave
	for sale in pending.duplicate():
		if int(sale["due"]) <= minutes:
			pending.erase(sale)
			events.append(_complete_sale(sale, false, wallet))
	var hours: Dictionary = config().get("hours", {})
	if not is_open or minutes < int(hours.get("open", 540)) or minutes >= int(hours.get("close", 1020)):
		return events
	if not has_stock() or rng.randf() >= customer_rate(weather, weekday):
		return events
	var archetype := _pick_archetype(rng)
	var customer := {"id": _next_id, "archetype": str(archetype["id"])}
	_next_id += 1
	today["customers"] = int(today["customers"]) + 1
	customer_arrived.emit(customer)
	events.append({"type": "arrival", "customer": customer})

	var stocked: Array[int] = []
	var liked: Array[int] = []
	var wants: Array = archetype.get("likes", [])
	for i in slots.size():
		if int(slots[i]["count"]) <= 0:
			continue
		stocked.append(i)
		for tag in _item_likes(slots[i]["item"]):
			if wants.has(tag):
				liked.append(i)
				break
	var choices := liked if not liked.is_empty() else stocked
	if not wants.is_empty() and liked.is_empty() and rng.randf() < 0.5:
		events.append(_leave(customer, "nothing_liked", -1))
		return events
	var index: int = choices[rng.randi_range(0, choices.size() - 1)]
	var slot := slots[index]
	customer["slot"] = index
	var item_id: StringName = slot["item"]
	var base := base_value(item_id)
	var tolerance := float(archetype.get("tolerance", 1.15)) + _bonus("tolerance") + stars() * 0.02
	if ItemRegistry.item(item_id).category == ItemData.Category.BOUQUET:
		tolerance += _bonus("bouquet_tolerance")
		var recipe := BouquetBook.recipe(item_id)
		if recipe.has("season") and int(recipe["season"]) == season:
			tolerance += 0.1
	if rng.randf() >= accept_chance(int(slot["price"]), base, tolerance):
		var greedy := float(slot["price"]) / float(base) > GREEDY_RATIO
		if greedy:
			add_reputation(-1)
		events.append(_leave(customer, "too_expensive" if greedy else "browsed", index))
		return events
	slot["count"] = int(slot["count"]) - 1
	var sale := {"customer": customer, "item": item_id, "price": int(slot["price"]), "base": base,
		"due": minutes + SERVE_WINDOW, "slot": index}
	if int(slot["count"]) <= 0:
		slot["item"] = &""
		slot["count"] = 0
	changed.emit()
	if player_inside:
		pending.append(sale)
		events.append({"type": "waiting", "sale": sale})
	else:
		events.append(_complete_sale(sale, false, wallet))
	return events


func _leave(customer: Dictionary, reason: String, slot: int) -> Dictionary:
	customer["reason"] = reason
	customer["slot"] = slot
	customer["bought"] = false
	customer_left.emit(customer)
	return {"type": "left", "customer": customer}


func has_waiting() -> bool:
	return not pending.is_empty()


## Serves the first customer at the counter (tip + extra reputation).
func serve_next(wallet: Wallet) -> Dictionary:
	if pending.is_empty():
		return {}
	var sale: Dictionary = pending.pop_front()
	return _complete_sale(sale, true, wallet)["sale"]


func _complete_sale(sale: Dictionary, served: bool, wallet: Wallet) -> Dictionary:
	var tip := int(round(int(sale["price"]) * TIP_RATE)) if served else 0
	wallet.add(int(sale["price"]) + tip)
	var rep := 0
	if float(sale["price"]) / maxf(float(sale["base"]), 1.0) <= FAIR_RATIO:
		rep += 1
	if served:
		rep += 2
	var recipe := BouquetBook.recipe(sale["item"])
	if not recipe.is_empty():
		rep += int(recipe.get("reputation", 1))
	add_reputation(rep)
	sale["tip"] = tip
	sale["served"] = served
	today["sales"] = int(today["sales"]) + 1
	today["income"] = int(today["income"]) + int(sale["price"]) + tip
	today["tips"] = int(today["tips"]) + tip
	totals["sales"] = int(totals["sales"]) + 1
	totals["income"] = int(totals["income"]) + int(sale["price"]) + tip
	(sale["customer"] as Dictionary)["bought"] = true
	sale_completed.emit(sale)
	customer_left.emit(sale["customer"])
	return {"type": "sale", "sale": sale}


# ---------------------------------------------------------------- orders ---

## Daily bookkeeping: settles waiting customers, expires and creates orders.
## Returns a summary for the morning banner.
func end_day(wallet: Wallet, total_day: int, weekday: int, season: int, rng: RandomNumberGenerator) -> Dictionary:
	for sale in pending.duplicate():
		pending.erase(sale)
		_complete_sale(sale, false, wallet)
	var summary := today.duplicate()
	summary["expired"] = 0
	var penalty := int((config().get("orders", {}) as Dictionary).get("expire_penalty", 3))
	for order in orders.duplicate():
		if int(order["deadline"]) < total_day:
			orders.erase(order)
			add_reputation(-penalty)
			summary["expired"] = int(summary["expired"]) + 1
	summary["new_orders"] = generate_orders(total_day, weekday, season, rng)
	today = {"sales": 0, "income": 0, "customers": 0, "tips": 0}
	changed.emit()
	return summary


func generate_orders(total_day: int, weekday: int, season: int, rng: RandomNumberGenerator) -> int:
	if not restored:
		return 0
	var cfg: Dictionary = config().get("orders", {})
	var wanted := (1 if rng.randf() < 0.6 else 0) + (1 if weekday == 0 else 0)
	var created := 0
	for i in wanted:
		if orders.size() >= int(cfg.get("max_active", 3)):
			break
		var entry := _pick_order_entry(cfg.get("pool", []), season, rng)
		if entry.is_empty():
			break
		var item_id := StringName(str(entry["item"]))
		var count := rng.randi_range(int(entry["count"][0]), int(entry["count"][1]))
		var rep_range: Array = cfg.get("reputation", [8, 20])
		var days: Array = cfg.get("days", [3, 6])
		var names: Array = cfg.get("customers", ["?"])
		var notes: Array = cfg.get("notes", [""])
		orders.append({
			"id": _next_id, "item": item_id, "count": count,
			"customer": str(names[rng.randi_range(0, names.size() - 1)]),
			"note": str(notes[rng.randi_range(0, notes.size() - 1)]),
			"reward": int(round(base_value(item_id) * count * float(cfg.get("reward_multiplier", 1.5)))),
			"reputation": rng.randi_range(int(rep_range[0]), int(rep_range[1])),
			"deadline": total_day + rng.randi_range(int(days[0]), int(days[1])),
		})
		_next_id += 1
		created += 1
	if created > 0:
		changed.emit()
	return created


func _pick_order_entry(pool: Array, season: int, rng: RandomNumberGenerator) -> Dictionary:
	var options: Array[Dictionary] = []
	var total := 0
	for e: Dictionary in pool:
		if stars() < int(e.get("min_stars", 0)):
			continue
		if e.has("seasons") and not JsonUtil.has_int(e["seasons"], season):
			continue
		options.append(e)
		total += int(e.get("weight", 1))
	if options.is_empty():
		return {}
	var pick := rng.randi_range(1, total)
	for e in options:
		pick -= int(e.get("weight", 1))
		if pick <= 0:
			return e
	return options[0]


func order_by_id(order_id: int) -> Dictionary:
	for o in orders:
		if int(o["id"]) == order_id:
			return o
	return {}


func can_deliver(order: Dictionary, inventory: Inventory) -> bool:
	return not order.is_empty() and inventory.count_of(order["item"]) >= int(order["count"])


func deliver_order(order_id: int, wallet: Wallet, inventory: Inventory) -> bool:
	var order := order_by_id(order_id)
	if not can_deliver(order, inventory):
		return false
	inventory.remove_item(order["item"], int(order["count"]))
	wallet.add(int(order["reward"]))
	add_reputation(int(order["reputation"]))
	orders.erase(order)
	totals["orders"] = int(totals.get("orders", 0)) + 1
	changed.emit()
	return true


# ------------------------------------------------------ upgrades / decor ---

func _find_def(list_key: String, id: String) -> Dictionary:
	for d: Dictionary in config().get(list_key, []):
		if str(d["id"]) == id:
			return d
	return {}


## "owned", "locked" (stars), "available" or "unaffordable".
func purchase_state(list_key: String, id: String, wallet: Wallet, inventory: Inventory) -> String:
	var def := _find_def(list_key, id)
	var owned: Dictionary = upgrades if list_key == "upgrades" else decorations
	if owned.has(id):
		return "owned"
	if stars() < int(def.get("min_stars", 0)):
		return "locked"
	if not can_afford(int(def.get("cost", 0)), def.get("items", []), wallet, inventory):
		return "unaffordable"
	return "available"


func buy(list_key: String, id: String, wallet: Wallet, inventory: Inventory) -> bool:
	if not restored or purchase_state(list_key, id, wallet, inventory) != "available":
		return false
	var def := _find_def(list_key, id)
	_pay(int(def.get("cost", 0)), def.get("items", []), wallet, inventory)
	if list_key == "upgrades":
		upgrades[id] = true
	else:
		decorations[id] = true
	_ensure_slots()
	changed.emit()
	return true


# --------------------------------------------------------------- crafting ---

## Crafts a bouquet from 3 inventory items. Returns {} on failure, else
## {"recipe": Dictionary, "new": bool (first time)}.
func craft(items: Array[StringName], inventory: Inventory) -> Dictionary:
	var recipe := BouquetBook.find(items)
	if recipe.is_empty():
		return {}
	var needed := {}
	for id in items:
		needed[id] = int(needed.get(id, 0)) + 1
	for id: StringName in needed:
		if inventory.count_of(id) < int(needed[id]):
			return {}
	for id: StringName in needed:
		inventory.remove_item(id, int(needed[id]))
	var bouquet := StringName(str(recipe["id"]))
	if inventory.add_item(bouquet, 1) > 0:
		for id: StringName in needed:
			inventory.add_item(id, int(needed[id]))
		return {}
	var first := not known_recipes.has(str(recipe["id"]))
	known_recipes[str(recipe["id"])] = true
	totals["bouquets"] = int(totals.get("bouquets", 0)) + 1
	changed.emit()
	return {"recipe": recipe, "new": first}


# ------------------------------------------------------------------- save ---

func to_dict() -> Dictionary:
	var slot_data: Array = []
	for s in slots:
		slot_data.append({"item": String(s["item"]), "count": int(s["count"]), "price": int(s["price"])})
	var order_data: Array = []
	for o in orders:
		var copy := o.duplicate()
		copy["item"] = String(o["item"])
		order_data.append(copy)
	return {
		"restored": restored, "open": is_open, "reputation": reputation,
		"upgrades": upgrades.keys(), "decorations": decorations.keys(),
		"slots": slot_data, "orders": order_data, "recipes": known_recipes.keys(),
		"totals": totals.duplicate(), "next_id": _next_id,
	}


## Restores saved state; invalid entries are dropped. Returns issue count.
func load_dict(data: Dictionary) -> int:
	reset()
	var issues := 0
	restored = bool(data.get("restored", false))
	is_open = bool(data.get("open", false))
	reputation = clampi(int(data.get("reputation", 0)), 0, int(config().get("max_reputation", 1000)))
	for id in data.get("upgrades", []):
		if _find_def("upgrades", str(id)).is_empty():
			issues += 1
		else:
			upgrades[str(id)] = true
	for id in data.get("decorations", []):
		if _find_def("decorations", str(id)).is_empty():
			issues += 1
		else:
			decorations[str(id)] = true
	if restored:
		_ensure_slots()
	var saved_slots: Array = data.get("slots", [])
	for i in mini(saved_slots.size(), slots.size()):
		var s: Variant = saved_slots[i]
		if typeof(s) != TYPE_DICTIONARY:
			issues += 1
			continue
		var id := StringName(str(s.get("item", "")))
		var count := int(s.get("count", 0))
		if id == &"" or count <= 0:
			continue
		if not can_display(id):
			issues += 1
			continue
		slots[i] = {"item": id, "count": mini(count, int(config().get("slot_capacity", 10))),
			"price": clampi(int(s.get("price", 0)), ceili(base_value(id) * MIN_PRICE_RATIO), floori(base_value(id) * MAX_PRICE_RATIO))}
	for o in data.get("orders", []):
		if typeof(o) != TYPE_DICTIONARY or not ItemRegistry.has_item(StringName(str(o.get("item", "")))):
			issues += 1
			continue
		var order: Dictionary = (o as Dictionary).duplicate()
		order["item"] = StringName(str(o["item"]))
		for key in ["id", "count", "reward", "reputation", "deadline"]:
			order[key] = int(order.get(key, 0))
		orders.append(order)
	for id in data.get("recipes", []):
		if BouquetBook.recipe(StringName(str(id))).is_empty():
			issues += 1
		else:
			known_recipes[str(id)] = true
	var t: Variant = data.get("totals", {})
	if typeof(t) == TYPE_DICTIONARY:
		for key in totals:
			totals[key] = maxi(int(t.get(key, 0)), 0)
	_next_id = maxi(int(data.get("next_id", 1)), 1)
	changed.emit()
	return issues
