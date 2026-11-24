class_name FloristBuilding
extends InteractableProp
## The village flower shop: shows the ruined building until it is restored.

const RUINED := preload("res://assets/buildings/old_florist.png")
const RESTORED := preload("res://assets/buildings/florist.png")

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	GameState.florist.changed.connect(refresh)
	refresh()


func refresh() -> void:
	_sprite.texture = RESTORED if GameState.florist.restored else RUINED
