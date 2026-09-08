shader_type canvas_item;
// 纯黑底素材只移除外围底色，保留布纹和金线；不影响原生文字与真实命中区。
varying vec4 artwork_tint;
void vertex() { artwork_tint = COLOR; }
void fragment() {
    vec4 artwork = texture(TEXTURE, UV);
    float coverage = smoothstep(0.008, 0.032, max(artwork.r, max(artwork.g, artwork.b)));
    COLOR = vec4(artwork.rgb / max(coverage, 0.001), artwork.a * coverage) * artwork_tint;
}
