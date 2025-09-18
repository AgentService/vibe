shader_type canvas_item;

uniform float radius : hint_range(0.0, 0.5) = 0.5;
uniform vec2 center = vec2(0.5, 0.5);
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec2 uv = UV - center;
    float distance = length(uv);

    if (distance > radius) {
        discard;
    }

    vec4 original_color = texture(TEXTURE, UV);
    COLOR = mix(original_color, original_color * tint_color, tint_strength);
}