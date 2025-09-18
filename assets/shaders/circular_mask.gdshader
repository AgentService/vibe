shader_type canvas_item;

uniform float radius : hint_range(0.0, 0.5) = 0.5;
uniform vec2 center = vec2(0.5, 0.5);
uniform vec4 border_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float border_thickness : hint_range(0.0, 0.2) = 0.05;
uniform float border_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec2 uv = UV - center;
    float distance = length(uv);

    if (distance > radius) {
        discard;
    }

    vec4 original_color = texture(TEXTURE, UV);

    // Calculate border effect based on distance from edge
    float edge_distance = radius - distance;
    float border_factor = 1.0 - smoothstep(0.0, border_thickness, edge_distance);

    // Mix original color with border color at the edges
    COLOR = mix(original_color, border_color, border_factor * border_strength);
}