class_name CharacterSpriteFrames
extends RefCounted
## Builds SpriteFrames from a character sheet laid out as:
##   rows: down, up, right   (left = right flipped at runtime)
##   cols: 0 idle | 1 left step | 2 contact/bob | 3 right step
## Shared by the player and (later) NPCs that use the same sheet layout.

const ROW_FOR_FACING := {"down": 0, "up": 1, "right": 2}
const WALK_SEQUENCE: Array[int] = [1, 2, 3, 2]
const IDLE_SEQUENCE: Array[int] = [0, 0, 0, 2]
const WALK_FPS := 8.0
const IDLE_FPS := 2.5


static func build(sheet: Texture2D, frame_size: Vector2i) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for facing: String in ROW_FOR_FACING:
		var row: int = ROW_FOR_FACING[facing]
		_add(frames, "idle_" + facing, sheet, frame_size, row, IDLE_SEQUENCE, IDLE_FPS)
		_add(frames, "walk_" + facing, sheet, frame_size, row, WALK_SEQUENCE, WALK_FPS)
	return frames


static func _add(frames: SpriteFrames, anim: String, sheet: Texture2D, size: Vector2i,
		row: int, sequence: Array[int], fps: float) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, true)
	for col in sequence:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(col * size.x, row * size.y, size.x, size.y)
		frames.add_frame(anim, atlas)
