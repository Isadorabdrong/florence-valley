class_name ShopPanel
extends Control
## Buy / sell window for a Shop (data/shops/*.json).

signal closed

enum Tab { BUY, SELL }

const SHOP_DIR := "res://data/shops/"

var shop: Shop
var _cache: Dictionary = {}
var _tab: Tab = Tab.BUY

@onready var _title: Label = %ShopTitle
@onready var _greeting: Label = %Greeting
@onready var _money: Label = %Money
@onready var _buy_tab: Button = %BuyTab
@onready var _sell_tab: Button = %SellTab
@onready var _list: VBoxContainer = %List
@onready var _feedback: Label = %ShopFeedback
@onready var _close: Button = %CloseButton


func _ready() -> void:
	visible = false
	var group := ButtonGroup.new()
	_buy_tab.button_group = group
	_sell_tab.button_group = group
	_buy_tab.pressed.connect(_set_tab.bind(Tab.BUY))
	_sell_tab.pressed.connect(_set_tab.bind(Tab.SELL))
	_close.pressed.connect(close)
	GameState.wallet.changed.connect(_on_money_changed)


## Opens a shop by id (data/shops/<id>.json). Returns false if missing.
func open(shop_id: StringName) -> bool:
	if not _cache.has(shop_id):
		_cache[shop_id] = Shop.load_from_file(SHOP_DIR + String(shop_id) + ".json")
	shop = _cache[shop_id]
	if shop == null:
		return false
	_title.text = tr(shop.name_key)
	_greeting.text = tr(shop.greeting_key)
	_feedback.text = ""
	_on_money_changed(GameState.wallet.amount, 0)
	visible = true
	UiKit.pop_in(self)
	_buy_tab.button_pressed = true
	_set_tab(Tab.BUY)
	AudioManager.play(&"open", -6.0)
	return true


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(InputBindings.PAUSE)):
		close()
		get_viewport().set_input_as_handled()


func _on_money_changed(amount: int, _delta: int) -> void:
	_money.text = Wallet.format(amount)


func _set_tab(tab: Tab) -> void:
	_tab = tab
	_rebuild()


func _rebuild() -> void:
	for child in _list.get_children():
		child.queue_free()
	if _tab == Tab.BUY:
		var items := shop.available_items(int(GameState.calendar.season))
		var level := GameState.progression.level
		for item in items:
			var need := shop.required_level(item.id)
			var extra := UiKit.cost_text(0, shop.materials_for(item.id))
			if need > level:
				_add_row(item, item.buy_price, tr("SHOP_LEVEL_TAG") % need, [], _buy)
			elif shop.entry_for(item.id).get("replaces", &"") != &"" or item.is_placeable():
				_add_row(item, item.buy_price, extra, [[tr("SHOP_BUY"), 1]], _buy)
			else:
				_add_row(item, item.buy_price, extra, [[tr("SHOP_BUY"), 1], ["×5", 5]], _buy)
		if items.is_empty():
			_add_note(tr("SHOP_NOTHING_TODAY"))
	else:
		var seen := {}
		for i in GameState.inventory.size():
			var id := GameState.inventory.item_at(i)
			if id == &"" or seen.has(id) or shop.sell_price(id) <= 0:
				continue
			seen[id] = true
			var count := GameState.inventory.count_of(id)
			_add_row(ItemRegistry.item(id), shop.sell_price(id), "×%d" % count,
				[[tr("SHOP_SELL"), 1], [tr("SHOP_SELL_ALL"), count]], _sell)
		if seen.is_empty():
			_add_note(tr("SHOP_NOTHING_TO_SELL"))


func _add_note(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", 9)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_list.add_child(label)


func _add_row(item: ItemData, price: int, count_text: String, buttons: Array, handler: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	row.tooltip_text = ItemRegistry.describe(item.id)
	var icon := TextureRect.new()
	icon.texture = ItemRegistry.icon(item.id)
	icon.custom_minimum_size = Vector2(16, 16)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	row.add_child(icon)
	var name := Label.new()
	name.text = item.display_name() + ("  " + count_text if count_text else "")
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.add_theme_font_size_override(&"font_size", 10)
	name.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(name)
	var price_label := Label.new()
	price_label.text = "%s ✿" % Wallet.format(price)
	price_label.add_theme_color_override(&"font_color", Color("8a5d3f"))
	price_label.add_theme_font_size_override(&"font_size", 10)
	row.add_child(price_label)
	for b: Array in buttons:
		var button := Button.new()
		button.text = b[0]
		button.add_theme_font_size_override(&"font_size", 9)
		button.pressed.connect(handler.bind(item.id, int(b[1])))
		row.add_child(button)
	_list.add_child(row)


func _buy(id: StringName, quantity: int) -> void:
	var result := shop.buy(id, quantity, int(GameState.calendar.season), GameState.wallet, GameState.inventory,
		GameState.progression.level)
	if result == Shop.Result.OK:
		_say(tr("SHOP_BOUGHT") % [quantity, ItemRegistry.item(id).display_name()])
		AudioManager.play(&"coin")
	else:
		_say(tr(Shop.result_key(result)), true)
		AudioManager.play(&"error", -8.0)
	_rebuild()


func _sell(id: StringName, quantity: int) -> void:
	var name := ItemRegistry.item(id).display_name()
	var count := mini(quantity, GameState.inventory.count_of(id))
	var result := shop.sell(id, quantity, GameState.wallet, GameState.inventory)
	if result == Shop.Result.OK:
		_say(tr("SHOP_SOLD") % [count, name, Wallet.format(count * shop.sell_price(id))])
		AudioManager.play(&"coin")
	else:
		_say(tr(Shop.result_key(result)), true)
	_rebuild()


func _say(text: String, warn: bool = false) -> void:
	_feedback.text = text
	_feedback.add_theme_color_override(&"font_color", Color("b0465f") if warn else Color("6a7f4e"))
