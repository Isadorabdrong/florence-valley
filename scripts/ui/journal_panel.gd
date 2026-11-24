class_name JournalPanel
extends Control
## The journal (L): quests and requests, Grandma Amélia's diary pages and
## the villagers (hearts, birthday, story, discovered gift tastes).

signal closed

enum Tab { QUESTS, DIARY, VILLAGERS, PROGRESS }

const DIARY_PATH := "res://data/dialogues/diary.json"

var _tab: Tab = Tab.QUESTS

@onready var _tabs: Array[Button] = [%TabQuests, %TabDiary, %TabVillagers, %TabProgress]
@onready var _list: VBoxContainer = %JournalList
@onready var _close: Button = %CloseJournal


func _ready() -> void:
	visible = false
	var group := ButtonGroup.new()
	for i in _tabs.size():
		_tabs[i].button_group = group
		_tabs[i].toggle_mode = true
		_tabs[i].pressed.connect(_set_tab.bind(i))
	_close.pressed.connect(close)


func open(tab: Tab = Tab.QUESTS) -> void:
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
	if visible and (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(InputBindings.PAUSE) \
			or event.is_action_pressed(InputBindings.JOURNAL)):
		close()
		get_viewport().set_input_as_handled()


func _set_tab(tab: int) -> void:
	_tab = tab as Tab
	UiKit.clear(_list)
	match _tab:
		Tab.QUESTS:
			_build_quests()
		Tab.DIARY:
			_build_diary()
		Tab.VILLAGERS:
			_build_villagers()
		Tab.PROGRESS:
			_build_progress()


func _title(text: String) -> void:
	_list.add_child(UiKit.label(text, 11, Color("9c4f72")))


func _build_quests() -> void:
	var log := GameState.quests
	_title(tr("JOURNAL_ACTIVE"))
	if log.active.is_empty():
		_list.add_child(UiKit.label(tr("JOURNAL_NO_QUESTS"), 9, Color("9c8f94")))
	for id: String in log.active:
		var q := QuestLog.quest(id)
		var kind := tr("JOURNAL_MAIN") if q.get("kind") == "main" else tr("JOURNAL_SIDE") % Villagers.display_name(str(q.get("giver", "")))
		_list.add_child(UiKit.label("%s  · %s  (%s)" % [Loc.text(q.get("title")), kind, ", ".join(log.progress_text(id))], 10))
		_list.add_child(UiKit.wrap_label(Loc.text(q.get("desc")), 8, 420))
	if not log.requests.is_empty():
		_title(tr("JOURNAL_REQUESTS"))
		for r in log.requests:
			var days := int(r["deadline"]) - GameState.today()
			_list.add_child(UiKit.label(tr("JOURNAL_REQUEST_LINE") % [Villagers.display_name(str(r["npc"])), int(r["count"]),
				ItemRegistry.item(StringName(str(r["item"]))).display_name(), Wallet.format(int(r["reward"])), maxi(days, 0)], 9))
	_title(tr("JOURNAL_COMPLETED") % log.completed.size())
	for id: String in log.completed:
		_list.add_child(UiKit.label("✓ " + Loc.text(QuestLog.quest(id).get("title")), 8, Color("6a7f4e")))


func _build_diary() -> void:
	var pages: Array = (JSON.parse_string(FileAccess.get_file_as_string(DIARY_PATH)) as Dictionary).get("pages", [])
	_title(tr("JOURNAL_DIARY_TITLE") % [GameState.quests.diary_pages.size(), pages.size()])
	if GameState.quests.diary_pages.is_empty():
		_list.add_child(UiKit.wrap_label(tr("JOURNAL_DIARY_EMPTY"), 9, 420))
	for n in GameState.quests.diary_pages:
		if n < 1 or n > pages.size():
			continue
		_list.add_child(UiKit.label(tr("JOURNAL_PAGE") % n, 9, Color("8a5d3f")))
		_list.add_child(UiKit.wrap_label(Loc.text(pages[n - 1]), 9, 420))


func _build_villagers() -> void:
	var rel := GameState.relationships
	for id in Villagers.ids():
		var npc := Villagers.npc(id)
		var row := UiKit.row(8)
		var portrait := TextureRect.new()
		portrait.texture = load("res://assets/characters/portraits/%s.png" % id)
		portrait.custom_minimum_size = Vector2(36, 36)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(portrait)
		var col := VBoxContainer.new()
		col.add_theme_constant_override(&"separation", 0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var met := rel.has_met(id)
		var hearts := rel.hearts(id)
		var b: Array = npc.get("birthday", [0, 1])
		var name_row := UiKit.row(6)
		name_row.add_child(UiKit.label(str(npc["name"]) if met else "???", 10, Color("5b3a4f")))
		name_row.add_child(UiKit.label("♥".repeat(hearts) + "♡".repeat(10 - hearts), 8, Color("e07a9a")))
		col.add_child(name_row)
		if met:
			col.add_child(UiKit.label(tr("JOURNAL_BIRTHDAY") % [tr(Calendar.SEASON_KEYS[int(b[0])]), int(b[1])], 8, Color("9c5f7e")))
			col.add_child(UiKit.wrap_label(Loc.text(npc.get("bio")), 8, 360))
			var tastes := rel.known_tastes(id)
			if not tastes.is_empty():
				var parts := PackedStringArray()
				for item_id: String in tastes:
					parts.append("%s (%s)" % [ItemRegistry.item(StringName(item_id)).display_name(), tr("TASTE_" + str(tastes[item_id]).to_upper())])
				col.add_child(UiKit.wrap_label(tr("JOURNAL_TASTES") % ", ".join(parts), 8, 360))
		else:
			col.add_child(UiKit.label(tr("JOURNAL_NOT_MET"), 8, Color("9c8f94")))
		row.add_child(col)
		_list.add_child(row)


func _build_progress() -> void:
	var p := GameState.progression
	var next := p.next_level_xp()
	_title(tr("PROGRESS_LEVEL") % [p.level, Progression.max_level()])
	_list.add_child(UiKit.label(tr("PROGRESS_XP") % [p.xp, next] if next >= 0 else "%d XP" % p.xp, 9))
	_list.add_child(UiKit.wrap_label(tr("PROGRESS_STATS") % [p.stat("harvested_total"),
		GameState.stat_value("species_harvested"), p.stat("crafted_total"), p.stat("placed_total"),
		Wallet.format(p.stat("money_earned"))], 8, 420))
	_title(tr("PROGRESS_ACHIEVEMENTS") % [p.achievements.size(), Progression.achievement_defs().size()])
	for a: Dictionary in Progression.achievement_defs():
		var done := p.achievements.has(str(a["id"]))
		var row := UiKit.row(6)
		var icon := UiKit.icon(StringName(str(a["icon"])), 16)
		icon.modulate = Color.WHITE if done else Color(0.25, 0.2, 0.25, 0.45)
		row.add_child(icon)
		var col := VBoxContainer.new()
		col.add_theme_constant_override(&"separation", 0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UiKit.label(("✓ " if done else "") + Loc.text(a["title"]), 9, Color("6a7f4e") if done else Color("5b3a4f")))
		var value := mini(GameState.stat_value(str(a["stat"])), int(a["at_least"]))
		col.add_child(UiKit.label("%s  (%d/%d)" % [Loc.text(a["desc"]), value, int(a["at_least"])], 8, Color("9c5f7e")))
		row.add_child(col)
		_list.add_child(row)
