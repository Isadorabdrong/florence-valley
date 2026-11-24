class_name DecorSpot
extends Node2D
## A spot in the flower shop where a bought decoration or upgrade appears.

const TEXTURES := {
	"deco_vase": preload("res://assets/objects/deco_vase.png"),
	"deco_garland": preload("res://assets/objects/deco_garland.png"),
	"deco_chandelier": preload("res://assets/objects/deco_chandelier.png"),
	"deco_fountain": preload("res://assets/objects/deco_fountain.png"),
	"diffuser": preload("res://assets/objects/diffuser.png"),
}
## Hanging/wall items are drawn higher than floor items.
const LIFT := {"deco_garland": 18, "deco_chandelier": 30}

var decor_id := ""

@onready var _sprite: Sprite2D = $Sprite


func setup(id: String) -> void:
	decor_id = id
	_sprite.texture = TEXTURES.get(id)
	if _sprite.texture:
		var size := _sprite.texture.get_size()
		_sprite.offset = Vector2(-size.x / 2.0, -size.y - int(LIFT.get(id, 0)))
	z_index = 3 if LIFT.has(id) else 0
	if not GameState.florist.changed.is_connected(refresh):
		GameState.florist.changed.connect(refresh)
	refresh()


func refresh() -> void:
	var shop := GameState.florist
	visible = shop.decorations.has(decor_id) or shop.upgrades.has(decor_id)
