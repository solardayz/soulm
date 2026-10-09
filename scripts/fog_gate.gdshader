// 안개문 — 다크소울의 흰 안개. 텍스처 없이 노이즈로 흐르는 안개를 그린다
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform float push : hint_range(0.0, 1.0) = 0.0; // 통과 연출 때 밝아짐
uniform float fade : hint_range(0.0, 1.0) = 1.0; // 보스 처치 후 0으로
uniform vec3 tint : source_color = vec3(0.86, 0.9, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int k = 0; k < 5; k++) {
		v += a * vnoise(p);
		p = p * 2.07 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * 0.12;
	float n = fbm(uv * vec2(2.5, 3.5) + vec2(t, -t * 0.6)) * 0.6 + fbm(uv * vec2(6.0, 8.0) - vec2(t * 0.4, t * 1.1)) * 0.4;
	float edge = smoothstep(0.0, 0.22, uv.x) * smoothstep(1.0, 0.78, uv.x) * smoothstep(0.0, 0.18, uv.y) * smoothstep(1.0, 0.85, uv.y);
	float a = clamp((n * 1.9 - 0.3) * edge + push * 0.7, 0.0, 1.0) * fade;
	ALBEDO = tint * (0.75 + 0.45 * n);
	EMISSION = tint * (0.35 + push * 1.2);
	ALPHA = a * 0.9;
}
