shader_type canvas_item;

// 仅为素材包缺少的宝蓝、黄色纸托着色；已有对应原图的纸托保持原色。
uniform bool enabled = false;
uniform vec4 flavor_color : source_color = vec4(1.0);
varying vec4 vertex_tint;

void vertex() {
	vertex_tint = COLOR;
}

void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	if (enabled) {
		float light = dot(texel.rgb, vec3(0.299, 0.587, 0.114));
		vec3 tint = mix(flavor_color.rgb * 0.4, flavor_color.rgb, smoothstep(0.15, 0.75, light));
		texel.rgb = mix(tint, vec3(1.0), smoothstep(0.75, 1.0, light) * 0.38);
	}
	COLOR = texel * vertex_tint;
}
