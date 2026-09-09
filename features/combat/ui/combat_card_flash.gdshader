// 卡牌施放与受击共用的暖白光芯；强度由回放事件驱动，不读取引擎时间。
shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 flash_color : source_color = vec4(1.0, 0.83, 0.38, 1.0);
uniform float amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float radial = 1.0 - smoothstep(0.08, 0.72, length(centered));
	vec2 edge_distance = min(UV, vec2(1.0) - UV);
	float edge = 1.0 - smoothstep(0.015, 0.085, min(edge_distance.x, edge_distance.y));
	float streak = pow(max(0.0, 1.0 - abs(centered.x + centered.y * 0.42) * 3.2), 5.0);
	float alpha = amount * clamp(radial * 0.16 + edge * 0.28 + streak * 0.09, 0.0, 0.42);
	COLOR = vec4(flash_color.rgb, alpha);
}
