class_name Inventory
extends RefCounted
## Slot-based inventory with stacking. Pure data: the UI listens to `changed`.
## A slot is either {} (empty) or {"id": StringName, "count": int}.
## The first HOTBAR_SIZE slots form the hotbar.

signal changed(slot_index: int) ## -1 when several slots changed

const DEFAULT_SIZE := 36

var _slots: Array[Dictionary] = []
## (StringName) -> int. Unset = ItemRegistry.max_stack; tests may inject.
var max_stack_lookup: Callable


func _init(slot_count: int = DEFAULT_SIZE) -> void:
	_slots.resize(maxi(slot_count, 1))
	for i in _slots.size():
		_slots[i] = {}


func size() -> int:
	return _slots.size()


func clear() -> void:
	for i in _slots.size():
		_slots[i] = {}
	changed.emit(-1)


func get_slot(index: int) -> Dictionary:
	if index < 0 or index >= _slots.size():
		return {}
	return _slots[index].duplicate()


func item_at(index: int) -> StringName:
	return get_slot(index).get("id", &"")


func is_slot_empty(index: int) -> bool:
	return get_slot(index).is_empty()


func count_of(id: StringName) -> int:
	var total := 0
	for slot in _slots:
		if slot.get("id", &"") == id:
			total += int(slot["count"])
	return total


func first_slot_of(id: StringName) -> int:
	for i in _slots.size():
		if _slots[i].get("id", &"") == id:
			return i
	return -1


## How many more units of `id` fit (existing stacks + empty slots).
func space_for(id: StringName) -> int:
	var stack := _max_stack(id)
	if stack <= 0:
		return 0
	var space := 0
	for slot in _slots:
		if slot.is_empty():
			space += stack
		elif slot["id"] == id:
			space += stack - int(slot["count"])
	return space


func can_add(id: StringName, count: int) -> bool:
	return count <= space_for(id)


## Adds items, filling existing stacks first. Returns how many did NOT fit.
func add_item(id: StringName, count: int) -> int:
	var stack := _max_stack(id)
	if count <= 0:
		return 0
	if stack <= 0:
		push_error("Inventory: unknown item %s" % id)
		return count
	var left := count
	for i in _slots.size():
		if left == 0:
			break
		var slot := _slots[i]
		if not slot.is_empty() and slot["id"] == id and int(slot["count"]) < stack:
			var moved := mini(stack - int(slot["count"]), left)
			slot["count"] = int(slot["count"]) + moved
			left -= moved
			changed.emit(i)
	for i in _slots.size():
		if left == 0:
			break
		if _slots[i].is_empty():
			var moved := mini(stack, left)
			_slots[i] = {"id": id, "count": moved}
			left -= moved
			changed.emit(i)
	return left


## Removes `count` units across stacks (last slots first, so the hotbar
## keeps its items). All-or-nothing: returns false and changes nothing if
## there are not enough.
func remove_item(id: StringName, count: int) -> bool:
	if count <= 0:
		return true
	if count_of(id) < count:
		return false
	var left := count
	for i in range(_slots.size() - 1, -1, -1):
		if left == 0:
			break
		var slot := _slots[i]
		if slot.get("id", &"") == id:
			left -= remove_from_slot(i, left)
	return true


## Removes up to `count` units from one slot. Returns how many were removed.
func remove_from_slot(index: int, count: int) -> int:
	if index < 0 or index >= _slots.size() or _slots[index].is_empty():
		return 0
	var slot := _slots[index]
	var removed := mini(count, int(slot["count"]))
	slot["count"] = int(slot["count"]) - removed
	if int(slot["count"]) <= 0:
		_slots[index] = {}
	changed.emit(index)
	return removed


## Swaps two slots, or merges them when they hold the same item.
func move_slot(from: int, to: int) -> void:
	if from == to or from < 0 or to < 0 or from >= _slots.size() or to >= _slots.size():
		return
	var a := _slots[from]
	var b := _slots[to]
	if not a.is_empty() and not b.is_empty() and a["id"] == b["id"]:
		var stack := _max_stack(a["id"])
		var moved := mini(stack - int(b["count"]), int(a["count"]))
		b["count"] = int(b["count"]) + moved
		a["count"] = int(a["count"]) - moved
		if int(a["count"]) <= 0:
			_slots[from] = {}
	else:
		_slots[from] = b
		_slots[to] = a
	changed.emit(-1)


## Moves a stack between two inventories (or within one): merges into a
## stack of the same item (up to its max), otherwise swaps the two slots.
## Returns true if anything changed.
static func transfer(src: Inventory, from: int, dst: Inventory, to: int) -> bool:
	if src == dst:
		if from == to or src.is_slot_empty(from):
			return false
		src.move_slot(from, to)
		return true
	if src.is_slot_empty(from) or to < 0 or to >= dst.size():
		return false
	var a := src.get_slot(from)
	var b := dst.get_slot(to)
	if not b.is_empty() and b["id"] == a["id"]:
		var room := dst._max_stack(a["id"]) - int(b["count"])
		var moved := mini(room, int(a["count"]))
		if moved <= 0:
			return false
		dst._set_slot(to, a["id"], int(b["count"]) + moved)
		src._set_slot(from, a["id"], int(a["count"]) - moved)
		return true
	dst._set_slot(to, a["id"], a["count"])
	if b.is_empty():
		src._set_slot(from, &"", 0)
	else:
		src._set_slot(from, b["id"], b["count"])
	return true


## Splits a stack in half into the first empty slot.
## Returns the new slot index, or -1 if it can't be split.
func split_slot(index: int) -> int:
	var slot := get_slot(index)
	if slot.is_empty() or int(slot["count"]) < 2:
		return -1
	var empty := -1
	for i in _slots.size():
		if _slots[i].is_empty():
			empty = i
			break
	if empty == -1:
		return -1
	var half := int(slot["count"]) / 2
	_set_slot(index, slot["id"], int(slot["count"]) - half)
	_set_slot(empty, slot["id"], half)
	return empty


## Empties a slot and returns what was in it.
func take_slot(index: int) -> Dictionary:
	var slot := get_slot(index)
	if not slot.is_empty():
		_set_slot(index, &"", 0)
	return slot


## Puts a stack into a specific empty slot (used to undo a discard).
func put_in_slot(index: int, id: StringName, count: int) -> bool:
	if index < 0 or index >= _slots.size() or not _slots[index].is_empty() or count <= 0:
		return false
	_set_slot(index, id, mini(count, _max_stack(id)))
	return true


func _set_slot(index: int, id: StringName, count: int) -> void:
	_slots[index] = {} if (id == &"" or count <= 0) else {"id": id, "count": count}
	changed.emit(index)


func to_dict() -> Dictionary:
	var slots: Array = []
	for slot in _slots:
		slots.append({} if slot.is_empty() else {"id": String(slot["id"]), "count": int(slot["count"])})
	return {"size": _slots.size(), "slots": slots}


## Restores saved slots. Unknown items and invalid counts are dropped.
## Returns the number of entries that had to be discarded.
func load_dict(data: Dictionary) -> int:
	var discarded := 0
	var slots: Array = data.get("slots", [])
	for i in _slots.size():
		_slots[i] = {}
		if i >= slots.size() or typeof(slots[i]) != TYPE_DICTIONARY or (slots[i] as Dictionary).is_empty():
			continue
		var id := StringName(str(slots[i].get("id", "")))
		var count := int(slots[i].get("count", 0))
		var stack := _max_stack(id)
		if stack <= 0 or count <= 0:
			discarded += 1
			continue
		_slots[i] = {"id": id, "count": mini(count, stack)}
	changed.emit(-1)
	return discarded


func _max_stack(id: StringName) -> int:
	if max_stack_lookup.is_valid():
		return int(max_stack_lookup.call(id))
	return ItemRegistry.max_stack(id)
