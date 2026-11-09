extends Node
## Autoload "Updater": checks GitHub for a newer release and installs it on request.
## Linux/Windows replace their own executable and restart; Android opens the new APK.

signal update_available(version: String)
signal progress(text: String)
signal download_ratio(r: float)
signal checked(found: bool)

const REPO := "Quezka/lowgear"
const API := "https://api.github.com/repos/%s/releases/latest" % REPO

var latest := ""
var notes := ""         ## release notes of the latest version
var size_bytes := 0
var _digest := ""        ## "sha256:..." from GitHub, when it provides one
var _dl: HTTPRequest
var _assets: Dictionary = {}  ## name -> download url
var _http: HTTPRequest
var _checked := false


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 15.0
	add_child(_http)
	_cleanup_old()


func _process(_delta: float) -> void:
	if _dl and _dl.get_body_size() > 0:
		download_ratio.emit(float(_dl.get_downloaded_bytes()) / float(_dl.get_body_size()))


## Release notes for the version we're running, shown once after an update.
func whats_new() -> String:
	var mine := Net.version()
	if str(GameState.settings.get("last_version", "")) == mine:
		return ""
	var first_run := str(GameState.settings.get("last_version", "")) == ""
	GameState.settings["last_version"] = mine
	GameState.save_game()
	if first_run:
		return ""
	return str(GameState.settings.get("pending_notes", ""))


func check_now() -> void:
	_checked = false
	check()


func check() -> void:
	var testing := GameState.shot_args.has("ota-test")
	if _checked or GameState.server_mode or (GameState.shot_mode and not testing) or (OS.has_feature("editor") and not testing):
		return
	_checked = true
	_http.request_completed.connect(_on_release, CONNECT_ONE_SHOT)
	_http.request(API, ["User-Agent: lowgear-updater", "Accept: application/vnd.github+json"])


func _on_release(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		checked.emit(false)
		return
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not data is Dictionary:
		return
	var tag := str((data as Dictionary).get("tag_name", "")).trim_prefix("v")
	var current := str(GameState.shot_args.get("fake-version", Net.version()))
	print("[ota] latest=%s current=%s" % [tag, current])
	if tag.is_empty() or not is_newer(tag, current):
		checked.emit(false)
		return
	for a in (data as Dictionary).get("assets", []):
		_assets[str(a["name"])] = str(a["browser_download_url"])
		if str(a["name"]) == _asset_name():
			size_bytes = int(a.get("size", 0))
			_digest = str(a.get("digest", "")) if a.get("digest") != null else ""
	if _asset_name().is_empty() or not _assets.has(_asset_name()):
		checked.emit(false)
		return
	notes = _clean_notes(str((data as Dictionary).get("body", "")))
	checked.emit(true)
	latest = tag
	update_available.emit(tag)
	if GameState.shot_args.has("ota-test"):
		install()


## Keeps the readable part of the release notes (drops links and "Full Changelog" lines).
static func _clean_notes(body: String) -> String:
	var out: Array = []
	for line in body.split("\n"):
		var l := line.strip_edges()
		if l.is_empty() or l.begins_with("**Full Changelog") or l.begins_with("<!--"):
			continue
		out.append(l.trim_prefix("## ").trim_prefix("### "))
	return "\n".join(out.slice(0, 12))


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
	GameState.settings["pending_notes"] = notes
	GameState.save_game()
	if OS.get_name() == "Android":
		# The browser downloads it and hands it to the system installer.
		OS.shell_open(url)
		return
	var exe := OS.get_executable_path()
	var tmp := exe + ".new"
	progress.emit("Downloading %s..." % latest)
	var dl := HTTPRequest.new()
	dl.download_file = tmp
	dl.timeout = 900.0
	add_child(dl)
	_dl = dl
	dl.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
		dl.queue_free()
		_dl = null
		print("[ota] download result=%d code=%d" % [result, code])
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			progress.emit("Download failed, try again later")
			DirAccess.remove_absolute(tmp)
			return
		var problem := _verify(tmp)
		if problem != "":
			progress.emit(problem)
			DirAccess.remove_absolute(tmp)
			return
		_swap_and_restart(exe, tmp))
	dl.request(url, ["User-Agent: lowgear-updater"])


## Checks the download against the size and SHA-256 that GitHub reports.
func _verify(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return "Could not read the download"
	var got := f.get_length()
	f.close()
	if size_bytes > 0 and got != size_bytes:
		return "The download was incomplete, try again"
	if _digest.begins_with("sha256:"):
		var sum := FileAccess.get_sha256(path)
		if sum != _digest.substr(7):
			print("[ota] checksum mismatch %s != %s" % [sum, _digest])
			return "The download was damaged, try again"
	print("[ota] verified %d bytes%s" % [got, ", sha256 ok" if _digest != "" else ""])
	return ""


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
	print("[ota] replaced %s" % exe)
	if GameState.shot_args.has("ota-test"):
		get_tree().quit()
		return
	GameState.save_game()
	OS.create_process(exe, [])
	get_tree().quit()


func _cleanup_old() -> void:
	var old := OS.get_executable_path() + ".old"
	if FileAccess.file_exists(old):
		DirAccess.remove_absolute(old)
