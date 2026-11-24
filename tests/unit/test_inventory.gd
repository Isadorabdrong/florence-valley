extends TestCase

var inv: Inventory


func before_each() -> void:
	inv = Inventory.new(4)
	inv.max_stack_lookup = func(id: StringName) -> int:
		return {&"seed": 10, &"tool": 1, &"stone": 99}.get(id, 0)


func test_add_stacks_then_fills_empty_slots() -> void:
	assert_eq(inv.add_item(&"seed", 15), 0)
	assert_eq(inv.get_slot(0), {"id": &"seed", "count": 10})
	assert_eq(inv.get_slot(1), {"id": &"seed", "count": 5})
	assert_eq(inv.add_item(&"seed", 3), 0)
	assert_eq(inv.get_slot(1)["count"], 8, "tops up the existing stack first")


func test_add_returns_leftover_when_full() -> void:
	assert_eq(inv.add_item(&"tool", 6), 2)
	assert_eq(inv.count_of(&"tool"), 4)
	assert_eq(inv.space_for(&"tool"), 0)
	assert_false(inv.can_add(&"stone", 1))


func test_unknown_item_is_rejected() -> void:
	assert_eq(inv.add_item(&"???", 3), 3)
	assert_eq(inv.count_of(&"???"), 0)


func test_remove_is_all_or_nothing() -> void:
	inv.add_item(&"seed", 12)
	assert_false(inv.remove_item(&"seed", 13))
	assert_eq(inv.count_of(&"seed"), 12, "nothing removed on failure")
	assert_true(inv.remove_item(&"seed", 11))
	assert_eq(inv.count_of(&"seed"), 1)
	assert_eq(inv.get_slot(0)["count"], 1, "later stacks are consumed first, hotbar slot kept")
	assert_true(inv.is_slot_empty(1))


func test_move_swaps_and_merges() -> void:
	inv.add_item(&"tool", 1)
	inv.add_item(&"seed", 4)
	inv.move_slot(0, 1)
	assert_eq(inv.item_at(0), &"seed")
	assert_eq(inv.item_at(1), &"tool")
	inv.add_item(&"seed", 10) # slot0 -> 10, rest into slot 2 (4)
	inv.move_slot(2, 0)
	assert_eq(inv.get_slot(0)["count"], 10)
	assert_eq(inv.get_slot(2)["count"], 4, "merge limited by stack size")


func test_changed_signal_fires() -> void:
	var hits: Array = []
	inv.changed.connect(func(i: int) -> void: hits.append(i))
	inv.add_item(&"stone", 1)
	assert_eq(hits, [0])


func test_dict_roundtrip_drops_invalid() -> void:
	inv.add_item(&"seed", 7)
	inv.add_item(&"tool", 1)
	var data := inv.to_dict()
	var other := Inventory.new(4)
	other.max_stack_lookup = inv.max_stack_lookup
	assert_eq(other.load_dict(data), 0)
	assert_eq(other.to_dict(), data)
	data["slots"][2] = {"id": "ghost", "count": 3}
	assert_eq(other.load_dict(data), 1, "unknown item discarded")


func after_each() -> void:
	inv.max_stack_lookup = Callable()
	inv = null
