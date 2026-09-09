// 暗色石质战场叠加低频魔力流动；时间由战斗回放注入，暂停时不会继续变化。
shader_type canvas_item;
render_mode unshaded;

uniform float battle_time = 0.0;

float hash(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec2 centered = UV - vec2(0.5);
	float vignette = smoothstep(0.78, 0.24, length(centered * vec2(0.86, 1.0)));
	float breath = 0.5 + 0.5 * sin(battle_time * 0.72);
	vec2 cell = floor(UV * vec2(9.0, 16.0));
	float spark_seed = hash(cell);
	float drift = fract(UV.y + battle_time * (0.008 + spark_seed * 0.006) + spark_seed);
	float mote = smoothstep(0.035, 0.0, length(fract(UV * vec2(9.0, 16.0)) - vec2(spark_seed, drift))) * step(0.78, spark_seed);
	float warm_pool = exp(-length((UV - vec2(0.22, 0.72)) * vec2(1.6, 1.0)) * 8.5);
	float arcane_pool = exp(-length((UV - vec2(0.78, 0.29)) * vec2(1.5, 1.0)) * 9.0);
	vec3 color = source.rgb * mix(0.78, 1.02, vignette);
	color += vec3(0.30, 0.13, 0.035) * warm_pool * (0.09 + breath * 0.04);
	color += vec3(0.13, 0.10, 0.28) * arcane_pool * (0.075 + (1.0 - breath) * 0.035);
	color += vec3(1.0, 0.54, 0.16) * mote * 0.16;
	COLOR = vec4(color, source.a) * COLOR;
}
