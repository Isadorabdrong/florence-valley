class_name Weather
extends RefCounted
## Daily weather. Rolled deterministically from the world seed and the day,
## so reloading a save keeps the same weather.

enum Kind { SUNNY, RAIN, STORM, FOG, SNOW, WIND }

const KEYS: Array[String] = ["WEATHER_SUNNY", "WEATHER_RAIN", "WEATHER_STORM",
	"WEATHER_FOG", "WEATHER_SNOW", "WEATHER_WIND"]

## Per-season chances (weights) — Calendar.Season order.
const TABLE := {
	0: [[Kind.SUNNY, 55], [Kind.RAIN, 25], [Kind.STORM, 5], [Kind.WIND, 15]],
	1: [[Kind.SUNNY, 65], [Kind.RAIN, 12], [Kind.STORM, 15], [Kind.WIND, 8]],
	2: [[Kind.SUNNY, 45], [Kind.RAIN, 20], [Kind.FOG, 20], [Kind.WIND, 15]],
	3: [[Kind.SUNNY, 40], [Kind.SNOW, 45], [Kind.FOG, 15]],
}


static func roll(season: int, rng: RandomNumberGenerator) -> Kind:
	var table: Array = TABLE.get(season, TABLE[0])
	var total := 0
	for entry: Array in table:
		total += int(entry[1])
	var pick := rng.randi_range(1, total)
	for entry: Array in table:
		pick -= int(entry[1])
		if pick <= 0:
			return entry[0]
	return Kind.SUNNY


## Weather for a given day. The very first day of a game is always sunny.
static func for_day(world_seed: int, total_day: int, season: int) -> Kind:
	if total_day <= 1:
		return Kind.SUNNY
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world_seed, total_day])
	return roll(season, rng)


static func waters_crops(kind: Kind) -> bool:
	return kind == Kind.RAIN or kind == Kind.STORM


## How much the weather darkens the day (multiplied into the light colour).
static func light_factor(kind: Kind) -> Color:
	match kind:
		Kind.RAIN:
			return Color(0.86, 0.88, 0.95)
		Kind.STORM:
			return Color(0.70, 0.72, 0.84)
		Kind.FOG:
			return Color(0.93, 0.93, 0.96)
		Kind.SNOW:
			return Color(0.95, 0.97, 1.0)
	return Color.WHITE


static func key(kind: Kind) -> String:
	return KEYS[kind]
