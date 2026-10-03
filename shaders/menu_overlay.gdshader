shader_type canvas_item;
void fragment() {
	float top = 1.0 - smoothstep(0.05, 0.57, UV.y);
	float bottom = smoothstep(0.49, 0.94, UV.y);
	float edge = pow(abs(UV.x - 0.5) * 2.0, 2.0) * 0.14;
	COLOR = vec4(0.018, 0.032, 0.048, clamp(top * 0.90 + bottom * 0.96 + edge, 0.12, 0.98));
}
