class_name DisplayStand
extends InteractableProp
## A display stand in the flower shop. Shows the items of its two slots;
## stands beyond the shop's current slot count stay hidden (upgrades).

const SLOTS_PER_STAND := 2

var stand_index := 0
var _icons: Array[Sprite2D] = []

@onready var _collision: CollisionShape2D = $Collision


func setup(index: int) -> void:
	stand_index = index
	if not GameState.florist.changed.is_connected(refresh):
		GameState.florist.changed.connect(refresh)
	refresh()


func first_slot() -> int:
	return stand_index * SLOTS_PER_STAND


func is_unlocked() -> bool:
	return first_slot() < GameState.florist.slot_count()


func refresh() -> void:
	visible = is_unlocked()
	_collision.set_deferred(&"disabled", not visible)
	for icon in _icons:
		icon.queue_free()
	_icons.clear()
	if not visible:
		return
	var shop := GameState.florist
	for k in SLOTS_PER_STAND:
		var i := first_slot() + k
		if i >= shop.slots.size() or int(shop.slots[i]["count"]) <= 0:
			continue
		var count := mini(int(shop.slots[i]["count"]), 3)
		for n in count:
			var s := Sprite2D.new()
			s.texture = ItemRegistry.icon(shop.slots[i]["item"])
			# slot 0 on the top shelf, slot 1 on the bottom one; up to 3 icons each
			s.position = Vector2(-8 + n * 6 + k * 2, -15 if k == 0 else -7)
			s.z_index = 1
			add_child(s)
			_icons.append(s)
