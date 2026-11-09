shader_type spatial;
render_mode cull_disabled;
// Blends 5 CC0 texture layers (meadow, sand, gravel, rock, snow) by a splat map.
// Meadow is whatever the splat doesn't claim. Two scales per layer hide tiling.

uniform sampler2D splat : filter_linear, repeat_disable;
uniform sampler2DArray albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2DArray normal_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D macro : filter_linear, repeat_enable;
uniform float map_half = 512.0;
uniform bool use_normals = true;

varying vec3 world_pos;

const float TILE = 0.28;
const float ROUGH[6] = float[](0.95, 0.9, 0.88, 0.82, 0.6, 0.95);

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 s = texture(splat, (world_pos.xz + map_half) / (2.0 * map_half));
	float w[6];
	w[1] = s.r; w[2] = s.g; w[3] = s.b; w[4] = s.a;
	float meadow = max(0.0, 1.0 - (s.r + s.g + s.b + s.a));
	// Meadow is split between green grass and dirt patches by a large-scale noise.
	float patches = smoothstep(0.56, 0.8, texture(macro, world_pos.xz * 0.0021 + vec2(0.5)).r);
	w[0] = meadow * (1.0 - patches);
	w[5] = meadow * patches;
	vec2 uv = world_pos.xz * TILE;
	vec2 uv2 = world_pos.xz * TILE * 0.23 + vec2(0.37, 0.11);
	vec3 col = vec3(0.0);
	vec3 nm = vec3(0.0);
	float rough = 0.0;
	for (int i = 0; i < 6; i++) {
		if (w[i] > 0.004) {
			vec3 a = mix(texture(albedo_tex, vec3(uv, float(i))).rgb, texture(albedo_tex, vec3(uv2, float(i))).rgb, 0.45);
			col += a * w[i];
			rough += ROUGH[i] * w[i];
			if (use_normals) {
				nm += texture(normal_tex, vec3(uv, float(i))).rgb * w[i];
			}
		}
	}
	float m = texture(macro, world_pos.xz * 0.004).r;
	col *= mix(0.82, 1.12, m);
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.3;
	if (use_normals) {
		NORMAL_MAP = nm;
		NORMAL_MAP_DEPTH = 0.9;
	}
}
