class_name GameClock
extends RefCounted
## In-game time of day. The day runs from 06:00 to 02:00 (26:00); every
## SECONDS_PER_TICK real seconds advance MINUTES_PER_TICK game minutes.
## Time only advances when the owner calls advance() (paused in menus).

signal time_changed(minutes: int)
signal late_night ## emitted once at midnight
signal passed_out ## emitted once when the day ends at 02:00

const DAY_START := 6 * 60
const MIDNIGHT := 24 * 60
const DAY_END := 26 * 60
const MINUTES_PER_TICK := 10
const SECONDS_PER_TICK := 7.0

## Minutes since 00:00 of the current game day (may exceed 1440 after midnight).
var minutes := DAY_START
var _accumulator := 0.0
var _ended := false


func reset_day() -> void:
	minutes = DAY_START
	_accumulator = 0.0
	_ended = false
	time_changed.emit(minutes)


func advance(real_seconds: float) -> void:
	if _ended or real_seconds <= 0.0:
		return
	_accumulator += real_seconds
	while _accumulator >= SECONDS_PER_TICK and not _ended:
		_accumulator -= SECONDS_PER_TICK
		set_minutes(minutes + MINUTES_PER_TICK)


func set_minutes(value: int) -> void:
	var before := minutes
	minutes = clampi(value, DAY_START, DAY_END)
	time_changed.emit(minutes)
	if before < MIDNIGHT and minutes >= MIDNIGHT:
		late_night.emit()
	if minutes >= DAY_END and not _ended:
		_ended = true
		passed_out.emit()


func has_ended() -> bool:
	return _ended


func hour() -> int:
	return (minutes / 60) % 24


func minute() -> int:
	return minutes % 60


func format() -> String:
	return "%02d:%02d" % [hour(), minute()]


func to_dict() -> Dictionary:
	return {"minutes": minutes}


func load_dict(data: Dictionary) -> bool:
	var m := int(data.get("minutes", DAY_START))
	minutes = clampi(m, DAY_START, DAY_END - MINUTES_PER_TICK)
	_accumulator = 0.0
	_ended = false
	time_changed.emit(minutes)
	return minutes == m


## Ambient light colour for a time of day (used by a CanvasModulate).
static func light_color(at_minutes: int) -> Color:
	const KEYS := [
		[6 * 60, Color(0.96, 0.86, 0.86)],
		[8 * 60, Color(1.0, 0.97, 0.92)],
		[13 * 60, Color(1.0, 0.99, 0.95)],
		[17 * 60, Color(1.0, 0.94, 0.84)],
		[19 * 60, Color(1.0, 0.82, 0.70)],
		[20 * 60 + 30, Color(0.70, 0.66, 0.88)],
		[22 * 60, Color(0.52, 0.52, 0.78)],
		[26 * 60, Color(0.42, 0.42, 0.70)],
	]
	if at_minutes <= KEYS[0][0]:
		return KEYS[0][1]
	for i in range(1, KEYS.size()):
		if at_minutes <= KEYS[i][0]:
			var a: Array = KEYS[i - 1]
			var b: Array = KEYS[i]
			var t := float(at_minutes - a[0]) / float(b[0] - a[0])
			return (a[1] as Color).lerp(b[1], t)
	return KEYS[KEYS.size() - 1][1]
