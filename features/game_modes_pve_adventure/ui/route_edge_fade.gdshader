shader_type canvas_item;
render_mode unshaded;

// 只淡出路线像素，保留其下方原始地图纹理；独立预览默认不裁淡。
uniform vec2 top_edge = vec2(-1.0, -0.5);

void fragment() {
	COLOR.a *= smoothstep(top_edge.x, top_edge.y, SCREEN_UV.y);
}
