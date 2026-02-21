extends CharacterBody3D

## AI Enemy - direct movement (no nav mesh needed)

@export_group("Stats")
@export var max_health := 80.0
@export var move_speed := 4.0
@export var chase_speed := 5.0
@export var damage := 8.0
@export var fire_rate := 1.2
@export var detection_range := 15.0
@export var attack_range := 12.0
@export var score_value := 100

@export_group("Visual")
@export var enemy_color := Color(1.0, 0.2, 0.1)
@export var enemy_scale := 1.0

var current_health: float
var is_dead := false
var target: CharacterBody3D = null
var fire_timer := 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var hit_flash_timer := 0.0

enum State { PATROL, CHASE, ATTACK, DEAD }
var current_state := State.PATROL

var patrol_target: Vector3
var home_position: Vector3
var body_mesh: MeshInstance3D
var eye_left: MeshInstance3D
var eye_right: MeshInstance3D
var base_mat: StandardMaterial3D
var glow_mat: StandardMaterial3D
var health_bar_mesh: MeshInstance3D
var health_bar_bg: MeshInstance3D

signal enemy_died(enemy: Node3D, killer: Node)


func _ready() -> void:
	current_health = max_health
	home_position = global_position
	add_to_group("enemies")
	scale = Vector3.ONE * enemy_scale

	_build_visual()
	_find_player()
	_pick_patrol_target()
	current_state = State.PATROL


func _build_visual() -> void:
	# Try loading Blender model based on enemy type
	var model_path := _get_model_path()
	var model_scene = load(model_path) as PackedScene if model_path != "" else null
	if model_scene:
		var model_instance := model_scene.instantiate()
		model_instance.name = "EnemyGLB"
		$EnemyModel.add_child(model_instance)
	else:
		# Fallback: primitive capsule
		body_mesh = MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.35
		capsule.height = 1.6
		body_mesh.mesh = capsule
		body_mesh.position = Vector3(0, 0.9, 0)
		$EnemyModel.add_child(body_mesh)

	# Setup materials for hit flash regardless of model type
	base_mat = StandardMaterial3D.new()
	base_mat.albedo_color = enemy_color
	base_mat.emission_enabled = true
	base_mat.emission = enemy_color * 0.5
	base_mat.emission_energy_multiplier = 1.5
	base_mat.metallic = 0.3
	base_mat.roughness = 0.5

	if body_mesh:
		body_mesh.material_override = base_mat

	glow_mat = StandardMaterial3D.new()
	glow_mat.albedo_color = Color(1, 1, 0.5)
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(1, 0.9, 0.3)
	glow_mat.emission_energy_multiplier = 5.0

	# Only add primitive eyes if no GLB model loaded
	if not model_scene:
		eye_left = MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.06
		eye_mesh.height = 0.12
		eye_left.mesh = eye_mesh
		eye_left.material_override = glow_mat
		eye_left.position = Vector3(-0.12, 1.45, -0.28)
		$EnemyModel.add_child(eye_left)

		eye_right = MeshInstance3D.new()
		eye_right.mesh = eye_mesh
		eye_right.material_override = glow_mat
		eye_right.position = Vector3(0.12, 1.45, -0.28)
		$EnemyModel.add_child(eye_right)

	# Health bar background
	health_bar_bg = MeshInstance3D.new()
	var bg_mesh := BoxMesh.new()
	bg_mesh.size = Vector3(0.8, 0.08, 0.02)
	health_bar_bg.mesh = bg_mesh
	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.2, 0.0, 0.0)
	health_bar_bg.material_override = bg_mat
	health_bar_bg.position = Vector3(0, 2.1, 0)
	add_child(health_bar_bg)

	# Health bar fill
	health_bar_mesh = MeshInstance3D.new()
	var hp_mesh := BoxMesh.new()
	hp_mesh.size = Vector3(0.78, 0.06, 0.03)
	health_bar_mesh.mesh = hp_mesh
	var hp_mat := StandardMaterial3D.new()
	hp_mat.albedo_color = Color(1, 0.1, 0.1)
	hp_mat.emission_enabled = true
	hp_mat.emission = Color(1, 0, 0)
	hp_mat.emission_energy_multiplier = 2.0
	health_bar_mesh.material_override = hp_mat
	health_bar_mesh.position = Vector3(0, 2.1, 0)
	add_child(health_bar_mesh)


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Hit flash
	if hit_flash_timer > 0:
		hit_flash_timer -= delta
		if hit_flash_timer <= 0:
			base_mat.emission_energy_multiplier = 1.5
			base_mat.emission = enemy_color * 0.5

	# Billboard health bar toward camera
	var cam := get_viewport().get_camera_3d()
	if cam and health_bar_bg:
		health_bar_bg.look_at(cam.global_position)
		health_bar_mesh.look_at(cam.global_position)

	# Try to find player if we don't have one
	if not is_instance_valid(target):
		_find_player()

	match current_state:
		State.PATROL:
			_do_patrol(delta)
		State.CHASE:
			_do_chase(delta)
		State.ATTACK:
			_do_attack(delta)

	move_and_slide()


func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target = players[0] as CharacterBody3D


func _do_patrol(delta: float) -> void:
	var dir := (patrol_target - global_position)
	dir.y = 0

	if dir.length() < 1.5:
		_pick_patrol_target()
		# Skip movement this frame to avoid jitter from stale direction
		velocity.x = 0
		velocity.z = 0
		return

	dir = dir.normalized()
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	_face_direction(dir, delta)

	# Check for player
	if _can_see_player():
		current_state = State.CHASE


func _do_chase(delta: float) -> void:
	if not is_instance_valid(target):
		current_state = State.PATROL
		return

	var dist := global_position.distance_to(target.global_position)

	if dist <= attack_range:
		current_state = State.ATTACK
		return

	if dist > detection_range * 2:
		current_state = State.PATROL
		_pick_patrol_target()
		return

	var dir := (target.global_position - global_position)
	dir.y = 0
	dir = dir.normalized()

	velocity.x = dir.x * chase_speed
	velocity.z = dir.z * chase_speed
	_face_direction(dir, delta)


func _do_attack(delta: float) -> void:
	if not is_instance_valid(target):
		current_state = State.PATROL
		return

	var dist := global_position.distance_to(target.global_position)

	if dist > attack_range * 1.3:
		current_state = State.CHASE
		return

	# Face target
	var dir := (target.global_position - global_position)
	dir.y = 0
	_face_direction(dir.normalized(), delta)

	# Strafe a bit
	var strafe := Vector3(-dir.normalized().z, 0, dir.normalized().x) * sin(Time.get_ticks_msec() * 0.002) * move_speed * 0.5
	velocity.x = strafe.x
	velocity.z = strafe.z

	# Fire
	fire_timer -= delta
	if fire_timer <= 0:
		_shoot()
		fire_timer = fire_rate


func _shoot() -> void:
	if not is_instance_valid(target):
		return

	var from := global_position + Vector3(0, 1.5, 0)
	var to := target.global_position + Vector3(0, 1.0, 0)

	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]

	var result := space_state.intersect_ray(query)
	if result and result.collider == target:
		if target.has_method("take_damage"):
			target.take_damage(damage, self)

		# Tracer effect
		_spawn_tracer(from, to)


func _spawn_tracer(from_pos: Vector3, to_pos: Vector3) -> void:
	var tracer := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.01
	cyl.bottom_radius = 0.01
	var dist := from_pos.distance_to(to_pos)
	cyl.height = dist
	tracer.mesh = cyl

	var tracer_mat := StandardMaterial3D.new()
	tracer_mat.albedo_color = enemy_color
	tracer_mat.emission_enabled = true
	tracer_mat.emission = enemy_color
	tracer_mat.emission_energy_multiplier = 8.0
	tracer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tracer_mat.albedo_color.a = 0.8
	tracer.material_override = tracer_mat

	get_tree().root.add_child(tracer)
	var mid := (from_pos + to_pos) / 2.0
	tracer.global_position = mid
	tracer.look_at(to_pos)
	tracer.rotate_object_local(Vector3(1, 0, 0), deg_to_rad(90))

	# Fade out
	var tween := tracer.create_tween()
	tween.tween_property(tracer_mat, "albedo_color:a", 0.0, 0.15)
	tween.tween_callback(tracer.queue_free)


func take_damage(amount: float, from_who: Node = null) -> void:
	if is_dead:
		return

	current_health -= amount
	_update_health_bar()
	_flash_hit()
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_hit"):
		am.play_hit()

	if from_who and from_who is CharacterBody3D:
		target = from_who
		current_state = State.CHASE

	if current_health <= 0:
		_die(from_who)


func _flash_hit() -> void:
	hit_flash_timer = 0.12
	base_mat.emission = Color(1, 1, 1)
	base_mat.emission_energy_multiplier = 8.0


func _die(killer: Node = null) -> void:
	is_dead = true
	current_state = State.DEAD
	velocity = Vector3.ZERO

	enemy_died.emit(self, killer)

	var game_mgr = get_tree().get_first_node_in_group("game_manager")
	if game_mgr and game_mgr.has_method("on_enemy_killed"):
		game_mgr.on_enemy_killed(self, killer)

	# Death explosion particles
	EffectSpawner.spawn_death_explosion(get_tree(), global_position + Vector3(0, 1, 0), enemy_color)
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_death"):
		am.play_death()

	# Death animation - scale down + flash
	base_mat.emission = Color(1, 1, 1)
	base_mat.emission_energy_multiplier = 10.0

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3(0.01, 2.5, 0.01), 0.3).set_ease(Tween.EASE_IN)
	tween.tween_property(base_mat, "emission_energy_multiplier", 0.0, 0.3)
	tween.chain().tween_callback(queue_free)


func _can_see_player() -> bool:
	if not is_instance_valid(target):
		return false
	return global_position.distance_to(target.global_position) < detection_range


func _pick_patrol_target() -> void:
	var angle := randf() * TAU
	var dist := randf_range(3.0, 10.0)
	patrol_target = home_position + Vector3(cos(angle) * dist, 0, sin(angle) * dist)
	# Clamp inside arena
	patrol_target.x = clampf(patrol_target.x, -19, 19)
	patrol_target.z = clampf(patrol_target.z, -19, 19)


func _face_direction(direction: Vector3, delta: float) -> void:
	if direction.length_squared() > 0.001:
		var target_rot := atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rot, 10.0 * delta)


func _get_model_path() -> String:
	# Map enemy color/scale to Blender model
	if enemy_scale >= 1.25:
		return "res://models/SM_Enemy_Boss.glb"
	elif enemy_scale <= 0.9:
		return "res://models/SM_Enemy_Fast.glb"
	elif enemy_color.r > 0.85 and enemy_color.g > 0.4:
		return "res://models/SM_Enemy_Tank.glb"
	else:
		return "res://models/SM_Enemy_Basic.glb"


func _update_health_bar() -> void:
	if health_bar_mesh:
		var pct := clampf(current_health / max_health, 0, 1)
		health_bar_mesh.scale.x = pct
