class_name FloristPanel
extends Control
## Flower shop management: displays & prices, orders, upgrades &
## decorations, and a sales report. Opens from the counter, the stands and
## the order board.

signal closed

enum Tab { DISPLAYS, ORDERS, UPGRADES, REPORT }

var _tab: Tab = Tab.DISPLAYS
var _choosing_slot := -1

@onready var _status: Label = %ShopStatus
@onready var _stars: Label = %ShopStars
@onready var _money: Label = %ShopMoney
@onready var _open_toggle: Button = %OpenToggle
@onready var _tabs: Array[Button] = [%TabDisplays, %TabOrders, %TabUpgrades, %TabReport]
@onready var _list: VBoxContainer = %FloristList
@onready var _feedback: Label = %FloristFeedback
@onready var _close: Button = %CloseFlorist


func _ready() -> void:
	visible = false
	var group := ButtonGroup.new()
	for i in _tabs.size():
		_tabs[i].button_group = group
		_tabs[i].toggle_mode = true
		_tabs[i].pressed.connect(_set_tab.bind(i))
	_open_toggle.pressed.connect(_toggle_open)
	_close.pressed.connect(close)
	GameState.florist.changed.connect(_on_changed)
	GameState.wallet.changed.connect(func(_a: int, _d: int) -> void: _refresh_header())


func open(tab: Tab = Tab.DISPLAYS) -> void:
	_feedback.text = ""
	_choosing_slot = -1
	visible = true
	UiKit.pop_in(self)
	_tabs[tab].button_pressed = true
	_set_tab(tab)
	_close.grab_focus()
	AudioManager.play(&"open", -6.0)


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func current_tab() -> Tab:
	return _tab


func _input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(InputBindings.PAUSE)):
		close()
		get_viewport().set_input_as_handled()


func _on_changed() -> void:
	if visible:
		_rebuild()


func _set_tab(tab: int) -> void:
	_tab = tab as Tab
	_choosing_slot = -1
	_rebuild()


func _toggle_open() -> void:
	GameState.florist.is_open = not GameState.florist.is_open
	GameState.florist.changed.emit()
	_say(tr("FLORIST_NOW_OPEN") if GameState.florist.is_open else tr("FLORIST_NOW_CLOSED"))


func _refresh_header() -> void:
	var shop := GameState.florist
	_status.text = tr("FLORIST_OPEN") if shop.is_open else tr("FLORIST_CLOSED")
	_status.add_theme_color_override(&"font_color", Color("6a7f4e") if shop.is_open else Color("b0465f"))
	var next := shop.next_star_at()
	_stars.text = "%s  %s" % [UiKit.stars(shop.stars()),
		(tr("FLORIST_REP_NEXT") % [shop.reputation, next]) if next >= 0 else str(shop.reputation)]
	_money.text = "%s ✿" % Wallet.format(GameState.wallet.amount)
	_open_toggle.text = tr("FLORIST_CLOSE_SHOP") if shop.is_open else tr("FLORIST_OPEN_SHOP")


func _rebuild() -> void:
	_refresh_header()
	UiKit.clear(_list)
	match _tab:
		Tab.DISPLAYS:
			_build_displays()
		Tab.ORDERS:
			_build_orders()
		Tab.UPGRADES:
			_build_upgrades()
		Tab.REPORT:
			_build_report()


func _say(text: String, warn: bool = false) -> void:
	_feedback.text = text
	_feedback.add_theme_color_override(&"font_color", Color("b0465f") if warn else Color("6a7f4e"))


# ---------------------------------------------------------------- displays ---

func _build_displays() -> void:
	var shop := GameState.florist
	_list.add_child(UiKit.label(tr("FLORIST_DISPLAYS_HINT"), 8, Color("9c5f7e")))
	for i in shop.slots.size():
		var slot := shop.slots[i]
		var r := UiKit.row()
		r.add_child(UiKit.label("%d." % (i + 1), 9, Color("9c5f7e")))
		if int(slot["count"]) > 0:
			var id: StringName = slot["item"]
			var base := FloristShop.base_value(id)
			r.add_child(UiKit.icon(id))
			r.add_child(UiKit.label("%s ×%d" % [ItemRegistry.item(id).display_name(), int(slot["count"])], 9, Color("5b3a4f"), true))
			r.add_child(UiKit.label("%s ✿ (%d%%)" % [Wallet.format(int(slot["price"])), roundi(100.0 * int(slot["price"]) / base)], 9, Color("8a5d3f")))
			r.add_child(UiKit.button("−", func() -> void: shop.adjust_price(i, -1)))
			r.add_child(UiKit.button("+", func() -> void: shop.adjust_price(i, 1)))
			r.add_child(UiKit.button(tr("FLORIST_RESTOCK"), _choose_for.bind(i)))
			r.add_child(UiKit.button(tr("FLORIST_REMOVE"), func() -> void: shop.unstock_slot(i, GameState.inventory)))
		else:
			r.add_child(UiKit.label(tr("FLORIST_EMPTY_SLOT"), 9, Color("9c8f94"), true))
			r.add_child(UiKit.button(tr("FLORIST_STOCK"), _choose_for.bind(i)))
		_list.add_child(r)
		if _choosing_slot == i:
			_build_chooser(i)


func _choose_for(index: int) -> void:
	_choosing_slot = -1 if _choosing_slot == index else index
	_rebuild()


func _build_chooser(index: int) -> void:
	var shop := GameState.florist
	var box := HFlowContainer.new()
	box.add_theme_constant_override(&"h_separation", 4)
	box.add_theme_constant_override(&"v_separation", 4)
	var seen := {}
	var current: StringName = shop.slots[index]["item"]
	for i in GameState.inventory.size():
		var id := GameState.inventory.item_at(i)
		if id == &"" or seen.has(id) or not FloristShop.can_display(id):
			continue
		if int(shop.slots[index]["count"]) > 0 and id != current:
			continue
		seen[id] = true
		var b := UiKit.button("%s ×%d" % [ItemRegistry.item(id).display_name(), GameState.inventory.count_of(id)],
			_stock.bind(index, id))
		b.icon = ItemRegistry.icon(id)
		box.add_child(b)
	if seen.is_empty():
		_list.add_child(UiKit.label(tr("FLORIST_NOTHING_TO_STOCK"), 8, Color("b0465f")))
	else:
		_list.add_child(box)


func _stock(index: int, id: StringName) -> void:
	var moved := GameState.florist.stock_slot(index, id, 10, GameState.inventory)
	_choosing_slot = -1
	if moved > 0:
		AudioManager.play(&"pickup", -6.0)
		_say(tr("FLORIST_STOCKED") % [moved, ItemRegistry.item(id).display_name()])
	_rebuild()


# ------------------------------------------------------------------ orders ---

func _build_orders() -> void:
	var shop := GameState.florist
	if shop.orders.is_empty():
		_list.add_child(UiKit.label(tr("FLORIST_NO_ORDERS"), 9, Color("9c8f94")))
		return
	for order in shop.orders:
		var box := VBoxContainer.new()
		box.add_theme_constant_override(&"separation", 1)
		var r := UiKit.row()
		var id: StringName = order["item"]
		r.add_child(UiKit.icon(id))
		var days := int(order["deadline"]) - GameState.calendar.total_days()
		r.add_child(UiKit.label("%s — %d× %s" % [order["customer"], int(order["count"]), ItemRegistry.item(id).display_name()],
			9, Color("5b3a4f"), true))
		r.add_child(UiKit.label(tr("FLORIST_ORDER_REWARD") % [Wallet.format(int(order["reward"])), int(order["reputation"])], 9, Color("8a5d3f")))
		var ok := shop.can_deliver(order, GameState.inventory)
		r.add_child(UiKit.button(tr("FLORIST_DELIVER"), _deliver.bind(int(order["id"])), ok))
		box.add_child(r)
		var note := "\"%s\"  · %s" % [tr(str(order["note"])), tr("FLORIST_ORDER_DAYS") % maxi(days, 0) if days > 0 else tr("FLORIST_ORDER_TODAY")]
		box.add_child(UiKit.label(note, 8, Color("9c5f7e")))
		_list.add_child(box)


func _deliver(order_id: int) -> void:
	var order := GameState.florist.order_by_id(order_id)
	var name: String = order.get("customer", "")
	if GameState.florist.deliver_order(order_id, GameState.wallet, GameState.inventory):
		GameState.record("order", str(order.get("item", "")))
		# Orders from villagers also make them like you more.
		for id in Villagers.ids():
			if Villagers.display_name(id) == name:
				GameState.relationships.add(id, 25)
		AudioManager.play(&"coin")
		_say(tr("FLORIST_DELIVERED") % name)


# ---------------------------------------------------------------- upgrades ---

func _build_upgrades() -> void:
	_list.add_child(UiKit.label(tr("FLORIST_UPGRADES"), 10, Color("9c4f72")))
	for def: Dictionary in FloristShop.config().get("upgrades", []):
		_purchase_row("upgrades", def)
	_list.add_child(UiKit.label(tr("FLORIST_DECORATIONS"), 10, Color("9c4f72")))
	for def: Dictionary in FloristShop.config().get("decorations", []):
		_purchase_row("decorations", def)


func _purchase_row(list_key: String, def: Dictionary) -> void:
	var shop := GameState.florist
	var id := str(def["id"])
	var state := shop.purchase_state(list_key, id, GameState.wallet, GameState.inventory)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 0)
	var r := UiKit.row()
	r.add_child(UiKit.label(tr("UPG_" + id.to_upper()), 9, Color("5b3a4f"), true))
	match state:
		"owned":
			r.add_child(UiKit.label(tr("FLORIST_OWNED"), 9, Color("6a7f4e")))
		"locked":
			r.add_child(UiKit.label(tr("FLORIST_NEEDS_STARS") % int(def.get("min_stars", 0)), 9, Color("9c8f94")))
		_:
			r.add_child(UiKit.label(UiKit.cost_text(int(def.get("cost", 0)), def.get("items", [])), 8, Color("8a5d3f")))
			r.add_child(UiKit.button(tr("SHOP_BUY"), _buy.bind(list_key, id), state == "available"))
	box.add_child(r)
	box.add_child(UiKit.label(tr("UPG_" + id.to_upper() + "_DESC"), 8, Color("9c5f7e")))
	_list.add_child(box)


func _buy(list_key: String, id: String) -> void:
	if GameState.florist.buy(list_key, id, GameState.wallet, GameState.inventory):
		AudioManager.play(&"coin")
		_say(tr("FLORIST_BOUGHT") % tr("UPG_" + id.to_upper()))


# ------------------------------------------------------------------ report ---

func _build_report() -> void:
	var shop := GameState.florist
	var today := shop.today
	var t := shop.totals
	var lines := [
		tr("FLORIST_REPORT_TODAY") % [int(today["customers"]), int(today["sales"]), Wallet.format(int(today["income"])), Wallet.format(int(today["tips"]))],
		tr("FLORIST_REPORT_TOTAL") % [int(t["sales"]), Wallet.format(int(t["income"])), int(t["bouquets"]), int(t.get("orders", 0))],
		tr("FLORIST_REPORT_RECIPES") % [shop.known_recipes.size(), BouquetBook.recipes().size()],
		tr("FLORIST_REPORT_WAITING") % shop.pending.size(),
		tr("FLORIST_REPORT_RATE") % roundi(shop.customer_rate(int(GameState.weather), GameState.calendar.weekday()) * 6.0 * 8.0),
	]
	for line: String in lines:
		_list.add_child(UiKit.wrap_label(line, 9, 380))
	_list.add_child(UiKit.wrap_label(tr("FLORIST_TIPS"), 8, 380))
