shader_type canvas_item;

// 锁定位整盒去色；香草订单使用奶油色外观，原始 PNG 保持不变。
uniform float neutral_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 neutral_tint : source_color = vec4(1.0);

void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	float gray = dot(texel.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(texel.rgb, vec3(gray) * neutral_tint.rgb, neutral_amount), texel.a);
}
