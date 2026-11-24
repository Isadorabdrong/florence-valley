extends TestCase

const TEST_DIR := "user://test_saves"


func before_each() -> void:
	SaveSystem.save_dir = TEST_DIR
	for slot in range(1, SaveSystem.SLOT_COUNT + 1):
		SaveSystem.delete(slot)


func after_each() -> void:
	for slot in range(1, SaveSystem.SLOT_COUNT + 1):
		SaveSystem.delete(slot)
	SaveSystem.save_dir = SaveSystem.DEFAULT_DIR


func _write_raw(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_roundtrip() -> void:
	var data := {"money": 123, "list": [1, 2, 3], "nested": {"a": "b"}}
	assert_eq(SaveSystem.save(1, data, {"player": "Ana"}), OK)
	var r := SaveSystem.load_slot(1)
	assert_eq(r["error"], SaveSystem.LoadError.NONE)
	assert_eq(int(r["data"]["money"]), 123)
	assert_eq(r["data"]["nested"], {"a": "b"})
	assert_eq(r["summary"]["player"], "Ana")
	assert_false(r["from_backup"])


func test_invalid_slot_rejected() -> void:
	assert_eq(SaveSystem.save(0, {}), ERR_INVALID_PARAMETER)
	assert_eq(SaveSystem.save(4, {}), ERR_INVALID_PARAMETER)


func test_missing() -> void:
	assert_eq(SaveSystem.load_slot(2)["error"], SaveSystem.LoadError.MISSING)


func test_tampered_file_is_corrupt() -> void:
	SaveSystem.save(1, {"money": 10})
	var path := SaveSystem.slot_path(1)
	var text := FileAccess.get_file_as_string(path).replace("10", "99999")
	_write_raw(path, text)
	assert_eq(SaveSystem.read_file(path)["error"], SaveSystem.LoadError.CORRUPT, "checksum mismatch")


func test_garbage_file_falls_back_to_backup() -> void:
	SaveSystem.save(1, {"money": 1})
	SaveSystem.save(1, {"money": 2}) # previous becomes .bak
	_write_raw(SaveSystem.slot_path(1), "{ this is not json")
	var r := SaveSystem.load_slot(1)
	assert_eq(r["error"], SaveSystem.LoadError.NONE)
	assert_true(r["from_backup"])
	assert_eq(int(r["data"]["money"]), 1)


func test_corrupt_without_backup_reports_error() -> void:
	SaveSystem.save(1, {"money": 1})
	_write_raw(SaveSystem.slot_path(1), "garbage")
	assert_eq(SaveSystem.load_slot(1)["error"], SaveSystem.LoadError.CORRUPT)
	assert_eq(SaveSystem.list_slots()[0]["state"], "corrupt")


func test_newer_schema_unsupported() -> void:
	var payload := JSON.stringify({"money": 1})
	_write_raw(SaveSystem.slot_path(1), JSON.stringify({"format": SaveSystem.FORMAT,
		"schema_version": SaveSystem.SCHEMA_VERSION + 1, "checksum": payload.sha256_text(), "payload": payload}))
	assert_eq(SaveSystem.load_slot(1)["error"], SaveSystem.LoadError.UNSUPPORTED_VERSION)


func test_old_schema_is_migrated() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))
	var payload := JSON.stringify({"gold": 77})
	_write_raw(SaveSystem.slot_path(1), JSON.stringify({"format": SaveSystem.FORMAT,
		"schema_version": 0, "checksum": payload.sha256_text(), "payload": payload}))
	var r := SaveSystem.load_slot(1)
	assert_eq(r["error"], SaveSystem.LoadError.NONE)
	assert_eq(r["migrated_from"], 0)
	assert_eq(int(r["data"]["money"]), 77)
	assert_false(r["data"].has("gold"))
	assert_true(r["data"].has("clock"))


func test_slots_listing_free_and_recent() -> void:
	assert_eq(SaveSystem.first_free_slot(), 1)
	SaveSystem.save(2, {"x": 1})
	assert_eq(SaveSystem.first_free_slot(), 1)
	assert_eq(SaveSystem.most_recent_slot(), 2)
	var states := SaveSystem.list_slots().map(func(e: Dictionary) -> String: return e["state"])
	assert_eq(states, ["empty", "ok", "empty"])
	SaveSystem.delete(2)
	assert_false(SaveSystem.exists(2))
	assert_eq(SaveSystem.most_recent_slot(), -1)


func test_no_temp_file_left_behind() -> void:
	SaveSystem.save(3, {"a": 1})
	assert_false(FileAccess.file_exists(SaveSystem.slot_path(3) + ".tmp"))
