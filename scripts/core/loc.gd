class_name Loc
extends RefCounted
## Picks the current language from inline text objects used by large
## content files (dialogue, quests, diary): {"pt_BR": "...", "en": "..."}.
## UI strings use the CSV translations instead.

const FALLBACK := "pt_BR"


static func text(value: Variant) -> String:
	if typeof(value) == TYPE_STRING:
		return value
	if typeof(value) != TYPE_DICTIONARY:
		return ""
	var d: Dictionary = value
	var locale := TranslationServer.get_locale()
	if d.has(locale):
		return str(d[locale])
	var lang := locale.get_slice("_", 0)
	for key: String in d:
		if key.get_slice("_", 0) == lang:
			return str(d[key])
	return str(d.get(FALLBACK, ""))
