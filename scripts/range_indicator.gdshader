// 보스 공격 범위 — 바닥에 부채꼴. progress 가 0→1 로 차오르고(예비동작), parry_cue 가 1이면 패리 타이밍 색
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;

uniform float range_m = 4.0;
uniform float arc_deg = 90.0;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float parry_cue : hint_range(0.0, 1.0) = 0.0;
uniform float alpha_mul : hint_range(0.0, 1.0) = 1.0;

varying vec3 lpos;

void vertex() {
	lpos = VERTEX;
}

void fragment() {
	float d = length(lpos.xz);
	vec2 dir = d > 0.001 ? lpos.xz / d : vec2(0.0, -1.0);
	float ang = degrees(acos(clamp(dot(dir, vec2(0.0, -1.0)), -1.0, 1.0)));
	float inside = step(d, range_m) * step(ang, arc_deg * 0.5);
	float ring = inside * (1.0 - smoothstep(range_m - 0.18, range_m, d)) * smoothstep(range_m - 0.32, range_m - 0.18, d);
	float edge_arc = inside * (1.0 - smoothstep(arc_deg * 0.5 - 4.0, arc_deg * 0.5, ang)) * smoothstep(arc_deg * 0.5 - 6.0, arc_deg * 0.5 - 4.0, ang);
	float fill = inside * step(d, range_m * progress);
	vec3 danger = vec3(0.95, 0.15, 0.1);
	vec3 cue = vec3(1.0, 0.95, 0.45);
	vec3 col = mix(danger, cue, parry_cue);
	float a = inside * 0.12 + fill * 0.3 + ring * 0.6 + edge_arc * 0.6;
	ALBEDO = col;
	EMISSION = col * (0.6 + parry_cue * 0.8);
	ALPHA = clamp(a, 0.0, 0.85) * alpha_mul;
}
