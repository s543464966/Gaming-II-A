shader_type canvas_item;
// 只将 detail_paper 的内面转为炭黑，保留原图切角、金属包边和菱形；九宫格仍使用源像素坐标。

void fragment() {
	vec2 source_size = vec2(textureSize(TEXTURE, 0));
	// Button 的文字与图标也经过材质，其他纹理保持原样。
	if (all(lessThan(abs(source_size - vec2(312.0, 72.0)), vec2(0.5)))) {
		vec2 point = UV * source_size;
		vec2 edge = min(point, source_size - point);
		float face = smoothstep(6.0, 7.0, min(edge.x, edge.y));
		face *= smoothstep(19.0, 20.0, edge.x + edge.y);
		float ornament = abs(point.x - source_size.x * 0.5) + edge.y;
		face *= smoothstep(11.5, 12.5, ornament);
		COLOR.rgb *= mix(vec3(1.0), vec3(0.23, 0.235, 0.23), face);
	}
}
