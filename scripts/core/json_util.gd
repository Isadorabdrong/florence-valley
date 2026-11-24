class_name JsonUtil
extends RefCounted
## Helpers for data read from JSON, where every number is a float.


## `values.has(value)` that treats 6 and 6.0 as equal.
static func has_int(values: Array, value: int) -> bool:
	for v in values:
		if typeof(v) in [TYPE_INT, TYPE_FLOAT] and int(v) == value:
			return true
	return false
