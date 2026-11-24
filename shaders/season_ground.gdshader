shader_type canvas_item;
// Seasonal ground: fallen leaves in autumn and patchy snow in winter,
// laid over the grass tiles. Noise is sampled per world pixel so the
// patches line up across tiles and stay crisp.

global uniform float season;

varying vec2 world_px;

void vertex() {
	world_px = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
		mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec4 c = COLOR;
	float s = floor(season + 0.5);
	vec2 px = floor(world_px);
	bool grassy = c.g > c.r * 1.05 && c.g > c.b;
	if (s == 2.0 && grassy) {
		float n = hash(px);
		if (n > 0.965) {
			c.rgb = mix(vec3(0.85, 0.4, 0.16), vec3(0.95, 0.66, 0.25), hash(px + 7.0));
		}
	} else if (s == 3.0) {
		// snow settles on grass and, more thinly, on paths; tilled soil stays dark
		float lum = dot(c.rgb, vec3(0.3, 0.55, 0.15));
		bool path = !grassy && c.r > c.g && c.g > c.b && lum > 0.55;
		float n = noise(px / 22.0) * 0.7 + noise(px / 7.0) * 0.3;
		float cover = grassy ? 0.5 : (path ? 0.62 : 2.0);
		if (n > cover) {
			float shade = n > cover + 0.05 ? 1.0 : 0.9;
			c.rgb = vec3(0.9, 0.93, 1.0) * shade;
		}
	}
	COLOR = c;
}
