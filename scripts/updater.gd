extends Node
## Autoload "Updater": checks GitHub for a newer release and installs it on request.
## Linux/Windows replace their own executable and restart; Android opens the new APK.

signal update_available(version: String)
signal progress(text: String)

const REPO := "Quezka/lowgear"
const API := "https://api.github.com/repos/%s/releases/latest" % REPO

var latest := ""
var _assets: Dictionary = {}  ## name -> download url
var _http: HTTPRequest
var _checked := false


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 15.0
	add_child(_http)
	_cleanup_old()


func check() -> void:
	if _checked or GameState.server_mode or GameState.shot_mode or OS.has_feature("editor"):
		return
	_checked = true
	_http.request_completed.connect(_on_release, CONNECT_ONE_SHOT)
	_http.request(API, ["User-Agent: lowgear-updater", "Accept: application/vnd.github+json"])


func _on_release(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not data is Dictionary:
		return
	var tag := str((data as Dictionary).get("tag_name", "")).trim_prefix("v")
	if tag.is_empty() or not is_newer(tag, Net.version()):
		return
	for a in (data as Dictionary).get("assets", []):
		_assets[str(a["name"])] = str(a["browser_download_url"])
	if _asset_name().is_empty() or not _assets.has(_asset_name()):
		return
	latest = tag
	update_available.emit(tag)


static func is_newer(a: String, b: String) -> bool:
	var pa := a.split(".")
	var pb := b.split(".")
	for i in maxi(pa.size(), pb.size()):
		var x := int(pa[i]) if i < pa.size() else 0
		var y := int(pb[i]) if i < pb.size() else 0
		if x != y:
			return x > y
	return false


func _asset_name() -> String:
	match OS.get_name():
		"Linux", "FreeBSD": return "lowgear.x86_64"
		"Windows": return "lowgear.exe"
		"Android": return "lowgear.apk"
	return ""


func install() -> void:
	var url: String = _assets.get(_asset_name(), "")
	if url.is_empty():
		return
	if OS.get_name() == "Android":
		# The browser downloads it and hands it to the system installer.
		OS.shell_open(url)
		return
	var exe := OS.get_executable_path()
	var tmp := exe + ".new"
	progress.emit("Downloading %s..." % latest)
	var dl := HTTPRequest.new()
	dl.download_file = tmp
	dl.timeout = 600.0
	add_child(dl)
	dl.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
		dl.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			progress.emit("Download failed, try again later")
			DirAccess.remove_absolute(tmp)
			return
		_swap_and_restart(exe, tmp))
	dl.request(url, ["User-Agent: lowgear-updater"])


func _swap_and_restart(exe: String, tmp: String) -> void:
	var old := exe + ".old"
	DirAccess.remove_absolute(old)
	# Both Linux and Windows allow renaming a running executable.
	if DirAccess.rename_absolute(exe, old) != OK or DirAccess.rename_absolute(tmp, exe) != OK:
		progress.emit("Could not replace the game file (no permission?)")
		return
	if OS.get_name() != "Windows":
		OS.execute("chmod", ["+x", exe])
	progress.emit("Updated, restarting...")
	GameState.save_game()
	OS.create_process(exe, [])
	get_tree().quit()


func _cleanup_old() -> void:
	var old := OS.get_executable_path() + ".old"
	if FileAccess.file_exists(old):
		DirAccess.remove_absolute(old)
