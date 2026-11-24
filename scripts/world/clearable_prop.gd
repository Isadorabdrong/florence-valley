class_name ClearableProp
extends Node2D
## A map object the player can remove with a tool (rocks, weeds).
## FarmActionResolver reads `object_kind`; FarmController calls hit().

signal cleared

@export var object_kind: StringName = &"rock"
@export_range(1, 10) var hits_required := 1
@export var drop_item: StringName = &""
@export_range(0, 99) var drop_count := 1

var _hits := 0

@onready var _sprite: Sprite2D = $Sprite


## Applies one tool hit. Returns true when the object is destroyed.
func hit() -> bool:
	_hits += 1
	if _hits >= hits_required:
		cleared.emit()
		return true
	_shake()
	return false


func hits_left() -> int:
	return maxi(hits_required - _hits, 0)


func _shake() -> void:
	var tween := create_tween()
	for offset in [2.0, -2.0, 1.0, 0.0]:
		tween.tween_property(_sprite, "position:x", offset, 0.04)
