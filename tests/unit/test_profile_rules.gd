extends TestCase

const E := ProfileRules.NameError


func test_sanitize_collapses_spaces() -> void:
	assert_eq(ProfileRules.sanitize_name("  Ana   Clara  "), "Ana Clara")


func test_valid_names() -> void:
	for n in ["Flora", "Ana Clara", "João", "Maria-José", "D'Ávila", "Lu"]:
		assert_eq(ProfileRules.validate_name(n), E.NONE, n)


func test_too_short() -> void:
	assert_eq(ProfileRules.validate_name(" A "), E.TOO_SHORT)
	assert_eq(ProfileRules.validate_name(""), E.TOO_SHORT)


func test_too_long() -> void:
	assert_eq(ProfileRules.validate_name("A".repeat(17)), E.TOO_LONG)


func test_invalid_chars() -> void:
	assert_eq(ProfileRules.validate_name("Flora<3"), E.INVALID_CHARS)
	assert_eq(ProfileRules.validate_name("a/b"), E.INVALID_CHARS)


func test_every_error_has_translation_key() -> void:
	for err in [E.TOO_SHORT, E.TOO_LONG, E.INVALID_CHARS]:
		var key := ProfileRules.error_key(err)
		assert_false(key.is_empty())
		assert_ne(TranslationServer.translate(key), StringName(key), "missing translation for %s" % key)
