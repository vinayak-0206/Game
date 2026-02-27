extends Node3D

## Wave-based survival game manager with combo system, game over, high scores

@export_group("Waves")
@export var starting_enemies := 3
@export var enemies_per_wave := 2
@export var max_enemies_alive := 12
@export var wave_break_time := 5.0

@export_group("Scenes")
@export var enemy_scene: PackedScene

var wave := 0
var score := 0
var kills := 0
var combo := 0
var combo_multiplier := 1.0
var combo_timer := 0.0
var combo_timeout := 4.0
var best_combo := 0
var enemies_alive := 0
var enemies_to_spawn := 0
var spawn_timer := 0.0
var match_time := 0.0
var is_wave_active := false
var is_game_over := false
var enemy_spawn_points: Array = []

# Enemy variety per wave
var enemy_configs := [
	{"color": Color(1.0, 0.2, 0.1), "health": 60, "speed": 4.0, "damage": 8, "score": 100, "scale": 1.0, "type": "basic"},
	{"color": Color(1.0, 0.6, 0.0), "health": 100, "speed": 3.5, "damage": 12, "score": 150, "scale": 1.15, "type": "tank"},
	{"color": Color(0.8, 0.0, 1.0), "health": 40, "speed": 7.0, "damage": 15, "score": 200, "scale": 0.85, "type": "fast"},
	{"color": Color(0.0, 1.0, 0.2), "health": 150, "speed": 3.0, "damage": 20, "score": 300, "scale": 1.3, "type": "boss_mini"},
	{"color": Color(0.2, 0.5, 1.0), "health": 120, "speed": 3.0, "damage": 10, "score": 250, "scale": 1.1, "type": "shield"},
	{"color": Color(0.6, 0.9, 1.0), "health": 50, "speed": 6.0, "damage": 12, "score": 200, "scale": 0.7, "type": "drone"},
	{"color": Color(1.0, 0.1, 0.3), "health": 80, "speed": 8.0, "damage": 0, "score": 180, "scale": 1.0, "type": "rusher"},
]

var is_boss_wave := false
var boss_enemy: Node = null

signal score_updated(new_score: int)
signal kill_registered(total_kills: int)
signal match_timer_updated(time: float)
signal wave_started(wave_num: int)
signal wave_cleared(wave_num: int)
signal combo_updated(combo_count: int, multiplier: float)
signal match_ended(final_score: int)


func _ready() -> void:
	add_to_group("game_manager")

	for node in get_tree().get_nodes_in_group("enemy_spawns"):
		enemy_spawn_points.append(node)

	# Connect to player death on next frame (player is ready by then)
	call_deferred("_connect_player_signals")

	await get_tree().create_timer(2.0).timeout
	_start_next_wave()


func _connect_player_signals() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_signal("player_died"):
		player.player_died.connect(_on_player_died)


func _process(delta: float) -> void:
	if is_game_over:
		return

	match_time += delta
	match_timer_updated.emit(match_time)

	# Combo decay
	if combo > 0:
		combo_timer -= delta
		if combo_timer <= 0:
			combo = 0
			combo_multiplier = 1.0
			combo_updated.emit(combo, combo_multiplier)

	# Spawn enemies during active wave
	if is_wave_active and enemies_to_spawn > 0:
		spawn_timer -= delta
		if spawn_timer <= 0:
			_spawn_enemy()
			spawn_timer = 1.5


func on_enemy_killed(enemy: Node3D, killer: Node) -> void:
	enemies_alive -= 1
	kills += 1

	# Combo system — timeout scales with wave for fairness
	combo += 1
	combo_timer = combo_timeout + wave * 0.3
	combo_multiplier = 1.0 + (combo - 1) * 0.25
	combo_multiplier = minf(combo_multiplier, 5.0)
	best_combo = maxi(best_combo, combo)

	var base_score: int = enemy.score_value if "score_value" in enemy else 100
	var earned := int(base_score * combo_multiplier)
	score += earned

	score_updated.emit(score)
	kill_registered.emit(kills)
	combo_updated.emit(combo, combo_multiplier)

	# Notify player for hit marker + lifesteal
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var p = players[0]
		if p.has_method("_show_kill_marker"):
			p._show_kill_marker(earned, combo)
		# Lifesteal perk
		var ls: float = p.get_meta("lifesteal", 0.0)
		if ls > 0 and p.has_method("heal"):
			var base_score_val: int = enemy.score_value if "score_value" in enemy else 100
			p.heal(base_score_val * ls)

	# Check if wave is cleared
	if is_wave_active and enemies_alive <= 0 and enemies_to_spawn <= 0:
		is_wave_active = false
		wave_cleared.emit(wave)

		# Show upgrade shop between waves
		await get_tree().create_timer(1.5).timeout
		if not is_game_over:
			_show_upgrade_shop()


func _on_player_died() -> void:
	is_game_over = true
	is_wave_active = false
	match_ended.emit(score)

	# Show game over via HUD
	await get_tree().create_timer(1.0).timeout
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var hud_node = player.get_node_or_null("HUD")
		if hud_node and hud_node.has_method("show_game_over"):
			hud_node.show_game_over(score, wave, kills, best_combo)

	_save_high_score()


func _save_high_score() -> void:
	var path := "user://highscores.json"
	var scores: Array = []

	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		var json := JSON.new()
		if json.parse(file.get_as_text()) == OK and json.data is Array:
			scores = json.data
		file.close()

	scores.append({"score": score, "wave": wave, "kills": kills, "combo": best_combo})
	scores.sort_custom(func(a, b): return a.score > b.score)
	if scores.size() > 10:
		scores.resize(10)

	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(scores))
	file.close()


func _show_upgrade_shop() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var hud_node = player.get_node_or_null("HUD")
		if hud_node and hud_node.has_method("show_upgrade_shop"):
			hud_node.show_upgrade_shop(score, wave)
			# Wait for shop to close
			var shop = hud_node.get_node_or_null("UpgradeShop")
			if shop and shop.has_signal("shop_closed"):
				await shop.shop_closed
			else:
				await get_tree().create_timer(wave_break_time).timeout
		else:
			await get_tree().create_timer(wave_break_time).timeout
	else:
		await get_tree().create_timer(wave_break_time).timeout

	if not is_game_over:
		_start_next_wave()


func _start_next_wave() -> void:
	wave += 1
	is_boss_wave = (wave % 5 == 0)

	if is_boss_wave:
		# Boss wave: single powerful enemy
		enemies_to_spawn = 1
	else:
		var enemy_count := starting_enemies + (wave - 1) * enemies_per_wave
		enemy_count = mini(enemy_count, max_enemies_alive)
		enemies_to_spawn = enemy_count

	is_wave_active = true
	spawn_timer = 0.5

	wave_started.emit(wave)


func _spawn_enemy() -> void:
	if not enemy_scene or enemies_alive >= max_enemies_alive:
		return

	enemies_to_spawn -= 1
	enemies_alive += 1

	var spawn_pos := Vector3(randf_range(-18, 18), 1, randf_range(-18, 18))
	if enemy_spawn_points.size() > 0:
		spawn_pos = enemy_spawn_points[randi() % enemy_spawn_points.size()].global_position

	var enemy = enemy_scene.instantiate()
	add_child(enemy)
	enemy.global_position = spawn_pos

	# Scale difficulty with waves + difficulty setting
	var wave_mult := 1.0 + (wave - 1) * 0.1
	var diff_mult := 1.0
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("get_difficulty_multiplier"):
		diff_mult = gs.get_difficulty_multiplier()

	# Boss wave: spawn a single powerful boss
	if is_boss_wave:
		var boss_hp := 500.0 + wave * 50.0
		enemy.max_health = boss_hp * diff_mult
		enemy.current_health = enemy.max_health
		enemy.move_speed = 3.5
		enemy.chase_speed = 5.0
		enemy.damage = 25.0 * wave_mult * diff_mult
		enemy.score_value = 1000
		enemy.enemy_color = Color(1.0, 0.0, 0.2)
		enemy.enemy_scale = 1.8
		enemy.is_boss = true
		boss_enemy = enemy

		# Show boss health bar on HUD
		var player = get_tree().get_first_node_in_group("player")
		if player:
			var hud_node = player.get_node_or_null("HUD")
			if hud_node and hud_node.has_method("show_boss_health"):
				hud_node.show_boss_health("WAVE %d BOSS" % wave, enemy.current_health, enemy.max_health)
		return

	# Apply enemy variety based on wave — gradual introduction
	var config: Dictionary
	if wave <= 2:
		config = enemy_configs[0]
	elif wave <= 4:
		config = enemy_configs[randi() % 2]
	elif wave <= 6:
		config = enemy_configs[randi() % 3]
	elif wave <= 8:
		# Introduce shield enemies (wave 7+)
		var roll := randi() % 10
		if roll < 3:
			config = enemy_configs[0]
		elif roll < 5:
			config = enemy_configs[1]
		elif roll < 7:
			config = enemy_configs[2]
		elif roll < 9:
			config = enemy_configs[4]  # Shield
		else:
			config = enemy_configs[3]
	elif wave <= 10:
		# Introduce drones (wave 9+)
		var roll := randi() % 12
		if roll < 3:
			config = enemy_configs[0]
		elif roll < 5:
			config = enemy_configs[1]
		elif roll < 7:
			config = enemy_configs[2]
		elif roll < 9:
			config = enemy_configs[4]  # Shield
		elif roll < 11:
			config = enemy_configs[5]  # Drone
		else:
			config = enemy_configs[3]
	else:
		# Wave 11+: all types including rushers
		var roll := randi() % 14
		if roll < 3:
			config = enemy_configs[0]
		elif roll < 5:
			config = enemy_configs[1]
		elif roll < 7:
			config = enemy_configs[2]
		elif roll < 9:
			config = enemy_configs[4]  # Shield
		elif roll < 11:
			config = enemy_configs[5]  # Drone
		elif roll < 13:
			config = enemy_configs[6]  # Rusher
		else:
			config = enemy_configs[3]

	enemy.max_health = config.health * wave_mult * diff_mult
	enemy.current_health = enemy.max_health
	enemy.move_speed = config.speed
	enemy.chase_speed = config.speed * 1.5
	enemy.damage = config.damage * wave_mult * diff_mult
	enemy.score_value = config.score
	enemy.enemy_color = config.color
	enemy.enemy_scale = config.scale

	# Set type flags after spawn
	var enemy_type: String = config.get("type", "basic")
	match enemy_type:
		"shield":
			enemy.has_shield = true
			enemy.shield_hp = 60.0 * wave_mult * diff_mult
		"drone":
			enemy.is_flying = true
		"rusher":
			enemy.is_rusher = true
			enemy.contact_damage = 30.0 * wave_mult * diff_mult
