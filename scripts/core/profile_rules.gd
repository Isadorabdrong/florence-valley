class_name ProfileRules
extends RefCounted
## Validation rules for the player profile (character creation).
## Pure functions — covered by tests/unit/test_profile_rules.gd.

const NAME_MAX_LENGTH := 16
const NAME_MIN_LENGTH := 2

enum NameError { NONE, TOO_SHORT, TOO_LONG, INVALID_CHARS }

const _ERROR_KEYS := {
	NameError.TOO_SHORT: "ERR_NAME_SHORT",
	NameError.TOO_LONG: "ERR_NAME_LONG",
	NameError.INVALID_CHARS: "ERR_NAME_CHARS",
}


## Trims and collapses internal whitespace: "  Ana   Clara " -> "Ana Clara".
static func sanitize_name(raw: String) -> String:
	var parts := raw.strip_edges().split(" ", false)
	return " ".join(parts)


static func validate_name(raw: String) -> NameError:
	var clean := sanitize_name(raw)
	if clean.length() < NAME_MIN_LENGTH:
		return NameError.TOO_SHORT
	if clean.length() > NAME_MAX_LENGTH:
		return NameError.TOO_LONG
	for i in clean.length():
		var ch := clean.unicode_at(i)
		var allowed := ch == 32 or ch == 39 or ch == 45 \
			or (ch >= 48 and ch <= 57) \
			or (ch >= 65 and ch <= 90) \
			or (ch >= 97 and ch <= 122) \
			or (ch >= 192 and ch <= 591) # Latin-1 Supplement + Latin Extended (á, ç, ã, ü…)
		if not allowed:
			return NameError.INVALID_CHARS
	return NameError.NONE


static func error_key(error: NameError) -> String:
	return _ERROR_KEYS.get(error, "")
