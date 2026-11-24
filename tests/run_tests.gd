extends SceneTree
## Dependency-free test runner.
##   godot --headless --path . --script res://tests/run_tests.gd
## Runs every tests/unit/test_*.gd and tests/integration/test_*.gd.
## Exit code 0 = all passed, 1 = failures.

const SUITE_DIRS := ["res://tests/unit", "res://tests/integration"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# Let autoloads finish _ready before tests touch them.
	await process_frame
	var passed := 0
	var failed := 0
	var started := Time.get_ticks_msec()
	for dir_path in SUITE_DIRS:
		for file in _list_tests(dir_path):
			var script := load(dir_path.path_join(file)) as GDScript
			if script == null:
				print("  [ERROR] could not load ", file)
				failed += 1
				continue
			print("\n%s" % file)
			for method in script.get_script_method_list():
				var name: String = method["name"]
				if not name.begins_with("test_"):
					continue
				var test: TestCase = script.new()
				test.tree = self
				test.before_each()
				await test.call(name)
				test.after_each()
				if test.failures.is_empty():
					passed += 1
					print("  [PASS] ", name)
				else:
					failed += 1
					print("  [FAIL] ", name)
					for f in test.failures:
						print("         - ", f)
	var ms := Time.get_ticks_msec() - started
	print("\n%d passed, %d failed (%d ms)" % [passed, failed, ms])
	ItemRegistry.clear_cache()
	var audio := root.get_node_or_null(^"AudioManager")
	if audio:
		audio.call(&"stop_all")
		await process_frame
		await process_frame
	quit(0 if failed == 0 else 1)


func _list_tests(dir_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for file in dir.get_files():
		if file.begins_with("test_") and file.ends_with(".gd"):
			out.append(file)
	out.sort()
	return out
