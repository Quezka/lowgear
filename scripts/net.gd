extends Node
## Autoload "Net": LAN / Tailscale multiplayer over ENet (up to 4 players).
## Everyone drives the same seeded island; each player simulates their own car and
## streams its state to the others, who show it as a RemoteCar.

signal roster_changed
signal status(text: String)
signal joined
signal car_state(id: int, data: Array)
signal announced(text: String)
signal time_synced(t: float)

const PORT := 24680
## Bump when the network messages change; players must match to play together.
const PROTOCOL := 1
const MAX_CLIENTS := 3
const COLORS := [Color("#ff8fab"), Color("#8ecae6"), Color("#f6bd60"), Color("#b8a1e3")]

var players: Dictionary = {}  ## peer id -> {name, car, slot}
var active := false
var dedicated := false  ## headless relay server with no car of its own
var _clock := 0.34
var _clock_send := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_gone)


func is_host() -> bool:
	return active and multiplayer.is_server()


func my_id() -> int:
	return multiplayer.get_unique_id() if active else 1


func my_slot() -> int:
	var me: Dictionary = players.get(my_id(), {})
	return int(me.get("slot", 0))


func player_color(id: int) -> Color:
	var p: Dictionary = players.get(id, {})
	return COLORS[int(p.get("slot", 0)) % COLORS.size()]


func host(as_dedicated := false) -> bool:
	leave()
	dedicated = as_dedicated
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(PORT, MAX_CLIENTS + (1 if dedicated else 0)) != OK:
		status.emit("Could not host: port %d is busy" % PORT)
		return false
	multiplayer.multiplayer_peer = peer
	active = true
	players = {} if dedicated else {1: _me(0)}
	roster_changed.emit()
	if dedicated:
		print("[server] Lowgear relay listening on UDP %d (%s)" % [PORT, ", ".join(local_ips())])
	return true


## The dedicated server keeps the shared time of day.
func _process(delta: float) -> void:
	if not dedicated or not active:
		return
	_clock = fposmod(_clock + delta / 480.0, 1.0)
	_clock_send += delta
	if _clock_send > 5.0:
		_clock_send = 0.0
		if not players.is_empty():
			_time.rpc(_clock)


func join(ip: String) -> void:
	leave()
	ip = ip.strip_edges()
	var peer := ENetMultiplayerPeer.new()
	if ip.is_empty() or peer.create_client(ip, PORT) != OK:
		status.emit("That address does not look right")
		return
	multiplayer.multiplayer_peer = peer
	active = true
	status.emit("Connecting to %s..." % ip)
	get_tree().create_timer(8.0).timeout.connect(func() -> void:
		if active and players.is_empty():
			status.emit("No answer from %s" % ip)
			leave())


func leave() -> void:
	if active and multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	active = false
	players.clear()
	roster_changed.emit()


## This machine's addresses friends can type in (LAN and Tailscale).
func local_ips() -> Array:
	var out: Array = []
	for a in IP.get_local_addresses():
		var s := str(a)
		if s.count(".") == 3 and not s.begins_with("127.") and not s.begins_with("172.17."):
			out.append(s)
	return out


func _me(slot: int) -> Dictionary:
	return {"name": str(GameState.settings["name"]), "car": GameState.car_id, "slot": slot}


func _free_slot() -> int:
	var used := {}
	for id in players:
		used[int(players[id]["slot"])] = true
	for s in 4:
		if not used.has(s):
			return s
	return 0


func _on_connected() -> void:
	_register.rpc_id(1, str(GameState.settings["name"]), GameState.car_id, PROTOCOL, version())


static func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0"))


@rpc("any_peer", "reliable")
func _register(player_name: String, car: String, protocol := 0, their_version := "?") -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if protocol != PROTOCOL:
		_rejected.rpc_id(id, "This game runs version %s, you have %s. Update and try again." % [version(), their_version])
		get_tree().create_timer(1.0).timeout.connect(func() -> void:
			if multiplayer.multiplayer_peer:
				multiplayer.multiplayer_peer.disconnect_peer(id))
		return
	player_name = player_name.strip_edges().substr(0, 16)
	if player_name.is_empty():
		player_name = "Driver"
	players[id] = {"name": player_name, "car": car, "slot": _free_slot()}
	if dedicated:
		print("[server] %s joined (%d players)" % [player_name, players.size()])
	_roster.rpc(players)
	roster_changed.emit()
	announce("%s joined" % player_name)


@rpc("authority", "reliable")
func _rejected(reason: String) -> void:
	status.emit(reason)
	leave()


@rpc("authority", "reliable")
func _roster(p: Dictionary) -> void:
	var first := players.is_empty()
	players = p
	roster_changed.emit()
	if first:
		joined.emit()


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server() or not players.has(id):
		return
	var n := str(players[id]["name"])
	players.erase(id)
	if dedicated:
		print("[server] %s left (%d players)" % [n, players.size()])
	_roster.rpc(players)
	roster_changed.emit()
	announce("%s left" % n)


func _on_failed() -> void:
	status.emit("Could not connect")
	leave()


func _on_server_gone() -> void:
	leave()
	status.emit("The host left the game")
	announced.emit("The host left the game, you are driving solo")


func send_state(data: Array) -> void:
	if active and not dedicated and players.size() > 1:
		_state.rpc(data)


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _state(data: Array) -> void:
	car_state.emit(multiplayer.get_remote_sender_id(), data)


## Shows a toast on everyone's screen (including ours).
func announce(text: String) -> void:
	if active:
		_announce.rpc(text)
	else:
		announced.emit(text)


@rpc("any_peer", "call_local", "reliable")
func _announce(text: String) -> void:
	announced.emit(text)


func send_time(t: float) -> void:
	if is_host() and not dedicated and players.size() > 1:
		_time.rpc(t)


@rpc("authority", "call_remote", "unreliable")
func _time(t: float) -> void:
	time_synced.emit(t)
