shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;
// Sea: colour and opacity from the depth under each point (heights texture), foam at the shore,
// small moving ripples.

uniform sampler2D heights : filter_linear, repeat_disable;
uniform float map_half = 512.0;
uniform vec3 shallow : source_color = vec3(0.56, 0.82, 0.8);
uniform vec3 deep : source_color = vec3(0.24, 0.45, 0.62);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float ripple(vec2 p, float t) {
	return sin(p.x * 0.9 + t * 1.3) * 0.5 + sin(p.y * 1.3 - t * 1.1) * 0.5 + sin((p.x + p.y) * 2.3 + t * 2.0) * 0.25;
}

void fragment() {
	vec2 uv = (world_pos.xz + map_half) / (2.0 * map_half);
	float h = -7.0;
	if (uv.x > 0.0 && uv.y > 0.0 && uv.x < 1.0 && uv.y < 1.0) {
		h = texture(heights, uv).r;
	}
	float depth = max(0.0, -h);
	float t = TIME;
	vec2 p = world_pos.xz;
	float e = 0.15;
	float r0 = ripple(p, t);
	vec3 n = normalize(vec3(r0 - ripple(p + vec2(e, 0.0), t), 6.0, r0 - ripple(p + vec2(0.0, e), t)));
	NORMAL = (VIEW_MATRIX * vec4(n, 0.0)).xyz;
	vec3 col = mix(shallow, deep, smoothstep(0.0, 5.0, depth));
	float foam = (1.0 - smoothstep(0.05, 0.5, depth)) * (0.6 + 0.4 * sin(t * 1.5 + p.x * 0.7 + p.y * 0.4));
	col = mix(col, vec3(0.97, 0.98, 0.96), clamp(foam, 0.0, 1.0));
	ALBEDO = col;
	ALPHA = clamp(mix(0.45, 0.9, smoothstep(0.0, 3.0, depth)) + foam * 0.4, 0.0, 1.0);
	ROUGHNESS = 0.08;
	SPECULAR = 0.6;
}
