class_name Calendar
extends RefCounted
## In-game date: day of season, season and year.
## Phase 2 advances days by sleeping; Phase 3 adds the clock (TimeService).

signal day_changed(day: int, season: Season, year: int)

enum Season { SPRING, SUMMER, AUTUMN, WINTER }

const DAYS_PER_SEASON := 28
const SEASON_COUNT := 4
const SEASON_KEYS: Array[String] = ["SEASON_SPRING", "SEASON_SUMMER", "SEASON_AUTUMN", "SEASON_WINTER"]
const WEEKDAY_KEYS: Array[String] = ["WEEKDAY_MON", "WEEKDAY_TUE", "WEEKDAY_WED", "WEEKDAY_THU",
	"WEEKDAY_FRI", "WEEKDAY_SAT", "WEEKDAY_SUN"]

var day := 1
var season: Season = Season.SPRING
var year := 1


func reset() -> void:
	day = 1
	season = Season.SPRING
	year = 1
	day_changed.emit(day, season, year)


## Days elapsed since the start of the game, starting at 1.
func total_days() -> int:
	return (year - 1) * SEASON_COUNT * DAYS_PER_SEASON + int(season) * DAYS_PER_SEASON + day


## 0 = Monday … 6 = Sunday. Day 1 of the game is a Monday.
func weekday() -> int:
	return (total_days() - 1) % 7


## Advances one day. Returns true when the season changed.
func advance_day() -> bool:
	day += 1
	var season_changed := false
	if day > DAYS_PER_SEASON:
		day = 1
		season_changed = true
		if season == Season.WINTER:
			season = Season.SPRING
			year += 1
		else:
			season = (int(season) + 1) as Season
	day_changed.emit(day, season, year)
	return season_changed


func season_key() -> String:
	return SEASON_KEYS[season]


func weekday_key() -> String:
	return WEEKDAY_KEYS[weekday()]


func to_dict() -> Dictionary:
	return {"day": day, "season": int(season), "year": year}


## Loads a saved date. Invalid values are clamped; returns false if the data
## had to be corrected.
func load_dict(data: Dictionary) -> bool:
	var d := int(data.get("day", 1))
	var s := int(data.get("season", 0))
	var y := int(data.get("year", 1))
	day = clampi(d, 1, DAYS_PER_SEASON)
	season = clampi(s, 0, SEASON_COUNT - 1) as Season
	year = maxi(y, 1)
	day_changed.emit(day, season, year)
	return day == d and int(season) == s and year == y
