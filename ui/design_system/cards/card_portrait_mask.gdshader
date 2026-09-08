shader_type canvas_item;

uniform vec2 extent = vec2(95.0, 113.0);
uniform float corner_radius = 7.5;
uniform bool dimmed = false;
uniform float caption_height = 0.0;
varying vec4 tint;
varying vec2 point;

void vertex() {
	tint = COLOR;
	point = VERTEX;
}

void fragment() {
	COLOR = texture(TEXTURE, UV) * tint;
	if (dimmed) {
		float gray = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
		COLOR.rgb = vec3(gray) * 0.62;
	}
	if (caption_height > 0.0) {
		float band = smoothstep(extent.y - caption_height, extent.y, point.y);
		COLOR.rgb *= 1.0 - band * 0.78;
	}
	vec2 centered = abs(point - extent * 0.5) - (extent * 0.5 - vec2(corner_radius));
	float distance = length(max(centered, vec2(0.0))) + min(max(centered.x, centered.y), 0.0) - corner_radius;
	float antialias = max(fwidth(distance), 0.5);
	COLOR.a *= 1.0 - smoothstep(-antialias, antialias, distance);
}
