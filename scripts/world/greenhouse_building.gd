class_name GreenhouseBuilding
extends InteractableProp
## The farm greenhouse: ruined until restored (GameState.restore_greenhouse).

const RUINED := preload("res://assets/buildings/greenhouse_ruined.png")
const RESTORED := preload("res://assets/buildings/greenhouse.png")

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	refresh()


func refresh() -> void:
	_sprite.texture = RESTORED if GameState.greenhouse_restored else RUINED
