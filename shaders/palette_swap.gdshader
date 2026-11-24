shader_type canvas_item;
// Replaces up to three colour pairs: outfit, hair and skin (main + shade). Colours are compared in the texture's own (sRGB) space, so the
// uniforms are plain vec4 without source_color. Defaults = no change.

uniform vec4 src_main = vec4(0.435, 0.561, 0.753, 1.0);
uniform vec4 src_shade = vec4(0.322, 0.439, 0.624, 1.0);
uniform vec4 dst_main = vec4(0.435, 0.561, 0.753, 1.0);
uniform vec4 dst_shade = vec4(0.322, 0.439, 0.624, 1.0);
uniform vec4 src_hair = vec4(0.541, 0.322, 0.212, 1.0);
uniform vec4 src_hair_shade = vec4(0.416, 0.231, 0.153, 1.0);
uniform vec4 dst_hair = vec4(0.541, 0.322, 0.212, 1.0);
uniform vec4 dst_hair_shade = vec4(0.416, 0.231, 0.153, 1.0);
uniform vec4 src_skin = vec4(0.965, 0.812, 0.690, 1.0);
uniform vec4 src_skin_shade = vec4(0.890, 0.659, 0.533, 1.0);
uniform vec4 dst_skin = vec4(0.965, 0.812, 0.690, 1.0);
uniform vec4 dst_skin_shade = vec4(0.890, 0.659, 0.533, 1.0);
uniform float tolerance = 0.04;

void fragment() {
	// In Godot 4, COLOR already holds texture * modulate on entry.
	vec4 c = COLOR;
	if (distance(c.rgb, src_main.rgb) < tolerance) {
		c.rgb = dst_main.rgb;
	} else if (distance(c.rgb, src_shade.rgb) < tolerance) {
		c.rgb = dst_shade.rgb;
	} else if (distance(c.rgb, src_hair.rgb) < tolerance) {
		c.rgb = dst_hair.rgb;
	} else if (distance(c.rgb, src_hair_shade.rgb) < tolerance) {
		c.rgb = dst_hair_shade.rgb;
	} else if (distance(c.rgb, src_skin.rgb) < tolerance) {
		c.rgb = dst_skin.rgb;
	} else if (distance(c.rgb, src_skin_shade.rgb) < tolerance) {
		c.rgb = dst_skin_shade.rgb;
	}
	COLOR = c;
}
