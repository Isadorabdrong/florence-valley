class_name TestCase
extends RefCounted
## Minimal assertion base class for Florence Valley tests.
## Any method starting with "test_" is run by tests/run_tests.gd; methods may
## be coroutines (use `await`). `tree` gives access to the running SceneTree.

var tree: SceneTree
var failures: PackedStringArray = PackedStringArray()


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func fail(message: String) -> void:
	failures.append(message)


func assert_true(condition: bool, message: String = "expected true") -> void:
	if not condition:
		fail(message)


func assert_false(condition: bool, message: String = "expected false") -> void:
	if condition:
		fail(message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		fail("%s expected <%s> but got <%s>" % [message, str(expected), str(actual)])


func assert_ne(actual: Variant, unexpected: Variant, message: String = "") -> void:
	if typeof(actual) == typeof(unexpected) and actual == unexpected:
		fail("%s value should not be <%s>" % [message, str(unexpected)])


func assert_almost(actual: float, expected: float, epsilon: float = 0.001, message: String = "") -> void:
	if absf(actual - expected) > epsilon:
		fail("%s expected ~%f but got %f" % [message, expected, actual])


func assert_gt(actual: float, threshold: float, message: String = "") -> void:
	if not actual > threshold:
		fail("%s expected > %f but got %f" % [message, threshold, actual])


func assert_lt(actual: float, threshold: float, message: String = "") -> void:
	if not actual < threshold:
		fail("%s expected < %f but got %f" % [message, threshold, actual])


func wait_physics_frames(count: int) -> void:
	for i in count:
		await tree.physics_frame
