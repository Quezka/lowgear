extends Node
## Save data, settings, input map, shared UI theme and the screenshot test mode.

signal settings_changed

const SAVE_PATH := "user://save.cfg"
const DARK := Color("#2b2d42")
const CREAM := Color("#fff8f0")
const MUTED := Color("#6d6875")

var car_id: String = "panda4x4"
var coins: Dictionary = {}
var viewpoints: Dictionary = {}
var odometer: Dictionary = {}
var settings: Dictionary = {
	"music": 0.7,
	"sfx": 0.9,
	"engine": 0.8,
	"grain": true,
	"shadows": true,
	"fullscreen": true,
	"auto_gearbox": false,
}

## Test mode: `godot --path . -- --shot [--menu] [--car=id] [--out=dir] [--tod=0.8]`
var shot_mode := false
var shot_args: Dictionary = {}

var _theme: Theme


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	if shot_args.has("car"):
		car_id = str(shot_args["car"])


func apply_window() -> void:
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
	if key == "fullscreen":
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
	var s: Dictionary = cf.get_value("game", "settings", {})
	for k in s:
		settings[k] = s[k]


func save_game() -> void:
	if shot_mode:
		return
	var cf := ConfigFile.new()
	cf.set_value("game", "car", car_id)
	cf.set_value("game", "coins", coins)
	cf.set_value("game", "viewpoints", viewpoints)
	cf.set_value("game", "odometer", odometer)
	cf.set_value("game", "settings", settings)
	cf.save(SAVE_PATH)


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
	for type in ["Button", "CheckButton"]:
		t.set_stylebox("normal", type, _box(Color("#fff4e6")))
		t.set_stylebox("hover", type, _box(Color("#ffe1cc")))
		t.set_stylebox("pressed", type, _box(Color("#f6c1cf")))
		t.set_stylebox("hover_pressed", type, _box(Color("#f6c1cf")))
		t.set_stylebox("disabled", type, _box(Color("#e8e2dc")))
		var focus := _box(Color(0, 0, 0, 0), Color("#6c4ee0"), 5)
		focus.draw_center = false
		t.set_stylebox("focus", type, focus)
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			t.set_color(c, type, DARK)
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
