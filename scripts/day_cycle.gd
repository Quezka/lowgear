class_name DayCycle
extends Node
## Moves the sun and blends the pastel sky, fog and light through the day (8 minutes per day).

const LENGTH := 480.0

var t := 0.3
var darkness := 0.0
var env: Environment
var sky_mat: ProceduralSkyMaterial
var sun: DirectionalLight3D


func setup(world_env: WorldEnvironment, light: DirectionalLight3D, start_t := 0.3) -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_curve = 0.12
	sky_mat.ground_curve = 0.05
	sky_mat.sun_angle_max = 20.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_density = 0.0032
	env.fog_sky_affect = 0.3
	world_env.environment = env
	sun = light
	t = start_t
	apply()


func _process(delta: float) -> void:
	t = fposmod(t + delta / LENGTH, 1.0)
	apply()


func apply() -> void:
	var p := Palette.sample(t)
	var top: Color = p["top"]
	var horizon: Color = p["horizon"]
	var fog: Color = p["fog"]
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = horizon
	sky_mat.ground_horizon_color = horizon
	sky_mat.ground_bottom_color = fog.darkened(0.2)
	env.fog_light_color = fog
	env.ambient_light_color = horizon.lerp(top, 0.4)
	env.ambient_light_energy = p["ambient"]
	sun.light_color = p["light"]
	sun.light_energy = p["energy"]
	var e := sin((t - 0.25) * TAU)  # +1 noon, -1 midnight; the moon uses the mirrored arc
	var elev := maxf(absf(e), 0.1)
	sun.rotation = Vector3(-lerpf(0.15, 1.1, elev), t * TAU + 0.6, 0.0)
	darkness = clampf(-e * 3.0 + 0.2, 0.0, 1.0)
