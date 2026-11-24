shader_type canvas_item;
// Gentle wind sway for foliage. The top of the sprite moves, the base stays
// planted. Offsets snap to whole pixels to keep the pixel-art look.
// Each instance gets its own phase from its world position.
// The global `season` (0 spring … 3 winter) recolours leaves in autumn and
// puts snow on the upper edges of foliage in winter.

uniform float strength = 1.6;
uniform float speed = 1.3;
uniform float gust_strength = 0.8;
// Crops keep their own colours; only wild foliage follows the season.
uniform bool seasonal = true;
global uniform float season;

void vertex() {
	vec2 origin = MODEL_MATRIX[3].xy;
	float phase = origin.x * 0.045 + origin.y * 0.031;
	float gust = sin(TIME * 0.37 + origin.x * 0.01) * 0.5 + 0.5;
	float sway = sin(TIME * speed + phase) * (strength + gust * gust_strength);
	float weight = clamp(1.0 - UV.y, 0.0, 1.0);
	VERTEX.x += floor(sway * weight + 0.5);
}

void fragment() {
	vec4 c = COLOR;
	float s = seasonal ? floor(season + 0.5) : 0.0;
	bool leafy = c.g > c.r * 1.05 && c.g > c.b * 1.05;
	if (s == 2.0 && leafy) {
		// autumn: greens turn to amber and rust, keeping their shading
		float lum = dot(c.rgb, vec3(0.3, 0.55, 0.15));
		vec3 warm = mix(vec3(0.62, 0.24, 0.12), vec3(1.0, 0.68, 0.3), clamp(lum * 1.6, 0.0, 1.0));
		c.rgb = mix(c.rgb, warm, 0.85);
	} else if (s == 3.0 && c.a > 0.5) {
		// winter: snow where the pixel 1-2 px above is empty (top edges)
		float up1 = texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a;
		float up2 = texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y * 2.0)).a;
		if (up1 < 0.5 || up2 < 0.5) {
			c.rgb = mix(vec3(0.86, 0.9, 1.0), vec3(1.0), up1 < 0.5 ? 1.0 : 0.4);
		} else if (leafy) {
			float lum = dot(c.rgb, vec3(0.3, 0.55, 0.15));
			c.rgb = mix(c.rgb, vec3(lum * 0.8, lum * 0.95, lum * 1.05), 0.55);
		}
	}
	COLOR = c;
}
