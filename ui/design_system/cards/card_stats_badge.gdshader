shader_type canvas_item;
render_mode unshaded;

uniform vec2 badge_size = vec2(76.0, 18.0);
uniform float output_share = 0.4;
uniform float inner_edge = 1.5;
uniform float corner_radius = 3.0;
uniform vec4 output_color : source_color = vec4(0.847, 0.302, 0.247, 1.0);
uniform vec4 health_color : source_color = vec4(0.144, 0.416, 0.20, 1.0);
uniform float health_ratio : hint_range(0.0, 1.0) = 1.0;
uniform vec4 rim_color : source_color = vec4(0.459, 0.408, 0.298, 1.0);
uniform bool unavailable = false;
varying vec4 modulation;

void vertex() {
	modulation = COLOR;
}

// 正值在矩形内；短圆角只修饰外沿，不倾斜生命条的两端与填充界线。
float rounded_distance(vec2 point, vec2 extent, float radius) {
	vec2 edge = abs(point - extent * 0.5) - extent * 0.5 + vec2(radius);
	return radius - length(max(edge, vec2(0.0))) - min(max(edge.x, edge.y), 0.0);
}

// 分界由实际字宽与固定生命宽度提供；特殊牌从内部左沿起全部用于生命填充。
void fragment() {
	vec2 extent = max(badge_size, vec2(1.0));
	vec2 point = UV * extent;
	vec2 face_extent = extent - vec2(0.0, 1.0);
	float radius = min(corner_radius, min(face_extent.x, face_extent.y) * 0.5);
	float distance = rounded_distance(point, face_extent, radius);
	float alpha = smoothstep(0.3, 1.1, distance);
	float grain = texture(TEXTURE, UV).r;
	float pigment = 0.77 + grain * 0.46;
	vec3 outline = rim_color.rgb * 0.24;
	vec3 rim = rim_color.rgb * pigment * mix(1.12, 0.50, UV.y);
	vec3 color = mix(outline, rim, smoothstep(0.8, 1.4, distance));
	float divider = mix(inner_edge, extent.x - inner_edge, output_share);
	float right = output_share > 0.0 ? smoothstep(divider - 0.45, divider + 0.45, point.x) : 1.0;
	// 正常六类输出小幅提纯提亮；不可用保留原基础色，右区与全局语义色不受影响。
	float peak = max(output_color.r, max(output_color.g, output_color.b));
	vec3 vivid_output = max(mix(vec3(peak), output_color.rgb, 1.10), vec3(0.0));
	vec3 left_color = unavailable ? output_color.rgb * 0.52 : vivid_output * 0.59;
	// 仅缩短右区绿色填充，深色空槽、文字和外框不随生命值移动。
	float ratio = clamp(health_ratio, 0.0, 1.0);
	float fill_end = mix(divider, extent.x - inner_edge, ratio);
	float filled = 1.0 - smoothstep(fill_end - 0.45, fill_end + 0.45, point.x);
	filled = ratio <= 0.0 ? 0.0 : (ratio >= 1.0 ? 1.0 : filled);
	vec3 health_face = mix(health_color.rgb * 0.12, health_color.rgb, filled);
	vec3 face = mix(left_color, health_face, right) * pigment;
	face *= mix(1.08, 0.87, UV.y);
	float seam = output_share > 0.0 ? 1.0 - smoothstep(0.25, 0.85, abs(point.x - divider)) : 0.0;
	face = mix(face, outline, seam * 0.78);
	color = mix(color, face, smoothstep(inner_edge, inner_edge + 0.65, distance));
	float shadow_distance = rounded_distance(point - vec2(0.0, 1.0), face_extent, radius);
	float shadow_alpha = smoothstep(0.0, 1.0, shadow_distance) * 0.45;
	float combined_alpha = alpha + shadow_alpha * (1.0 - alpha);
	vec3 combined_color = (color * alpha + outline * shadow_alpha * (1.0 - alpha)) / max(combined_alpha, 0.001);
	COLOR = vec4(combined_color, combined_alpha) * modulation;
}
