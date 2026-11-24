class_name FarmHUD
extends CanvasLayer
## Gameplay HUD: date, hotbar, toasts, inventory window, dialogs and the
## location banner. `modal_changed` lets the scene freeze player movement.

signal modal_changed(open: bool)

@onready var banner: LocationBanner = $LocationBanner
@onready var hotbar: Hotbar = %Hotbar
@onready var _toast: Toast = %Toast
@onready var _inventory: InventoryPanel = $InventoryPanel
@onready var _dialog: ConfirmDialog = $ConfirmDialog
@onready var _shop: ShopPanel = $ShopPanel
@onready var _message: MessageDialog = $MessageDialog
@onready var _map: MapPanel = $MapPanel
@onready var _florist: FloristPanel = $FloristPanel
@onready var _workbench: BouquetPanel = $BouquetPanel
@onready var _journal: JournalPanel = $JournalPanel
@onready var _dialogue: DialogueBox = $DialogueBox


func _ready() -> void:
	for panel: Node in [_inventory, _shop, _message, _map, _florist, _workbench, _journal]:
		panel.closed.connect(func() -> void: modal_changed.emit(false))
	GameState.quests.quest_started.connect(_on_quest_started)
	GameState.quest_rewarded.connect(_on_quest_rewarded)
	GameState.leveled_up.connect(_on_leveled_up)
	GameState.achievement_earned.connect(_on_achievement)


func _on_leveled_up(level: int, reward: Dictionary) -> void:
	var text: String = tr("LEVEL_UP") % level
	var parts := PackedStringArray()
	for entry: Array in reward.get("items", []):
		parts.append("%d %s" % [int(entry[1]), ItemRegistry.item(StringName(str(entry[0]))).display_name()])
	if int(reward.get("money", 0)) > 0:
		parts.append("%s ✿" % Wallet.format(int(reward["money"])))
	if not parts.is_empty():
		text += "  +" + ", ".join(parts)
	toast(text)
	AudioManager.play(&"harvest")


func _on_achievement(definition: Dictionary) -> void:
	toast(tr("ACHIEVEMENT_UNLOCKED") % Loc.text(definition.get("title")))
	AudioManager.play(&"coin")


func _on_quest_started(id: String) -> void:
	toast(tr("QUEST_STARTED") % Loc.text(QuestLog.quest(id).get("title")))


func _on_quest_rewarded(id: String, reward: Dictionary) -> void:
	var title := tr("JOURNAL_REQUEST") if id == "request" else Loc.text(QuestLog.quest(id).get("title"))
	var text: String = tr("QUEST_DONE") % title
	if int(reward.get("money", 0)) > 0:
		text += "  +%s ✿" % Wallet.format(int(reward["money"]))
	if reward.has("diary"):
		text += "  " + tr("QUEST_DIARY_PAGE")
	toast(text)
	AudioManager.play(&"harvest", -4.0)


## Plays a conversation and returns the chosen option (see DialogueBox).
func show_dialogue(npc_id: String, pages: Array, choices: Array = []) -> int:
	modal_changed.emit(true)
	var choice: int = await _dialogue.play(npc_id, pages, choices)
	modal_changed.emit(false)
	return choice


func open_journal(tab: JournalPanel.Tab = JournalPanel.Tab.QUESTS) -> void:
	if is_modal_open():
		return
	_journal.open(tab)
	modal_changed.emit(true)


func journal_panel() -> JournalPanel:
	return _journal


func dialogue_box() -> DialogueBox:
	return _dialogue


func is_modal_open() -> bool:
	return _inventory.visible or _dialog.visible or _shop.visible or _message.visible or _map.visible \
		or _florist.visible or _workbench.visible or _journal.visible or _dialogue.visible


func open_florist(tab: FloristPanel.Tab) -> void:
	if is_modal_open():
		return
	_florist.open(tab)
	modal_changed.emit(true)


func open_workbench() -> void:
	if is_modal_open():
		return
	_workbench.open()
	modal_changed.emit(true)


func florist_panel() -> FloristPanel:
	return _florist


func workbench_panel() -> BouquetPanel:
	return _workbench


func open_shop(shop_id: StringName) -> void:
	if is_modal_open():
		return
	if _shop.open(shop_id):
		modal_changed.emit(true)


func show_text(text: String, title: String = "") -> void:
	if is_modal_open():
		return
	_message.show_text(text, title)
	modal_changed.emit(true)


func open_map(current_map: StringName) -> void:
	if is_modal_open():
		return
	_map.open(current_map)
	modal_changed.emit(true)


func message_dialog() -> MessageDialog:
	return _message


func open_chest(chest_id: String) -> void:
	if is_modal_open():
		return
	_inventory.open(GameState.chest(chest_id))
	modal_changed.emit(true)


func close_all() -> void:
	_inventory.close()
	_shop.close()
	_message.close()
	_map.close()
	_florist.close()
	_workbench.close()
	_journal.close()


func shop_panel() -> ShopPanel:
	return _shop


func inventory_panel() -> InventoryPanel:
	return _inventory


func toast(text: String, warn: bool = false) -> void:
	_toast.show_message(text, warn)


func last_toast() -> String:
	return _toast.current_text()


func open_inventory() -> void:
	if is_modal_open():
		return
	_inventory.open()
	modal_changed.emit(true)


func close_inventory() -> void:
	_inventory.close()


func ask(text: String) -> bool:
	modal_changed.emit(true)
	var yes: bool = await _dialog.ask(text)
	modal_changed.emit(false)
	return yes


func dialog() -> ConfirmDialog:
	return _dialog


func show_day_banner(stats: Dictionary) -> void:
	var cal := GameState.calendar
	var title: String = tr("DATE_FMT") % [tr(cal.weekday_key()), cal.day, tr(cal.season_key())]
	var parts := PackedStringArray()
	if int(stats.get("bloomed", 0)) > 0:
		parts.append(tr("DAY_BLOOMED") % stats["bloomed"])
	elif int(stats.get("grew", 0)) > 0:
		parts.append(tr("DAY_GREW") % stats["grew"])
	if int(stats.get("withered", 0)) > 0:
		parts.append(tr("DAY_WITHERED") % stats["withered"])
	var florist: Dictionary = stats.get("florist", {})
	if int(florist.get("sales", 0)) > 0:
		parts.append(tr("DAY_FLORIST_SALES") % [int(florist["sales"]), Wallet.format(int(florist["income"]))])
	if int(florist.get("new_orders", 0)) > 0:
		parts.append(tr("DAY_NEW_ORDERS"))
	for id in stats.get("birthdays", []):
		parts.append(tr("DAY_BIRTHDAY") % Villagers.display_name(str(id)))
	var q: Dictionary = stats.get("quests", {})
	if not str(q.get("new_request", "")).is_empty():
		parts.append(tr("DAY_REQUEST") % Villagers.display_name(str(q["new_request"])))
	var subtitle := " · ".join(parts) if not parts.is_empty() else tr("DAY_GOOD_MORNING")
	banner.show_banner(title, subtitle, false)
