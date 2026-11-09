shader_type canvas_item;
// "Realistic but soft": gentle saturation, lifted lavender shadows, warm pastel highlights,
// fine grain and a soft vignette. Drawn under the HUD.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float grain = 0.03;
uniform float vignette = 0.25;

float rnd(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, 0.86);
	c = c * 0.9 + 0.055;
	c += vec3(0.03, 0.012, 0.05) * (1.0 - l);
	c *= mix(vec3(1.0), vec3(1.05, 1.0, 0.93), smoothstep(0.4, 1.0, l));
	float n = rnd(floor(FRAGCOORD.xy * 0.5) + fract(TIME * 7.0) * 113.0) - 0.5;
	c += n * grain;
	float d = distance(SCREEN_UV, vec2(0.5));
	c = mix(c, c * vec3(0.78, 0.72, 0.86), smoothstep(0.45, 0.95, d) * vignette * 2.0);
	COLOR = vec4(c, 1.0);
}
