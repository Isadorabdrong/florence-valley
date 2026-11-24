extends PanelContainer
## Top-right status panel: date, time, weather and money.

const WEATHER_ICONS := preload("res://assets/ui/weather_icons.png")

var _icons: Array[AtlasTexture] = []

@onready var _date: Label = %Date
@onready var _time: Label = %Time
@onready var _weather: TextureRect = %WeatherIcon
@onready var _money: Label = %MoneyLabel
@onready var _level: Label = %LevelLabel
@onready var _xp: ProgressBar = %XpBar


func _ready() -> void:
	for i in Weather.Kind.size():
		var a := AtlasTexture.new()
		a.atlas = WEATHER_ICONS
		a.region = Rect2(i * 12, 0, 12, 12)
		_icons.append(a)
	GameState.calendar.day_changed.connect(_on_day_changed)
	GameState.clock.time_changed.connect(_on_time_changed)
	GameState.weather_changed.connect(_on_weather_changed)
	GameState.wallet.changed.connect(_on_money_changed)
	GameState.leveled_up.connect(_on_level)
	GameState.progression.xp_changed.connect(_on_xp)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("e6dfe0")
	bg.set_corner_radius_all(2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("86b27a")
	fill.set_corner_radius_all(2)
	_xp.add_theme_stylebox_override(&"background", bg)
	_xp.add_theme_stylebox_override(&"fill", fill)
	_refresh()


func _refresh() -> void:
	var cal := GameState.calendar
	_date.text = tr("DATE_FMT") % [tr(cal.weekday_key()), cal.day, tr(cal.season_key())]
	_time.text = GameState.clock.format()
	_weather.texture = _icons[GameState.weather]
	_weather.tooltip_text = tr(Weather.key(GameState.weather))
	_money.text = Wallet.format(GameState.wallet.amount)
	_refresh_level()


func _refresh_level() -> void:
	_level.text = tr("LEVEL_SHORT") % GameState.progression.level
	_xp.value = GameState.progression.level_progress()
	_xp.tooltip_text = "%d XP" % GameState.progression.xp


func _on_xp(_xp_total: int) -> void:
	_refresh_level()


func _on_level(_lv: int, _reward: Dictionary) -> void:
	_refresh_level()


func _on_day_changed(_d: int, _s: int, _y: int) -> void:
	_refresh()


func _on_time_changed(_m: int) -> void:
	_time.text = GameState.clock.format()


func _on_weather_changed(_k: Weather.Kind) -> void:
	_refresh()


func _on_money_changed(amount: int, delta: int) -> void:
	_money.text = Wallet.format(amount)
	if delta != 0 and is_inside_tree():
		_money.modulate = Color("b4e09a") if delta > 0 else Color("f0a0b0")
		create_tween().tween_property(_money, "modulate", Color.WHITE, 0.6)
