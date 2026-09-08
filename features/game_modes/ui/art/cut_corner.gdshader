shader_type canvas_item;

uniform vec2 extent = vec2(725.0, 1044.0);
uniform vec2 corner = vec2(25.0);
uniform bool clear_black = false;
varying vec2 point;

void vertex() {
	point = VERTEX;
}

void fragment() {
	vec2 p = min(point, extent - point);
	float edge = (p.x / corner.x + p.y / corner.y - 1.0) * min(corner.x, corner.y);
	COLOR.a *= smoothstep(0.0, max(fwidth(edge), 0.5), edge);
	if (clear_black) {
		vec3 source = texture(TEXTURE, UV).rgb;
		COLOR.a *= smoothstep(0.004, 0.035, max(source.r, max(source.g, source.b)));
		// 九宫边片含有一段黑色内场，只保留实际金属边沿，避免放大后出现暗点。
		float inset = min(min(p.x, p.y), (p.x + p.y - corner.x) * 0.707107);
		COLOR.a *= 1.0 - smoothstep(13.0, 15.0, inset);
	}
}
