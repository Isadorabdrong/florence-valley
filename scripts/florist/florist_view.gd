class_name FloristView
extends Node
## Brings the flower shop interior to life: configures stands and
## decoration spots, and shows customers walking in, browsing, queueing at
## the counter and leaving, mirroring the FloristShop simulation.

const CUSTOMER_SCENE := preload("res://scenes/florist/customer_npc.tscn")

var map: WorldMap
var shop: FloristShop
var _npcs: Dictionary = {} # customer id -> CustomerNPC
var _stand_cells: Dictionary = {} # stand index -> Vector2i
var _counter_cell := Vector2i.ZERO
var _door := Vector2.ZERO


func setup(world_map: WorldMap, florist: FloristShop) -> void:
	map = world_map
	shop = florist
	var spots: Dictionary = (WorldGraph.data().get("decor_spots", {}) as Dictionary).get(String(map.map_id), {})
	for key: String in spots:
		var xy := key.split(",")
		var spot := map.get_object_at(Vector2i(int(xy[0]), int(xy[1]))) as DecorSpot
		if spot:
			spot.setup(str(spots[key]))
	for y in map.layout.height:
		for x in map.layout.width:
			var cell := Vector2i(x, y)
			var data := WorldGraph.interaction(map.map_id, cell)
			match str(data.get("type", "")):
				"florist_stand":
					_stand_cells[int(data["stand"])] = cell
					var stand := map.get_object_at(cell) as DisplayStand
					if stand:
						stand.setup(int(data["stand"]))
				"florist_counter":
					_counter_cell = cell
	var entrance := WorldGraph.spawn(map.map_id, "entrance")
	_door = map.cell_anchor(entrance["cell"] + Vector2i.DOWN) + Vector2(0, -2)
	shop.customer_arrived.connect(_on_arrived)
	shop.customer_left.connect(_on_left)
	shop.sale_completed.connect(_on_sale)
	# customers already waiting when the player walks in
	for sale in shop.pending:
		var npc := _spawn(int(sale["customer"]["id"]))
		npc.position = _counter_front()
		npc.set_waiting(true)


func _exit_tree() -> void:
	if shop == null:
		return
	for sig: Signal in [shop.customer_arrived, shop.customer_left, shop.sale_completed]:
		for c in sig.get_connections():
			if c["callable"].get_object() == self:
				sig.disconnect(c["callable"])


func customer_count() -> int:
	return _npcs.size()


func _spawn(id: int) -> CustomerNPC:
	var npc := CUSTOMER_SCENE.instantiate() as CustomerNPC
	npc.position = _door
	map.entities.add_child(npc)
	npc.setup(id)
	_npcs[id] = npc
	npc.tree_exited.connect(func() -> void: _npcs.erase(id))
	return npc


func _counter_front() -> Vector2:
	return map.cell_anchor(_counter_cell + Vector2i.DOWN) + Vector2(0, -2)


func _stand_front(slot: int) -> Vector2:
	var stand := slot / DisplayStand.SLOTS_PER_STAND
	var cell: Vector2i = _stand_cells.get(stand, _counter_cell)
	return map.cell_anchor(cell + Vector2i.DOWN) + Vector2(0, -2)


func _on_arrived(customer: Dictionary) -> void:
	_spawn(int(customer["id"]))
	# The simulation decides where they go in the same tick; read it next frame.
	_route.call_deferred(customer)


func _route(customer: Dictionary) -> void:
	var npc: CustomerNPC = _npcs.get(int(customer["id"]))
	if npc == null:
		return
	var slot := int(customer.get("slot", -1))
	var browse := _stand_front(slot) if slot >= 0 else map.cell_center(map.layout.spawn_cell)
	var waiting := false
	for sale in shop.pending:
		if int(sale["customer"]["id"]) == int(customer["id"]):
			waiting = true
	if waiting:
		npc.walk([browse, _counter_front()])
		npc.arrived_at_end.connect(npc.set_waiting.bind(true), CONNECT_ONE_SHOT)
	elif not customer.get("bought", false):
		npc.walk([browse, browse + Vector2(0, -1), _door], true)


func _on_left(customer: Dictionary) -> void:
	if customer.get("bought", false):
		return # handled by _on_sale
	# _route handles the walk; nothing else to do.


func _on_sale(sale: Dictionary) -> void:
	var npc: CustomerNPC = _npcs.get(int(sale["customer"]["id"]))
	if npc == null:
		return
	npc.walk([_door], true)
