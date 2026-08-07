shader_type canvas_item;
render_mode unshaded;

uniform vec4 liquid_tint : source_color = vec4(0.85, 0.05, 0.04, 1.0);
uniform float fill_ratio : hint_range(0.0, 1.0) = 1.0;
uniform float liquid_top : hint_range(0.0, 1.0) = 0.28;
uniform float liquid_bottom : hint_range(0.0, 1.0) = 0.84;
uniform bool recolor_red_source = false;
uniform float shimmer_strength : hint_range(0.0, 0.4) = 0.14;
uniform vec2 pixel_grid = vec2(48.0, 96.0);

void fragment() {
	vec4 source = texture(TEXTURE, UV) * COLOR;
	float high = max(source.r, max(source.g, source.b));
	float low = min(source.r, min(source.g, source.b));
	float saturation = high - low;
	float saturated_mask = smoothstep(0.10, 0.34, saturation);
	float red_source_mask = smoothstep(0.02, 0.16, source.r - max(source.g, source.b));
	float liquid_mask = saturated_mask * (recolor_red_source ? red_source_mask : 1.0);

	float surface_y = mix(liquid_bottom, liquid_top, clamp(fill_ratio, 0.0, 1.0));
	float inside_vertical = step(liquid_top, UV.y) * step(UV.y, liquid_bottom);
	float filled = step(surface_y, UV.y);
	liquid_mask *= inside_vertical;

	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	vec3 empty_glass = vec3(luminance * 0.16);
	vec3 filled_color = liquid_tint.rgb * mix(0.34, 1.24, clamp(luminance * 1.8, 0.0, 1.0));
	vec3 result = mix(source.rgb, empty_glass, liquid_mask * (1.0 - filled) * 0.96);
	result = mix(result, filled_color, liquid_mask * filled * 0.92);

	vec2 pixel_uv = floor(UV * pixel_grid) / pixel_grid;
	float wave = sin(pixel_uv.y * 64.0 + pixel_uv.x * 27.0 - TIME * 2.15);
	float stepped_wave = step(0.72, wave) * shimmer_strength;
	float moving_band = step(0.88, sin(pixel_uv.y * 92.0 - TIME * 1.35)) * shimmer_strength * 0.45;
	result += liquid_tint.rgb * (stepped_wave + moving_band) * liquid_mask * filled;

	source.rgb = result;
	COLOR = source;
}
