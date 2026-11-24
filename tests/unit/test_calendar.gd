extends TestCase


func test_starts_spring_day_one_monday() -> void:
	var cal := Calendar.new()
	assert_eq(cal.day, 1)
	assert_eq(cal.season, Calendar.Season.SPRING)
	assert_eq(cal.year, 1)
	assert_eq(cal.weekday(), 0)


func test_season_rolls_over_after_28_days() -> void:
	var cal := Calendar.new()
	var changed_count := 0
	for i in 27:
		if cal.advance_day():
			changed_count += 1
	assert_eq(cal.day, 28)
	assert_eq(changed_count, 0)
	assert_true(cal.advance_day(), "day 29 starts summer")
	assert_eq(cal.day, 1)
	assert_eq(cal.season, Calendar.Season.SUMMER)


func test_year_rolls_over_after_winter() -> void:
	var cal := Calendar.new()
	for i in Calendar.DAYS_PER_SEASON * 4:
		cal.advance_day()
	assert_eq(cal.season, Calendar.Season.SPRING)
	assert_eq(cal.year, 2)
	assert_eq(cal.total_days(), 113)


func test_weekday_cycles() -> void:
	var cal := Calendar.new()
	for i in 7:
		cal.advance_day()
	assert_eq(cal.weekday(), 0, "day 8 is a Monday again")


func test_dict_roundtrip_and_validation() -> void:
	var cal := Calendar.new()
	assert_true(cal.load_dict({"day": 12, "season": 2, "year": 3}))
	assert_eq(cal.to_dict(), {"day": 12, "season": 2, "year": 3})
	assert_false(cal.load_dict({"day": 99, "season": 9, "year": 0}), "invalid data is reported")
	assert_eq(cal.day, 28)
	assert_eq(int(cal.season), 3)
	assert_eq(cal.year, 1)
