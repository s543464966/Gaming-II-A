shader_type canvas_item;
// 将属性原色收束为随节点状态变化的金属单色，同时保留原图明暗层次。
varying vec4 node_tint;

void vertex() {
	node_tint = COLOR;
}

void fragment() {
	vec4 artwork = texture(TEXTURE, UV);
	float luminance = dot(artwork.rgb, vec3(0.299, 0.587, 0.114));
	float relief = mix(0.72, 1.12, smoothstep(0.12, 0.88, luminance));
	COLOR = vec4(node_tint.rgb * relief, artwork.a * node_tint.a);
}
