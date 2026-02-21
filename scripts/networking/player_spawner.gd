extends Node

## Spawns and manages networked player instances

var player_scene: PackedScene
var spawned_players: Dictionary = {}  # peer_id -> player_node


func _ready() -> void:
	player_scene = load("res://scenes/characters/player.tscn") as PackedScene

	if not multiplayer.is_server():
		return

	# Server spawns players for all connected peers
	for peer_id in NetworkManager.player_info:
		_spawn_player(peer_id)

	NetworkManager.player_connected.connect(_on_player_joined)
	NetworkManager.player_disconnected.connect(_on_player_left)


func _spawn_player(peer_id: int) -> void:
	if not player_scene:
		return

	var player = player_scene.instantiate()
	player.name = "Player_%d" % peer_id
	player.set_multiplayer_authority(peer_id)

	# Set spawn position
	var spawns := get_tree().get_nodes_in_group("spawn_points")
	if spawns.size() > 0:
		var idx := spawned_players.size() % spawns.size()
		player.global_position = spawns[idx].global_position + Vector3(0, 1, 0)

	get_parent().add_child(player)
	spawned_players[peer_id] = player


func _on_player_joined(peer_id: int, _info: Dictionary) -> void:
	if multiplayer.is_server():
		_spawn_player(peer_id)


func _on_player_left(peer_id: int) -> void:
	if peer_id in spawned_players:
		spawned_players[peer_id].queue_free()
		spawned_players.erase(peer_id)
