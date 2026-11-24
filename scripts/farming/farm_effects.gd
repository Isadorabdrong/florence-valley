class_name FarmEffects
extends RefCounted
## Small one-shot visual effects for farming feedback.

const TEXTURES := {
	&"dust": preload("res://assets/effects/dust.png"),
	&"water": preload("res://assets/effects/droplet.png"),
	&"leaf": preload("res://assets/effects/leaf.png"),
	&"sparkle": preload("res://assets/effects/sparkle.png"),
	&"petal": preload("res://assets/environments/petal.png"),
}


## Spawns a burst of particles at `pos` (local to `parent`).
static func burst(parent: Node, pos: Vector2, kind: StringName, amount: int = 10) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = TEXTURES.get(kind, TEXTURES[&"dust"])
	p.position = pos
	p.amount = amount
	p.one_shot = true
	p.explosiveness = 0.85
	p.lifetime = 0.6
	p.direction = Vector2.UP
	p.spread = 70.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 45.0
	p.gravity = Vector2(0, 140)
	p.angle_min = -90.0
	p.angle_max = 90.0
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.3
	match kind:
		&"water":
			p.direction = Vector2.DOWN
			p.spread = 25.0
			p.initial_velocity_min = 10.0
			p.initial_velocity_max = 25.0
			p.gravity = Vector2(0, 220)
			p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			p.emission_rect_extents = Vector2(6, 2)
			p.position += Vector2(0, -10)
		&"sparkle":
			p.gravity = Vector2(0, -20)
			p.initial_velocity_min = 8.0
			p.initial_velocity_max = 20.0
			p.lifetime = 0.8
			p.spread = 180.0
		&"leaf", &"petal":
			p.gravity = Vector2(0, 60)
			p.lifetime = 0.9
			p.angular_velocity_min = -200.0
			p.angular_velocity_max = 200.0
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p


## Shows the tool icon swinging over the target cell.
static func tool_swing(parent: Node, pos: Vector2, icon: Texture2D, from_left: bool) -> void:
	if icon == null:
		return
	var s := Sprite2D.new()
	s.texture = icon
	s.position = pos + Vector2(0, -10)
	s.rotation = -0.9 if from_left else 0.9
	s.z_index = 5
	parent.add_child(s)
	var tween := s.create_tween()
	tween.tween_property(s, "rotation", 0.5 if from_left else -0.5, 0.14).set_trans(Tween.TRANS_BACK)
	tween.tween_property(s, "modulate:a", 0.0, 0.12)
	tween.tween_callback(s.queue_free)


## Little squash-and-stretch "pop" used when a crop changes stage.
static func pop(node: Node2D) -> void:
	if not node.is_inside_tree():
		return
	node.scale = Vector2(1.25, 0.8)
	var tween := node.create_tween()
	tween.tween_property(node, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
