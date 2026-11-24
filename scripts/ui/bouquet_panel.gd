class_name BouquetPanel
extends Control
## The flower shop workbench: pick three items to combine into a bouquet.
## The result is previewed before crafting; recipes are discovered by
## crafting them and listed in the recipe book.

signal closed

var _picked: Array[StringName] = []

@onready var _items: HFlowContainer = %IngredientList
@onready var _slots: HBoxContainer = %PickedSlots
@onready var _preview: Label = %BouquetPreview
@onready var _preview_icon: TextureRect = %BouquetIcon
@onready var _craft: Button = %CraftButton
@onready var _book: VBoxContainer = %RecipeBook
@onready var _close: Button = %CloseWorkbench


func _ready() -> void:
	visible = false
	_craft.pressed.connect(craft)
	_close.pressed.connect(close)


func open() -> void:
	_picked.clear()
	visible = true
	UiKit.pop_in(self)
	_rebuild()
	_close.grab_focus()
	AudioManager.play(&"open", -6.0)


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(InputBindings.PAUSE)):
		close()
		get_viewport().set_input_as_handled()


## Items that can go into a bouquet (anything tagged flower/wild/decor/rare/greenery).
static func is_ingredient(id: StringName) -> bool:
	var item := ItemRegistry.item(id)
	if item == null or item.category == ItemData.Category.BOUQUET:
		return false
	for tag in ["flower", "wild", "decor", "rare", "greenery"]:
		if item.tags.has(tag):
			return true
	return false


func pick(id: StringName) -> void:
	if _picked.size() >= BouquetBook.INGREDIENTS:
		return
	var used := _picked.count(id)
	if GameState.inventory.count_of(id) <= used:
		return
	_picked.append(id)
	_rebuild()


func unpick(index: int) -> void:
	if index < _picked.size():
		_picked.remove_at(index)
		_rebuild()


func preview() -> Dictionary:
	return BouquetBook.find(_picked) if _picked.size() == BouquetBook.INGREDIENTS else {}


func craft() -> Dictionary:
	var result := GameState.florist.craft(_picked, GameState.inventory)
	if result.is_empty():
		AudioManager.play(&"error", -6.0)
		return result
	var name := ItemRegistry.item(StringName(str(result["recipe"]["id"]))).display_name()
	GameState.record("craft", str(result["recipe"]["id"]))
	AudioManager.play(&"harvest")
	_preview.text = (tr("WORKBENCH_NEW_RECIPE") if result["new"] else tr("WORKBENCH_MADE")) % name
	_picked.clear()
	_rebuild(false)
	return result


func _rebuild(update_preview: bool = true) -> void:
	UiKit.clear(_items)
	var seen := {}
	for i in GameState.inventory.size():
		var id := GameState.inventory.item_at(i)
		if id == &"" or seen.has(id) or not is_ingredient(id):
			continue
		seen[id] = true
		var left := GameState.inventory.count_of(id) - _picked.count(id)
		var b := UiKit.button("×%d" % left, pick.bind(id), left > 0)
		b.icon = ItemRegistry.icon(id)
		b.tooltip_text = ItemRegistry.item(id).display_name()
		_items.add_child(b)
	if seen.is_empty():
		_items.add_child(UiKit.label(tr("WORKBENCH_NO_FLOWERS"), 9, Color("b0465f")))
	UiKit.clear(_slots)
	for i in BouquetBook.INGREDIENTS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(30, 30)
		if i < _picked.size():
			b.icon = ItemRegistry.icon(_picked[i])
			b.tooltip_text = ItemRegistry.item(_picked[i]).display_name()
			b.pressed.connect(unpick.bind(i))
		else:
			b.text = "+"
			b.disabled = true
		_slots.add_child(b)
	var recipe := preview()
	_craft.disabled = recipe.is_empty()
	_preview_icon.texture = ItemRegistry.icon(StringName(str(recipe["id"]))) if not recipe.is_empty() else null
	if update_preview:
		if _picked.size() < BouquetBook.INGREDIENTS:
			_preview.text = tr("WORKBENCH_PICK") % (BouquetBook.INGREDIENTS - _picked.size())
		elif recipe.is_empty():
			_preview.text = tr("WORKBENCH_NO_MATCH")
		else:
			var item := ItemRegistry.item(StringName(str(recipe["id"])))
			var known := GameState.florist.known_recipes.has(str(recipe["id"]))
			_preview.text = tr("WORKBENCH_RESULT") % [item.display_name() if known else tr("WORKBENCH_SURPRISE"),
				tr(BouquetBook.TYPE_KEYS[str(recipe["type"])]), Wallet.format(item.sell_price),
				Wallet.format(BouquetBook.ingredients_value(_picked))]
	_build_book()


func _build_book() -> void:
	UiKit.clear(_book)
	for r in BouquetBook.recipes():
		var id := StringName(str(r["id"]))
		var known := GameState.florist.known_recipes.has(str(r["id"]))
		var row := UiKit.row(4)
		var icon := UiKit.icon(id, 14)
		icon.modulate = Color.WHITE if known else Color(0.2, 0.15, 0.2, 0.5)
		row.add_child(icon)
		var text := ItemRegistry.item(id).display_name() if known else "??? (%s)" % tr(BouquetBook.TYPE_KEYS[str(r["type"])])
		row.add_child(UiKit.label(text, 8, Color("5b3a4f") if known else Color("9c8f94"), true))
		_book.add_child(row)
		if known:
			_book.add_child(UiKit.label("   " + _ingredients_text(r), 7, Color("9c5f7e")))


func _ingredients_text(r: Dictionary) -> String:
	var parts := PackedStringArray()
	for ing: Dictionary in r.get("ingredients", []):
		var n := int(ing.get("count", 1))
		var what := ""
		if ing.has("item"):
			what = ItemRegistry.item(StringName(str(ing["item"]))).display_name()
		elif ing.has("any"):
			var names := PackedStringArray()
			for i in ing["any"]:
				names.append(ItemRegistry.item(StringName(str(i))).display_name())
			what = tr("WORKBENCH_OR").join(names)
		else:
			what = tr("TAG_" + str(ing["tag"]).to_upper())
		parts.append("%d× %s" % [n, what])
	return " + ".join(parts)
