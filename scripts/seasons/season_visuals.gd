class_name SeasonVisuals
extends RefCounted
## Seasonal look: a light colour grade (ground / foliage modulate) plus the
## global shader uniform `season`, which the foliage (wind_sway) and ground
## (season_ground) shaders use for autumn leaves and winter snow.

const GROUND := [Color(1, 1, 1), Color(1.04, 1.0, 0.86), Color(1.06, 0.94, 0.8), Color(0.94, 0.97, 1.06)]
const FOLIAGE := [Color(1, 1, 1), Color(0.96, 1.02, 0.9), Color(1.04, 0.98, 0.94), Color(0.96, 0.98, 1.04)]


static func ground_tint(season: int) -> Color:
	return GROUND[clampi(season, 0, 3)]


static func foliage_tint(season: int) -> Color:
	return FOLIAGE[clampi(season, 0, 3)]


const GLOBAL_SEASON := &"season"


## Publishes the season to every shader that reads `global uniform float season`.
static func set_shader_season(season: int) -> void:
	RenderingServer.global_shader_parameter_set(GLOBAL_SEASON, float(clampi(season, 0, 3)))
