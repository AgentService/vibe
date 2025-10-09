shader_type canvas_item;

// Dissolve effect for enemy spawn animation
// Enemies materialize from transparent to fully visible

uniform sampler2D noise_texture: repeat_enable, filter_linear;
uniform float dissolve_progress: hint_range(0.0, 1.0) = 0.0;
uniform float edge_width: hint_range(0.0, 0.2) = 0.05;
uniform vec4 edge_color: source_color = vec4(0.0, 1.0, 1.0, 1.0); // Cyan glow
uniform float noise_scale: hint_range(0.5, 5.0) = 1.5;
uniform vec4 modulate_tint: source_color = vec4(1.0, 1.0, 1.0, 1.0); // Tint color (white = no tint)

void fragment() {
	// Sample base sprite texture
	vec4 color = texture(TEXTURE, UV);

	// Sample noise texture for dissolve pattern
	vec2 noise_uv = UV * noise_scale;
	float noise_value = texture(noise_texture, noise_uv).r;

	// Calculate dissolve cutoff
	float dissolve_threshold = dissolve_progress;

	// Determine if pixel should be visible
	float alpha_mask = step(dissolve_threshold, noise_value);

	// Edge glow calculation
	float edge_mask = smoothstep(dissolve_threshold - edge_width, dissolve_threshold, noise_value);
	edge_mask *= (1.0 - alpha_mask); // Only glow on dissolving edge

	// Combine sprite color with edge glow
	vec3 final_color = mix(color.rgb, edge_color.rgb, edge_mask * edge_color.a);

	// Apply modulate tint (for breach events, etc.)
	final_color *= modulate_tint.rgb;

	// Apply dissolve alpha mask
	float final_alpha = color.a * alpha_mask * modulate_tint.a;

	COLOR = vec4(final_color, final_alpha);
}
