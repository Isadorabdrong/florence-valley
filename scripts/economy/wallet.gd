class_name Wallet
extends RefCounted
## The player's money, in Pétalas (✿).

signal changed(amount: int, delta: int)

const MAX_AMOUNT := 99_999_999

var amount := 0


func can_afford(cost: int) -> bool:
	return cost >= 0 and amount >= cost


func add(value: int) -> bool:
	if value <= 0:
		return false
	var before := amount
	amount = mini(amount + value, MAX_AMOUNT)
	changed.emit(amount, amount - before)
	return true


func spend(cost: int) -> bool:
	if cost <= 0 or not can_afford(cost):
		return false
	amount -= cost
	changed.emit(amount, -cost)
	return true


func set_amount(value: int) -> void:
	var before := amount
	amount = clampi(value, 0, MAX_AMOUNT)
	changed.emit(amount, amount - before)


static func format(value: int) -> String:
	var s := str(absi(value))
	var out := ""
	while s.length() > 3:
		out = "." + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if value < 0 else "") + s + out
