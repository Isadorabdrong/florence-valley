class_name UiKit
extends RefCounted
## Small helpers to build list rows in code with the game's look.


static func label(text: String, size: int = 10, color: Color = Color("5b3a4f"), expand: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	if expand:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


static func wrap_label(text: String, size: int = 9, width: float = 300.0) -> Label:
	var l := label(text, size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	return l


static func button(text: String, callback: Callable, enabled: bool = true, size: int = 9) -> Button:
	var b := Button.new()
	b.text = text
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.add_theme_font_size_override(&"font_size", size)
	b.disabled = not enabled
	b.pressed.connect(callback)
	return b


static func icon(id: StringName, size: int = 16) -> TextureRect:
	var t := TextureRect.new()
	t.texture = ItemRegistry.icon(id)
	t.custom_minimum_size = Vector2(size, size)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return t


static func row(separation: int = 6) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", separation)
	return h


static func stars(count: int, total: int = 5) -> String:
	return "★".repeat(count) + "☆".repeat(maxi(total - count, 0))


static func clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


## "250 ✿ + 3 Argila" style cost text, with what the player owns.
static func cost_text(money: int, items: Array) -> String:
	var parts := PackedStringArray()
	if money > 0:
		parts.append("%s ✿" % Wallet.format(money))
	for entry: Array in items:
		var id := StringName(str(entry[0]))
		parts.append("%d %s (%d)" % [int(entry[1]), ItemRegistry.item(id).display_name(), GameState.inventory.count_of(id)])
	return " + ".join(parts)


## Soft fade-in when a panel opens (keeps working while the game is paused).
static func pop_in(control: CanvasItem, seconds: float = 0.14) -> void:
	if not control.is_inside_tree():
		return
	control.modulate.a = 0.0
	var tween := control.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(control, "modulate:a", 1.0, seconds).set_ease(Tween.EASE_OUT)
