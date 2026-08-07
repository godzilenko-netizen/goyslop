shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float pixel_block : hint_range(1.0, 4.0, 1.0) = 2.0;
uniform float saturation : hint_range(0.0, 1.5) = 0.72;
uniform float contrast : hint_range(0.5, 1.5) = 1.06;
uniform float color_steps : hint_range(8.0, 64.0, 1.0) = 40.0;
uniform float dither_strength : hint_range(0.0, 1.0) = 0.24;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.14;
uniform vec3 shadow_tint : source_color = vec3(0.84, 0.90, 0.92);
uniform vec3 highlight_tint : source_color = vec3(1.0, 0.95, 0.86);


float ordered_dither(vec2 pixel_position) {
	vec2 cell = mod(floor(pixel_position), 4.0);
	float row_0 = cell.x < 1.0 ? 0.0 : (cell.x < 2.0 ? 8.0 : (cell.x < 3.0 ? 2.0 : 10.0));
	float row_1 = cell.x < 1.0 ? 12.0 : (cell.x < 2.0 ? 4.0 : (cell.x < 3.0 ? 14.0 : 6.0));
	float row_2 = cell.x < 1.0 ? 3.0 : (cell.x < 2.0 ? 11.0 : (cell.x < 3.0 ? 1.0 : 9.0));
	float row_3 = cell.x < 1.0 ? 15.0 : (cell.x < 2.0 ? 7.0 : (cell.x < 3.0 ? 13.0 : 5.0));
	float value = cell.y < 1.0 ? row_0 : (cell.y < 2.0 ? row_1 : (cell.y < 3.0 ? row_2 : row_3));
	return value / 16.0 - 0.5;
}


void fragment() {
	vec2 viewport_size = vec2(textureSize(screen_texture, 0));
	vec2 sample_size = max(vec2(pixel_block), vec2(1.0)) / viewport_size;
	vec2 snapped_uv = (floor(SCREEN_UV / sample_size) + 0.5) * sample_size;
	vec3 color = textureLod(screen_texture, snapped_uv, 0.0).rgb;

	float luminance = dot(color, vec3(0.2126, 0.7152, 0.0722));
	color = mix(vec3(luminance), color, saturation);
	color = (color - 0.5) * contrast + 0.5;
	color *= mix(shadow_tint, vec3(1.0), smoothstep(0.10, 0.58, luminance));
	color *= mix(vec3(1.0), highlight_tint, smoothstep(0.48, 0.95, luminance));

	vec2 retro_pixel = floor(FRAGCOORD.xy / max(pixel_block, 1.0));
	float dither = ordered_dither(retro_pixel) * dither_strength;
	color = floor(clamp(color, vec3(0.0), vec3(1.0)) * color_steps + dither) / color_steps;

	vec2 centered = SCREEN_UV * 2.0 - 1.0;
	float edge = smoothstep(0.30, 1.25, dot(centered, centered));
	color *= 1.0 - edge * vignette_strength;
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}
