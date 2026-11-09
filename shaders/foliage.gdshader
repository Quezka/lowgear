shader_type spatial;
render_mode cull_disabled;
// Leaf and needle cards: alpha cut-out, a gentle sway, per-instance colour tint,
// softened lighting so the cards don't look flat.

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform float sway = 0.06;

void vertex() {
	float h = max(VERTEX.y, 0.0);
	vec3 wp = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float s = sin(TIME * 1.1 + wp.x * 0.13 + wp.z * 0.17) * sway * h * 0.15;
	VERTEX.x += s;
	VERTEX.z += s * 0.6;
}

void fragment() {
	vec4 c = texture(tex, UV);
	// Fade out foliage right in front of the camera (dithered) so it never blocks the view.
	float near_fade = smoothstep(2.5, 6.0, length(VERTEX));
	float dither = fract(sin(dot(floor(FRAGCOORD.xy), vec2(12.9898, 78.233))) * 43758.5453);
	if (c.a < 0.5 || dither > near_fade) {
		discard;
	}
	ALBEDO = c.rgb * COLOR.rgb;
	ROUGHNESS = 0.85;
	SPECULAR = 0.15;
	BACKLIGHT = vec3(0.25, 0.3, 0.15);
}
