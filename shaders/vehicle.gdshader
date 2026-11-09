shader_type spatial;
// Vehicle paint: soft satin colour that gets mud splashed up from the bottom as you drive.

uniform vec3 paint : source_color = vec3(0.8);
uniform float roughness = 0.42;
uniform float dirt = 0.0;
uniform float damage = 0.0;
uniform float dirt_top = 1.6;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap, repeat_enable;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec3 p = local_pos * 1.3;
	vec3 d = texture(dirt_tex, p.xy * 0.5 + p.z * 0.31).rgb * 0.7;
	float n = texture(dirt_tex, p.zy * 0.37 + p.x * 0.21).r;
	float height_mask = 1.0 - smoothstep(dirt_top * 0.2, dirt_top, local_pos.y + n * 0.6);
	float m = clamp(dirt * 1.4 * height_mask + (dirt > 0.5 ? (dirt - 0.5) * 0.5 : 0.0), 0.0, 1.0);
	m = smoothstep(0.25, 0.7, m * (0.6 + n * 0.8));
	vec3 col = mix(paint, d, m);
	// Scratches and dents show bare grey metal as damage grows.
	float s = texture(dirt_tex, p.xz * 2.7 + p.y * 1.9).g;
	float scratch = smoothstep(1.0 - damage * 0.55, 1.0 - damage * 0.5, s) * step(0.05, damage);
	ALBEDO = mix(col, vec3(0.55, 0.56, 0.58), scratch);
	ROUGHNESS = mix(roughness, 0.95, m);
	METALLIC = mix(0.15, 0.0, m);
	SPECULAR = 0.45;
}
