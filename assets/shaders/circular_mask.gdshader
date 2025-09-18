shader_type canvas_item;

uniform float radius : hint_range(0.0, 0.5) = 0.5;
uniform vec2 center = vec2(0.5, 0.5);

void fragment() {
    vec2 uv = UV - center;
    float distance = length(uv);

    if (distance > radius) {
        discard;
    }

    COLOR = texture(TEXTURE, UV);
}