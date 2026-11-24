shader_type canvas_item;
// Animated sparkles and soft ripples on the water tiles. Only bluish pixels
// are affected, so the grass/earth banks stay still.

uniform vec4 sparkle_color = vec4(0.894, 0.953, 0.973, 1.0);
uniform vec4 deep_color = vec4(0.420, 0.616, 0.769, 1.0);
uniform float speed = 0.9;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	// In Godot 4, COLOR already holds texture * modulate on entry.
	vec4 c = COLOR;
	float water = step(c.r + 0.12, c.b) * step(0.55, c.b);
	vec2 p = floor(world_pos);
	float t = TIME * speed;
	float wave = sin(p.x * 0.31 + t * 2.0 + sin(p.y * 0.47 + t) * 1.6) * sin(p.y * 0.83 - t * 1.3);
	float sparkle = step(0.94, wave);
	float ripple = step(wave, -0.88);
	c.rgb = mix(c.rgb, sparkle_color.rgb, sparkle * water * 0.85);
	c.rgb = mix(c.rgb, deep_color.rgb, ripple * water * 0.5);
	COLOR = c;
}
