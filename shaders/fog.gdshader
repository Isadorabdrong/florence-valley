shader_type canvas_item;
// Soft drifting fog over the whole screen (two layers of value noise).

uniform vec4 fog_color = vec4(0.93, 0.92, 0.96, 1.0);
uniform float density = 0.5;
uniform vec2 scale = vec2(4.0, 2.25);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 uv = UV * scale + vec2(TIME * 0.035, TIME * 0.012);
	float n = noise(uv) * 0.6 + noise(uv * 2.3 - vec2(TIME * 0.02, 0.0)) * 0.4;
	COLOR = vec4(fog_color.rgb, density * smoothstep(0.2, 0.85, n));
}
