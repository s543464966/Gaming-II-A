// 冷却扫描只消费状态帧的完成比例；不使用 TIME，暂停和冻结时整层保持静止。
shader_type canvas_item;
render_mode unshaded;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 card_size = vec2(100.0, 118.0);
uniform vec4 scan_color : source_color = vec4(0.22, 0.96, 0.87, 1.0);

// 按横向分段生成稳定光点，避免帧间随机闪烁或添加粒子节点。
float seed(float value) {
	return fract(sin(value * 127.1 + 31.7) * 43758.5453);
}

void fragment() {
	vec2 pixels = max(card_size, vec2(1.0));
	float y = (UV.y - progress) * pixels.y;
	float distance_to_line = abs(y);
	float core = 1.0 - smoothstep(1.2, 2.5, distance_to_line);
	// 亮芯之外保留宽柔光和更远的薄雾，让外发光有面积而不是只有硬线。
	float glow = exp(-distance_to_line / 12.0) * 0.74;
	float haze = exp(-distance_to_line / 28.0) * 0.24;

	float columns = max(4.0, floor(pixels.x / 17.0));
	float column = floor(UV.x * columns);
	float x = (fract(UV.x * columns) - mix(0.2, 0.8, seed(column))) * pixels.x / columns;
	float phase = fract(progress * 4.0 + seed(column + 9.0));
	float sparkle_y = 3.0 + phase * 14.0;
	float sparkle = (1.0 - smoothstep(0.5, 1.5, length(vec2(x, y - sparkle_y)))) * (1.0 - phase);

	// 光线跨越整张卡的上下边缘，暗罩只作用于插画；文字由上层节点保持清晰。
	float shade = mix(0.06, 0.34, 1.0 - smoothstep(-2.0, 2.0, y));
	vec2 inset = min(UV, vec2(1.0) - UV);
	shade *= step(0.04, inset.x) * step(0.035, inset.y);
	float light = clamp(core + glow + haze + sparkle, 0.0, 1.0);
	float alpha = max(shade, light);
	vec3 light_color = mix(scan_color.rgb, vec3(0.88, 1.0, 0.98), core);
	float radius = min(pixels.x, pixels.y) * 0.055;
	vec2 corner = abs((UV - vec2(0.5)) * pixels) - (pixels * 0.5 - vec2(radius));
	float edge = length(max(corner, vec2(0.0))) + min(max(corner.x, corner.y), 0.0) - radius;
	float rounded_mask = 1.0 - smoothstep(-0.5, 0.5, edge);
	COLOR = vec4(light_color * light / max(alpha, 0.001), alpha * rounded_mask);
}
