extends Control

## Radar-style minimap — draws player, enemies, pickups, and arena outline

var map_range := 30.0  # World units visible on minimap
var map_size := 180.0  # Pixel size of minimap
var player: CharacterBody3D


func _ready() -> void:
	custom_minimum_size = Vector2(map_size, map_size)
	size = Vector2(map_size, map_size)
	# Position below health bar area
	position = Vector2(20, 130)
	z_index = 10


func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	queue_redraw()


func _draw() -> void:
	var center := Vector2(map_size / 2.0, map_size / 2.0)
	var radius := map_size / 2.0 - 5.0

	# Background circle
	draw_circle(center, radius + 2, Color(0.1, 0.1, 0.15, 0.85))
	draw_arc(center, radius + 2, 0, TAU, 64, Color(0.0, 0.6, 1.0, 0.5), 1.5)

	if not is_instance_valid(player):
		return

	var player_pos := Vector2(player.global_position.x, player.global_position.z)
	var player_yaw: float = player.current_yaw if "current_yaw" in player else 0.0

	# Arena walls outline (44x44 arena centered at 0,0 with walls at +/-22)
	_draw_arena_outline(center, player_pos, player_yaw, radius)

	# Pickups
	for pickup in get_tree().get_nodes_in_group("pickups"):
		if not is_instance_valid(pickup) or not pickup.visible:
			continue
		var ppos := Vector2(pickup.global_position.x, pickup.global_position.z)
		var map_pos := _world_to_minimap(ppos, player_pos, player_yaw, center, radius)
		if map_pos.distance_to(center) < radius:
			# Green for health, yellow for ammo
			var col := Color(0.0, 1.0, 0.4) if pickup is PickupBase and "heal_amount" in pickup else Color(1.0, 0.8, 0.0)
			draw_rect(Rect2(map_pos - Vector2(2.5, 2.5), Vector2(5, 5)), col)

	# Enemies
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var epos := Vector2(enemy.global_position.x, enemy.global_position.z)
		var map_pos := _world_to_minimap(epos, player_pos, player_yaw, center, radius)
		if map_pos.distance_to(center) < radius:
			var dot_size := 3.5
			if "enemy_scale" in enemy:
				dot_size = 3.0 + enemy.enemy_scale * 1.5
			draw_circle(map_pos, dot_size, Color(1.0, 0.2, 0.1, 0.9))

	# Player triangle (always at center, rotated)
	var tri_size := 6.0
	var points := PackedVector2Array()
	points.append(center + Vector2(0, -tri_size))  # Forward (up)
	points.append(center + Vector2(-tri_size * 0.6, tri_size * 0.5))
	points.append(center + Vector2(tri_size * 0.6, tri_size * 0.5))
	draw_polygon(points, PackedColorArray([Color(0.0, 1.0, 0.5, 1.0), Color(0.0, 1.0, 0.5, 1.0), Color(0.0, 1.0, 0.5, 1.0)]))

	# FOV cone indicator
	var cone_length := radius * 0.35
	var cone_half_angle := deg_to_rad(30)
	var left_dir := Vector2(sin(-cone_half_angle), -cos(-cone_half_angle)) * cone_length
	var right_dir := Vector2(sin(cone_half_angle), -cos(cone_half_angle)) * cone_length
	draw_line(center, center + left_dir, Color(0.0, 1.0, 0.5, 0.3), 1.0)
	draw_line(center, center + right_dir, Color(0.0, 1.0, 0.5, 0.3), 1.0)


func _draw_arena_outline(center: Vector2, player_pos: Vector2, player_yaw: float, radius: float) -> void:
	# Arena corners in world space
	var corners := [
		Vector2(-22, -22), Vector2(22, -22),
		Vector2(22, 22), Vector2(-22, 22),
	]
	var mapped_corners: Array[Vector2] = []
	for c in corners:
		mapped_corners.append(_world_to_minimap(c, player_pos, player_yaw, center, radius))

	# Draw wall lines
	for i in range(4):
		var a: Vector2 = mapped_corners[i]
		var b: Vector2 = mapped_corners[(i + 1) % 4]
		draw_line(a, b, Color(0.4, 0.4, 0.5, 0.5), 1.0)


func _world_to_minimap(world_pos: Vector2, player_pos: Vector2, player_yaw: float, center: Vector2, radius: float) -> Vector2:
	var rel := world_pos - player_pos
	# Rotate so player forward = up on minimap
	var rotated := Vector2(
		rel.x * cos(-player_yaw) - rel.y * sin(-player_yaw),
		rel.x * sin(-player_yaw) + rel.y * cos(-player_yaw)
	)
	# Scale to minimap
	var scale_factor := radius / map_range
	return center + rotated * scale_factor
