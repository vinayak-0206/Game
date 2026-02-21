extends Node

## Network manager — ENet multiplayer for 2-4 player co-op

const DEFAULT_PORT := 27015
const MAX_PLAYERS := 4

var peer: ENetMultiplayerPeer = null
var player_info: Dictionary = {}  # peer_id -> {name, color}
var is_host := false
var is_connected := false

signal player_connected(peer_id: int, info: Dictionary)
signal player_disconnected(peer_id: int)
signal server_started
signal connection_failed
signal all_players_ready


func create_server(port: int = DEFAULT_PORT) -> Error:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		return err

	multiplayer.multiplayer_peer = peer
	is_host = true
	is_connected = true

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	# Add self
	player_info[1] = {"name": "Host", "color": Color(0.2, 0.8, 1.0)}
	server_started.emit()
	return OK


func join_server(ip: String, port: int = DEFAULT_PORT) -> Error:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		return err

	multiplayer.multiplayer_peer = peer
	is_host = false

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

	return OK


func disconnect_from_server() -> void:
	if peer:
		peer.close()
	player_info.clear()
	is_host = false
	is_connected = false
	multiplayer.multiplayer_peer = null


func _on_peer_connected(id: int) -> void:
	# Send our info to the new peer
	_send_player_info.rpc_id(id, multiplayer.get_unique_id(), player_info.get(multiplayer.get_unique_id(), {"name": "Player", "color": Color.WHITE}))


func _on_peer_disconnected(id: int) -> void:
	player_info.erase(id)
	player_disconnected.emit(id)


func _on_connected_to_server() -> void:
	is_connected = true
	var my_id := multiplayer.get_unique_id()
	player_info[my_id] = {"name": "Player %d" % my_id, "color": Color(randf(), randf(), randf())}
	# Share our info with everyone
	_send_player_info.rpc(my_id, player_info[my_id])


func _on_connection_failed() -> void:
	connection_failed.emit()
	disconnect_from_server()


@rpc("any_peer", "reliable")
func _send_player_info(id: int, info: Dictionary) -> void:
	player_info[id] = info
	player_connected.emit(id, info)


func get_player_count() -> int:
	return player_info.size()


func is_server() -> bool:
	return is_host and is_connected
