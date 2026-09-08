shader_type spatial;
render_mode cull_disabled;

// 每个真实骰面独立取无字图集块；金额由共面的原生文字绘制。
uniform sampler2D surface_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 tile_origin;
uniform float surface_metallic = 0.3;

void fragment() {
	vec2 face_uv = clamp(UV, vec2(0.012), vec2(0.988));
	ALBEDO = texture(surface_atlas, tile_origin + face_uv * 0.5).rgb;
	METALLIC = surface_metallic;
	ROUGHNESS = 0.72;
}
