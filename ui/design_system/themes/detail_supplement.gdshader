shader_type canvas_item;
// 九宫格保留素材像素坐标，按固定切角去掉原始底板轮廓外的黑底。

void fragment() {
	vec2 texture_size = vec2(textureSize(TEXTURE, 0));
	vec2 edge = min(UV, vec2(1.0) - UV) * texture_size;
	float corner_alpha = smoothstep(13.5, 14.5, edge.x + edge.y);
	float rim_alpha = smoothstep(0.0, 0.6, min(edge.x, edge.y));
	COLOR.a *= corner_alpha * rim_alpha;
}
