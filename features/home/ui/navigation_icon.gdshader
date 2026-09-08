shader_type canvas_item;
// 把纸面深墨图标映射为浅金主形与深铜内纹，透明轮廓和入口明度反馈保持独立。
uniform vec4 metal_color : source_color = vec4(0.91, 0.81, 0.59, 1.0);
uniform vec4 inlay_color : source_color = vec4(0.30, 0.22, 0.12, 1.0);
varying vec4 entry_tint;

void vertex() {
	entry_tint = COLOR;
}

void fragment() {
	vec4 artwork = texture(TEXTURE, UV);
	float luminance = dot(artwork.rgb, vec3(0.299, 0.587, 0.114));
	vec3 metal = mix(metal_color.rgb, inlay_color.rgb, smoothstep(0.12, 0.76, luminance));
	COLOR = vec4(metal * entry_tint.rgb, artwork.a * entry_tint.a);
}
