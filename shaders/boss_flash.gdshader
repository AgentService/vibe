shader_type canvas_item;

uniform vec4 flash_color: source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash_modifier: hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	// Add white flash on top of the existing color (additive approach)
	color.rgb += flash_color.rgb * flash_modifier;
	// Clamp to prevent overbrightness
	color.rgb = clamp(color.rgb, vec3(0.0), vec3(1.0));
	COLOR = color;
}