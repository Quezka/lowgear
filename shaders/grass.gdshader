shader_type spatial;
render_mode cull_disabled;
// Grass clumps near the camera: wind, fade-out with distance, colour from instance tint.

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform float radius = 30.0;
uniform vec3 cam_pos;

varying float fade;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float d = distance(wp.xz, cam_pos.xz);
	fade = 1.0 - smoothstep(radius * 0.7, radius, d);
	float bend = UV.y < 0.5 ? 1.0 : 0.0;
	float wind = sin(TIME * 1.7 + wp.x * 0.35 + wp.z * 0.25) * 0.12 + sin(TIME * 3.1 + wp.x) * 0.03;
	VERTEX.x += wind * bend;
	VERTEX.y *= fade;
}

void fragment() {
	vec4 c = texture(tex, UV);
	if (c.a < 0.45 || fade < 0.02) {
		discard;
	}
	ALBEDO = c.rgb * COLOR.rgb;
	ROUGHNESS = 0.9;
	SPECULAR = 0.1;
	BACKLIGHT = vec3(0.3, 0.35, 0.15);
}
