shader_type canvas_item;
// 深色底图集原样取色，轮廓内保留黑底；仅外围与纸面饰线做透明分离。
uniform vec4 keep_rect = vec4(0.0);
uniform float corner_cut_radius = 0.0;
uniform vec3 keep_circle = vec3(0.0);
uniform bool paper_ornament = false;
varying vec4 artwork_tint;

void vertex() {
	artwork_tint = COLOR;
}

void fragment() {
	vec4 artwork = texture(TEXTURE, UV);
	vec2 point = UV * vec2(textureSize(TEXTURE, 0));
	float brightness = max(artwork.r, max(artwork.g, artwork.b));
	float coverage = smoothstep(0.075, 0.16, brightness);
	vec3 matte = vec3(0.064);
	if (paper_ornament) {
		coverage = 1.0 - smoothstep(0.50, 0.80, brightness);
		matte = vec3(0.84, 0.76, 0.66);
	} else {
		bool in_rect = keep_rect.z > 0.0 && all(greaterThanEqual(point, keep_rect.xy)) && all(lessThanEqual(point, keep_rect.xy + keep_rect.zw));
		// 标题牌的内凹圆角只保留轮廓内黑底，避免矩形底色盖住羊皮纸。
		vec2 corner = min(point - keep_rect.xy, keep_rect.xy + keep_rect.zw - point);
		in_rect = in_rect && length(corner) >= corner_cut_radius;
		bool in_circle = keep_circle.z > 0.0 && distance(point, keep_circle.xy) <= keep_circle.z;
		if (in_rect || in_circle) { coverage = 1.0; }
	}
	// 仅移除边缘混入的底色，金色高光和象牙白纸面保持原像素颜色。
	vec3 ink = clamp((artwork.rgb - matte * (1.0 - coverage)) / max(coverage, 0.001), vec3(0.0), vec3(1.0));
	COLOR = vec4(ink, artwork.a * coverage) * artwork_tint;
}
