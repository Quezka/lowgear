extends Node
## Save data, settings, input map, shared UI theme and the screenshot test mode.

signal settings_changed
signal career_changed

const XP_PER_LEVEL := 1000
const START_OWNED := ["panda4x4", "niva", "mini_rally"]
## Upgrade prices; trucks pay double for tyres.
const TYRE_PRICE := {"highway": 0, "allroad": 400, "mud": 900, "chains": 700}
const SNORKEL_PRICE := 1200
const ENGINE_PRICE := 2500
const TANK_PRICE := 1000

const SAVE_PATH := "user://save.cfg"
const DARK := Color("#2b2d42")
const CREAM := Color("#fff8f0")
const MUTED := Color("#6d6875")

var car_id: String = "panda4x4"
var coins: Dictionary = {}
var viewpoints: Dictionary = {}
var odometer: Dictionary = {}
var career: Dictionary = {"money": 3000, "xp": 0, "owned": START_OWNED.duplicate(), "maps": {}}
var map_id := "island"
var waypoint := Vector3.INF
var settings: Dictionary = {
	"music": 0.7,
	"sfx": 0.9,
	"engine": 0.8,
	"grain": true,
	"shadows": true,
	"fullscreen": true,
	"auto_gearbox": false,
	"manual_clutch": false,
	"name": "Driver",
	"quality": -1,
	"ui_scale": 1.0,
	"cam_zoom": -1.0,
	"garage": {},
	"last_ip": "",
}

## Test mode: `godot --path . -- --shot [--menu] [--car=id] [--out=dir] [--tod=0.8]`
var shot_mode := false
var ui_open := false  ## a menu is open over the drive: cars ignore input
## `godot --headless --path . -- --server` runs a relay for multiplayer with no window.
var server_mode := false
var shot_args: Dictionary = {}

var _theme: Theme


var font_regular: Font
var font_bold: Font


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Manrope (OFL), the same face as the other Quezka apps, everywhere.
	font_regular = load("res://assets/fonts/Manrope-SemiBold.ttf")
	font_bold = load("res://assets/fonts/Manrope-Bold.ttf")
	ThemeDB.fallback_font = font_regular
	_setup_input()
	load_game()
	_parse_args()
	apply_window()


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			shot_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	shot_mode = shot_args.has("shot")
	server_mode = shot_args.has("server")
	if shot_args.has("car"):
		car_id = str(shot_args["car"])


func apply_window() -> void:
	if server_mode:
		return
	get_window().content_scale_factor = clampf(float(settings.get("ui_scale", 1.0)), 0.75, 1.5)
	if shot_mode:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1366, 768))
		return
	if settings["fullscreen"]:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)


func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	if key == "fullscreen" or key == "ui_scale":
		apply_window()
	settings_changed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		set_setting("fullscreen", not settings["fullscreen"])


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


# --- save -------------------------------------------------------------------

func load_game() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	car_id = cf.get_value("game", "car", car_id)
	coins = cf.get_value("game", "coins", {})
	viewpoints = cf.get_value("game", "viewpoints", {})
	odometer = cf.get_value("game", "odometer", {})
	var c: Dictionary = cf.get_value("game", "career", {})
	for k in c:
		career[k] = c[k]
	if c.is_empty():
		# Saves from before the career: pay out what was already collected.
		career["money"] = 3000 + coins.size() * 25 + viewpoints.size() * 400
		career["xp"] = coins.size() * 5 + viewpoints.size() * 150
	var s: Dictionary = cf.get_value("game", "settings", {})
	for k in s:
		settings[k] = s[k]


func save_game() -> void:
	if shot_mode or server_mode:
		return
	var cf := ConfigFile.new()
	cf.set_value("game", "car", car_id)
	cf.set_value("game", "coins", coins)
	cf.set_value("game", "viewpoints", viewpoints)
	cf.set_value("game", "odometer", odometer)
	cf.set_value("game", "career", career)
	cf.set_value("game", "settings", settings)
	cf.save(SAVE_PATH)


## Per-vehicle setup: equipped tyres and snorkel, plus what has been bought.
func garage_for(id: String) -> Dictionary:
	var spec := CarSpecs.get_spec(id)
	var g: Dictionary = (settings.get("garage", {}) as Dictionary).get(id, {})
	var stock := str(spec.get("tyres", "allroad"))
	return {
		"tyres": str(g.get("tyres", stock)),
		"owned_tyres": g.get("owned_tyres", [stock]),
		"snorkel": bool(g.get("snorkel", false)),
		"has_snorkel": bool(g.get("has_snorkel", false)),
		"engine": bool(g.get("engine", false)),
		"tank": bool(g.get("tank", false)),
	}


## The vehicle's spec with its bought upgrades applied (engine, tank).
func spec_for(id: String) -> Dictionary:
	var spec := CarSpecs.get_spec(id).duplicate(true)
	var g := garage_for(id)
	if g["engine"]:
		spec["drivetrain"]["torque"] = float(spec["drivetrain"]["torque"]) * 1.18
	if g["tank"]:
		spec["fuel"] = float(spec["fuel"]) * 1.5
	return spec


# --- career -------------------------------------------------------------------

func money() -> int:
	return int(career.get("money", 0))


func level() -> int:
	return 1 + int(career.get("xp", 0)) / XP_PER_LEVEL


func level_progress() -> float:
	return float(int(career.get("xp", 0)) % XP_PER_LEVEL) / XP_PER_LEVEL


func owns(id: String) -> bool:
	return (career.get("owned", START_OWNED) as Array).has(id)


func reward(cash: int, xp: int) -> void:
	var before := level()
	career["money"] = money() + cash
	career["xp"] = int(career.get("xp", 0)) + xp
	career_changed.emit()
	if level() > before:
		Sfx.play("discover")
	save_game()


## Spends money if there is enough; returns whether it did.
func spend(cash: int) -> bool:
	if money() < cash:
		return false
	career["money"] = money() - cash
	career_changed.emit()
	save_game()
	return true


func buy_vehicle(id: String) -> String:
	var spec := CarSpecs.get_spec(id)
	if owns(id):
		return "You already own it"
	if level() < int(spec.get("level", 1)):
		return "Needs level %d" % int(spec["level"])
	if not spend(int(spec.get("price", 0))):
		return "Not enough money"
	(career["owned"] as Array).append(id)
	save_game()
	return ""


## Per-map progress: {"contracts": {id: {"got": {type: n}, "done": bool, "runs": int}}, "built": [], "fog": String}
func map_state() -> Dictionary:
	var maps: Dictionary = career.get("maps", {})
	if not maps.has(map_id):
		maps[map_id] = {"contracts": {}, "built": [], "fog": ""}
	career["maps"] = maps
	return maps[map_id]


func set_garage(id: String, key: String, value: Variant) -> void:
	var all: Dictionary = settings.get("garage", {})
	var g: Dictionary = all.get(id, {})
	g[key] = value
	all[id] = g
	settings["garage"] = all
	save_game()


## 0 low, 1 medium, 2 high. -1 in the settings means "pick for this device".
func quality() -> int:
	if shot_args.has("quality"):
		return clampi(int(shot_args["quality"]), 0, 2)
	var q := int(settings.get("quality", -1))
	if q >= 0:
		return clampi(q, 0, 2)
	return 0 if OS.has_feature("mobile") else 1


func add_distance(id: String, metres: float) -> void:
	odometer[id] = float(odometer.get(id, 0.0)) + metres


# --- input ------------------------------------------------------------------

func _setup_input() -> void:
	_keys("gas", [KEY_W, KEY_UP])
	_keys("brake", [KEY_S, KEY_DOWN])
	_keys("left", [KEY_A, KEY_LEFT])
	_keys("right", [KEY_D, KEY_RIGHT])
	_keys("handbrake", [KEY_SPACE])
	_keys("reset", [KEY_R])
	_keys("camera", [KEY_C])
	_keys("pause", [KEY_ESCAPE, KEY_P])
	_keys("fullscreen", [KEY_F11])
	_keys("shift_up", [KEY_E, KEY_PAGEUP])
	_keys("shift_down", [KEY_Q, KEY_PAGEDOWN])
	_keys("low_range", [KEY_L])
	_keys("clutch", [KEY_SHIFT])
	_keys("zoom_in", [KEY_EQUAL, KEY_KP_ADD])
	_keys("zoom_out", [KEY_MINUS, KEY_KP_SUBTRACT])
	_keys("interact", [KEY_T, KEY_ENTER])
	_keys("map", [KEY_M, KEY_TAB])
	_button("interact", JOY_BUTTON_B)
	_button("map", JOY_BUTTON_BACK)
	_keys("lights", [KEY_F])
	_keys("hazards", [KEY_Y])
	_button("lights", JOY_BUTTON_LEFT_STICK)
	_keys("awd", [KEY_X])
	_keys("diff", [KEY_Z])
	_keys("winch", [KEY_G])
	_keys("winch_in", [KEY_H])
	_keys("ignition", [KEY_I])
	_button("awd", JOY_BUTTON_DPAD_UP)
	_button("diff", JOY_BUTTON_DPAD_DOWN)
	_button("winch", JOY_BUTTON_DPAD_RIGHT)
	_button("winch_in", JOY_BUTTON_DPAD_LEFT)
	_button("ignition", JOY_BUTTON_RIGHT_STICK)
	_button("shift_up", JOY_BUTTON_RIGHT_SHOULDER)
	_button("shift_down", JOY_BUTTON_LEFT_SHOULDER)
	_button("low_range", JOY_BUTTON_BACK)
	_axis("gas", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_axis("brake", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_axis("left", JOY_AXIS_LEFT_X, -1.0)
	_axis("right", JOY_AXIS_LEFT_X, 1.0)
	_button("handbrake", JOY_BUTTON_A)
	_button("reset", JOY_BUTTON_Y)
	_button("camera", JOY_BUTTON_X)
	_button("pause", JOY_BUTTON_START)


func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)


func _keys(action: String, keys: Array) -> void:
	_ensure(action)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)


func _axis(action: String, axis: JoyAxis, value: float) -> void:
	_ensure(action)
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	InputMap.action_add_event(action, e)


func _button(action: String, button: JoyButton) -> void:
	_ensure(action)
	var e := InputEventJoypadButton.new()
	e.button_index = button
	InputMap.action_add_event(action, e)


# --- UI helpers ---------------------------------------------------------------

## Light text with a dark outline for over the 3D view, or dark text for panels.
func label_settings(size: int, on_panel := false, color := Color.TRANSPARENT) -> LabelSettings:
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.font = font_bold if size >= 30 else font_regular
	if on_panel:
		ls.font_color = DARK if color == Color.TRANSPARENT else color
	else:
		ls.font_color = CREAM if color == Color.TRANSPARENT else color
		ls.outline_size = maxi(6, size / 4)
		ls.outline_color = DARK
	return ls


func ui_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 28
	t.default_font = font_regular
	for type in ["Button", "CheckButton"]:
		t.set_stylebox("normal", type, _box(Color("#fff4e6")))
		t.set_stylebox("hover", type, _box(Color("#ffe1cc")))
		t.set_stylebox("pressed", type, _box(Color("#f6c1cf")))
		t.set_stylebox("hover_pressed", type, _box(Color("#f6c1cf")))
		t.set_stylebox("disabled", type, _box(Color("#e8e2dc")))
		var focus := _box(Color(0, 0, 0, 0), Color("#6c4ee0"), 5)
		focus.draw_center = false
		t.set_stylebox("focus", type, focus)
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color",
				"icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
			t.set_color(c, type, DARK)
		t.set_constant("icon_max_width", type, 30)
		t.set_constant("h_separation", type, 10)
	t.set_color("font_color", "Label", DARK)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(CREAM, 0.94)
	panel.set_corner_radius_all(24)
	panel.set_border_width_all(3)
	panel.border_color = DARK
	panel.set_content_margin_all(30)
	t.set_stylebox("panel", "PanelContainer", panel)
	var slider := StyleBoxFlat.new()
	slider.bg_color = Color("#d8cfe8")
	slider.set_corner_radius_all(6)
	slider.content_margin_top = 6
	slider.content_margin_bottom = 6
	t.set_stylebox("slider", "HSlider", slider)
	var fill := slider.duplicate() as StyleBoxFlat
	fill.bg_color = Color("#9b8ae6")
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	# Primary (mint) button and text fields.
	t.set_type_variation("PrimaryButton", "Button")
	t.set_stylebox("normal", "PrimaryButton", _box(Color("#9ed9c5")))
	t.set_stylebox("hover", "PrimaryButton", _box(Color("#b5e6d5")))
	t.set_stylebox("pressed", "PrimaryButton", _box(Color("#84c7b0")))
	t.set_font_size("font_size", "PrimaryButton", 32)
	var field := _box(Color.WHITE)
	t.set_stylebox("normal", "LineEdit", field)
	var field_focus := _box(Color.WHITE, Color("#6c4ee0"), 4)
	t.set_stylebox("focus", "LineEdit", field_focus)
	t.set_color("font_color", "LineEdit", DARK)
	t.set_color("font_placeholder_color", "LineEdit", MUTED)
	t.set_color("caret_color", "LineEdit", DARK)
	t.set_font_size("font_size", "LineEdit", 26)
	_theme = t
	return t


func _box(bg: Color, border := DARK, width := 3) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.set_corner_radius_all(14)
	b.set_border_width_all(width)
	b.border_color = border
	b.content_margin_left = 22
	b.content_margin_right = 22
	b.content_margin_top = 10
	b.content_margin_bottom = 10
	return b


# --- test mode ----------------------------------------------------------------

func screenshot(file_name: String) -> void:
	var dir := str(shot_args.get("out", "user://shots"))
	DirAccess.make_dir_recursive_absolute(dir)
	var img := get_viewport().get_texture().get_image()
	var path := dir.path_join(file_name)
	img.save_png(path)
	print("[shot] saved ", ProjectSettings.globalize_path(path))
