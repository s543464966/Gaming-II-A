shader_type canvas_item;

uniform vec2 extent = vec2(725.0, 1044.0);
uniform vec4 art_region = vec4(0.0, 0.0, 1.0, 1.0);
uniform float corner = 25.0;
varying vec4 tint;
varying vec2 point;

void vertex() {
	tint = COLOR;
	point = VERTEX;
}

void fragment() {
	COLOR = texture(TEXTURE, art_region.xy + UV * art_region.zw) * tint;
	vec2 p = min(point, extent - point);
	float edge = p.x + p.y - corner;
	COLOR.a *= smoothstep(0.0, max(fwidth(edge), 0.5), edge);
}
