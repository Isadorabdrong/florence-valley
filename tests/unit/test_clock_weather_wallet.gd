extends TestCase


func test_clock_ticks_ten_minutes_every_seven_seconds() -> void:
	var clock := GameClock.new()
	clock.advance(6.9)
	assert_eq(clock.minutes, GameClock.DAY_START)
	clock.advance(0.2)
	assert_eq(clock.minutes, GameClock.DAY_START + 10)
	assert_eq(clock.format(), "06:10")


func test_clock_midnight_and_pass_out_fire_once() -> void:
	var clock := GameClock.new()
	var events: Array = []
	clock.late_night.connect(func() -> void: events.append("late"))
	clock.passed_out.connect(func() -> void: events.append("out"))
	clock.set_minutes(23 * 60 + 50)
	clock.advance(GameClock.SECONDS_PER_TICK)
	assert_eq(clock.format(), "00:00")
	clock.advance(GameClock.SECONDS_PER_TICK * 20)
	assert_eq(clock.minutes, GameClock.DAY_END)
	assert_true(clock.has_ended())
	clock.advance(100.0)
	assert_eq(events, ["late", "out"])
	clock.reset_day()
	assert_false(clock.has_ended())


func test_light_is_brightest_at_noon_and_dark_at_night() -> void:
	var noon := GameClock.light_color(12 * 60)
	var night := GameClock.light_color(25 * 60)
	assert_almost(noon.v, 1.0, 0.001, "noon at full brightness")
	assert_true(noon.r >= noon.b, "daylight is warm (golden), never blue")
	assert_lt(night.v, 0.75)
	var dusk := GameClock.light_color(20 * 60)
	assert_lt(dusk.v, noon.v + 0.0001)


func test_weather_deterministic_and_seasonal() -> void:
	assert_eq(Weather.for_day(123, 1, 0), Weather.Kind.SUNNY, "first day is sunny")
	for day in range(2, 60):
		assert_eq(Weather.for_day(7, day, 0), Weather.for_day(7, day, 0), "same seed+day")
	var counts := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for i in 2000:
		var k := Weather.roll(Calendar.Season.WINTER, rng)
		counts[k] = int(counts.get(k, 0)) + 1
	assert_false(counts.has(Weather.Kind.RAIN), "no rain in winter")
	assert_gt(counts.get(Weather.Kind.SNOW, 0), 700, "snow is common in winter")
	assert_true(Weather.waters_crops(Weather.Kind.STORM))
	assert_false(Weather.waters_crops(Weather.Kind.SNOW))


func test_wallet() -> void:
	var w := Wallet.new()
	assert_false(w.spend(1))
	assert_true(w.add(500))
	assert_false(w.add(-5))
	assert_true(w.spend(120))
	assert_eq(w.amount, 380)
	assert_false(w.spend(381))
	w.set_amount(-50)
	assert_eq(w.amount, 0)
	assert_eq(Wallet.format(1234567), "1.234.567")
	assert_eq(Wallet.format(999), "999")


func test_season_visuals_cover_all_seasons() -> void:
	for s in 4:
		assert_ne(SeasonVisuals.ground_tint(s), Color(0, 0, 0, 0))
	assert_ne(SeasonVisuals.foliage_tint(2), SeasonVisuals.foliage_tint(0), "autumn differs")
