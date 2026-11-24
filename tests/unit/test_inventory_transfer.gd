extends TestCase

var a: Inventory
var b: Inventory


func before_each() -> void:
	a = Inventory.new(4)
	b = Inventory.new(4)


func test_transfer_to_empty_slot() -> void:
	a.add_item(&"stone", 5)
	assert_true(Inventory.transfer(a, 0, b, 2))
	assert_true(a.is_slot_empty(0))
	assert_eq(b.get_slot(2), {"id": &"stone", "count": 5})


func test_transfer_merges_same_item() -> void:
	a.add_item(&"stone", 90)
	b.add_item(&"stone", 20)
	assert_true(Inventory.transfer(a, 0, b, 0))
	assert_eq(b.get_slot(0)["count"], 99)
	assert_eq(a.get_slot(0)["count"], 11, "remainder stays")


func test_transfer_swaps_different_items() -> void:
	a.add_item(&"stone", 3)
	b.add_item(&"fiber", 7)
	assert_true(Inventory.transfer(a, 0, b, 0))
	assert_eq(a.item_at(0), &"fiber")
	assert_eq(b.item_at(0), &"stone")


func test_transfer_from_empty_does_nothing() -> void:
	assert_false(Inventory.transfer(a, 0, b, 0))


func test_split_and_take_put() -> void:
	a.add_item(&"fiber", 9)
	assert_eq(a.split_slot(0), 1)
	assert_eq(a.get_slot(0)["count"], 5)
	assert_eq(a.get_slot(1)["count"], 4)
	assert_eq(a.split_slot(3), -1, "empty slot")
	var taken := a.take_slot(1)
	assert_eq(taken, {"id": &"fiber", "count": 4})
	assert_true(a.is_slot_empty(1))
	assert_true(a.put_in_slot(1, &"fiber", 4))
	assert_false(a.put_in_slot(1, &"fiber", 4), "slot occupied")
