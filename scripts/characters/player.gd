extends CharacterBody3D

## Third-person shooter player - smooth camera, sprint, dash, grenades

@export_group("Movement")
@export var move_speed := 6.5
@export var sprint_speed := 10.0
@export var jump_velocity := 6.0
@export var dash_speed := 25.0
@export var dash_duration := 0.25
@export var dash_cooldown := 2.0

@export_group("Camera")
@export var mouse_sensitivity := 0.0015
@export var camera_smoothing := 18.0
@export var camera_distance_normal := 3.5
@export var camera_distance_aim := 2.0
@export var camera_min_pitch := -50.0
@export var camera_max_pitch := 70.0

@export_group("Combat")
@export var max_health := 100.0
@export var max_grenades := 3

@export_group("Stamina")
@export var max_stamina := 100.0
@export var sprint_drain := 25.0
@export var stamina_regen := 20.0
@export var stamina_regen_delay := 1.0

var current_health: float
var is_dead := false
var is_aiming := false
var is_sprinting := false
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Camera smoothing
var target_yaw := 0.0
var target_pitch := 0.0
var current_yaw := 0.0
var current_pitch := 0.0

# Screen shake
var shake_intensity := 0.0
var shake_decay := 8.0

# Damage vignette
var damage_flash := 0.0

# Hit freeze juice
var hit_freeze_timer := 0.0

# Stamina
var current_stamina: float
var stamina_regen_timer := 0.0

# Dash
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var dash_direction := Vector3.ZERO
var is_dashing := false
var dash_requested := false

# Grenades
var grenades := 3

# Kill streak
var recent_kills := 0
var kill_streak_timer := 0.0

# Node references
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var mesh: Node3D = $PlayerModel
@onready var weapon_mount: Marker3D = $PlayerModel/WeaponMount
@onready var hud: Control = $HUD

# Weapon system
var weapons: Array = []
var current_weapon_index := 0
var current_weapon: Node3D = null

signal health_changed(new_health: float, max_hp: float)
signal ammo_changed(current_ammo: int, reserve: int)
signal weapon_switched(wep_name: String)
signal player_died
signal stamina_changed(current: float, max_val: float)
signal grenade_count_changed(count: int)


func _ready() -> void:
	current_health = max_health
	current_stamina = max_stamina
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera_arm.spring_length = camera_distance_normal

	camera_arm.collision_mask = 1
	camera.h_offset = 0.0
	camera.v_offset = 0.0

	target_pitch = deg_to_rad(-15.0)
	current_pitch = target_pitch

	add_to_group("player")
	health_changed.emit(current_health, max_health)
	stamina_changed.emit(current_stamina, max_stamina)
	grenade_count_changed.emit(grenades)

	_build_player_visual()
	_apply_saved_settings()
	_add_weapon("res://scenes/weapons/rifle.tscn")
	_add_weapon("res://scenes/weapons/pistol.tscn")
	if weapons.size() > 0:
		_equip_weapon(0)


func _build_player_visual() -> void:
	for child in $PlayerModel.get_children():
		if child is MeshInstance3D or child.name == "PlayerGLB":
			child.queue_free()

	# Try loading Blender model first, fallback to primitives
	var model_scene = load("res://models/SM_Player.glb") as PackedScene
	if model_scene:
		var model_instance := model_scene.instantiate()
		model_instance.name = "PlayerGLB"
		$PlayerModel.add_child(model_instance)
		return

	# Fallback: primitive visuals
	var body_mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 1.4
	body_mesh.mesh = capsule
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.15, 0.2, 0.35)
	body_mat.metallic = 0.3
	body_mat.roughness = 0.5
	body_mesh.material_override = body_mat
	body_mesh.position = Vector3(0, 0.9, 0)
	$PlayerModel.add_child(body_mesh)

	var head_mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.4
	head_mesh.mesh = sphere
	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.2, 0.25, 0.4)
	head_mat.metallic = 0.4
	head_mat.roughness = 0.4
	head_mesh.material_override = head_mat
	head_mesh.position = Vector3(0, 1.75, 0)
	$PlayerModel.add_child(head_mesh)

	var visor := MeshInstance3D.new()
	var visor_mesh := BoxMesh.new()
	visor_mesh.size = Vector3(0.3, 0.08, 0.05)
	visor.mesh = visor_mesh
	var visor_mat := StandardMaterial3D.new()
	visor_mat.albedo_color = Color(0.0, 0.8, 1.0)
	visor_mat.emission_enabled = true
	visor_mat.emission = Color(0.0, 0.7, 1.0)
	visor_mat.emission_energy_multiplier = 4.0
	visor.material_override = visor_mat
	visor.position = Vector3(0, 1.78, -0.18)
	$PlayerModel.add_child(visor)


func _input(event: InputEvent) -> void:
	if is_dead:
		return

	# Mouse look
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		target_yaw -= event.relative.x * mouse_sensitivity
		target_pitch -= event.relative.y * mouse_sensitivity
		target_pitch = clampf(target_pitch, deg_to_rad(camera_min_pitch), deg_to_rad(camera_max_pitch))

	# Mouse buttons
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_fire()
			else:
				_stop_fire()
		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_aiming = event.pressed

	# Keyboard
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				_reload()
			KEY_Q:
				_switch_weapon()
			KEY_G:
				_throw_grenade()
			KEY_CTRL:
				dash_requested = true
			KEY_ESCAPE:
				_toggle_pause()


func _toggle_pause() -> void:
	# Let pause menu handle it if it exists
	var pause = get_node_or_null("HUD/PauseMenu")
	if pause and pause.has_method("toggle"):
		pause.toggle()
	else:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# --- Smooth camera ---
	current_yaw = lerp_angle(current_yaw, target_yaw, camera_smoothing * delta)
	current_pitch = lerpf(current_pitch, target_pitch, camera_smoothing * delta)

	camera_pivot.rotation.y = current_yaw
	camera_arm.rotation.x = current_pitch

	# Camera zoom
	var target_dist := camera_distance_aim if is_aiming else camera_distance_normal
	camera_arm.spring_length = lerpf(camera_arm.spring_length, target_dist, 10.0 * delta)

	# --- Gravity ---
	if not is_on_floor():
		velocity.y -= gravity * delta

	# --- Jump ---
	if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = jump_velocity

	# --- Sprint ---
	is_sprinting = Input.is_key_pressed(KEY_SHIFT) and current_stamina > 0

	# --- Dash ---
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false
		else:
			velocity.x = dash_direction.x * dash_speed
			velocity.z = dash_direction.z * dash_speed
			move_and_slide()
			_update_effects(delta)
			return

	dash_cooldown_timer = maxf(dash_cooldown_timer - delta, 0)

	# --- Movement ---
	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1
	if Input.is_key_pressed(KEY_W):
		input_dir.y -= 1
	if Input.is_key_pressed(KEY_S):
		input_dir.y += 1
	input_dir = input_dir.normalized()

	var cam_basis := camera_pivot.global_transform.basis
	var direction := (cam_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	direction.y = 0

	# Dash on single Ctrl press
	if dash_requested:
		dash_requested = false
		if input_dir.length() > 0 and dash_cooldown_timer <= 0 and current_stamina >= 20:
			is_dashing = true
			dash_timer = dash_duration
			dash_cooldown_timer = dash_cooldown
			dash_direction = direction.normalized()
			current_stamina = maxf(current_stamina - 20, 0)
			stamina_regen_timer = stamina_regen_delay
			stamina_changed.emit(current_stamina, max_stamina)
			_add_screen_shake(0.15)
			var am = get_node_or_null("/root/AudioManager")
			if am and am.has_method("play_dash"):
				am.play_dash()

	var speed := sprint_speed if is_sprinting else move_speed

	if direction.length() > 0:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed * 3 * delta)
		velocity.z = move_toward(velocity.z, 0, move_speed * 3 * delta)

	# --- Stamina ---
	if is_sprinting and direction.length() > 0:
		current_stamina = maxf(current_stamina - sprint_drain * delta, 0)
		stamina_regen_timer = stamina_regen_delay
		stamina_changed.emit(current_stamina, max_stamina)
	else:
		stamina_regen_timer = maxf(stamina_regen_timer - delta, 0)
		if stamina_regen_timer <= 0 and current_stamina < max_stamina:
			current_stamina = minf(current_stamina + stamina_regen * delta, max_stamina)
			stamina_changed.emit(current_stamina, max_stamina)

	# --- Character faces away from camera ---
	var cam_forward := -cam_basis.z
	cam_forward.y = 0
	cam_forward = cam_forward.normalized()
	if cam_forward.length_squared() > 0.001:
		var target_rot := atan2(-cam_forward.x, -cam_forward.z)
		mesh.rotation.y = lerp_angle(mesh.rotation.y, target_rot, 20.0 * delta)

	_update_effects(delta)
	move_and_slide()


func _update_effects(delta: float) -> void:
	# Hit freeze recovery (use unscaled delta)
	if hit_freeze_timer > 0:
		hit_freeze_timer -= delta / maxf(Engine.time_scale, 0.01)
		if hit_freeze_timer <= 0:
			Engine.time_scale = 1.0

	# Screen shake
	if shake_intensity > 0:
		shake_intensity = lerpf(shake_intensity, 0, shake_decay * delta)
		var shake_offset := shake_intensity * 0.08
		camera.h_offset += randf_range(-shake_offset, shake_offset)
		camera.v_offset = randf_range(-shake_offset, shake_offset)
	else:
		camera.v_offset = lerpf(camera.v_offset, 0.0, 10.0 * delta)

	# Damage flash
	if damage_flash > 0:
		damage_flash = maxf(damage_flash - delta * 2, 0)

	# Kill streak decay
	if kill_streak_timer > 0:
		kill_streak_timer -= delta
		if kill_streak_timer <= 0:
			recent_kills = 0


# --- Combat ---

func take_damage(amount: float, from_who: Node = null) -> void:
	if is_dead:
		return
	# Apply damage reduction from armor upgrade
	var dr: float = get_meta("damage_reduction", 0.0)
	var final_amount := amount * (1.0 - dr)
	current_health = clampf(current_health - final_amount, 0, max_health)
	health_changed.emit(current_health, max_health)
	_add_screen_shake(0.3)
	damage_flash = 1.0
	if current_health <= 0:
		_die()


func heal(amount: float) -> void:
	if is_dead:
		return
	current_health = clampf(current_health + amount, 0, max_health)
	health_changed.emit(current_health, max_health)


func _die() -> void:
	is_dead = true
	player_died.emit()
	# Game over screen handles the rest via game_manager


func _respawn() -> void:
	current_health = max_health
	current_stamina = max_stamina
	grenades = max_grenades
	is_dead = false
	health_changed.emit(current_health, max_health)
	stamina_changed.emit(current_stamina, max_stamina)
	grenade_count_changed.emit(grenades)
	var spawns := get_tree().get_nodes_in_group("spawn_points")
	if spawns.size() > 0:
		var spawn = spawns[randi() % spawns.size()]
		global_position = spawn.global_position + Vector3(0, 1, 0)
	else:
		global_position = Vector3(0, 2, 0)


func _add_screen_shake(intensity: float) -> void:
	shake_intensity = maxf(shake_intensity, intensity)


func _show_kill_marker(points: int, combo_count: int) -> void:
	_add_screen_shake(0.2)
	recent_kills += 1
	kill_streak_timer = 4.0
	# Hit freeze — brief time slowdown on kill for impact feel
	Engine.time_scale = 0.15
	hit_freeze_timer = 0.06  # Real-time duration (not affected by time_scale)
	if hud and hud.has_method("show_kill_popup"):
		hud.show_kill_popup(points, combo_count)
	# Kill streak announcements
	if recent_kills >= 2 and hud and hud.has_method("show_streak"):
		var streak_text := ""
		match recent_kills:
			2: streak_text = "DOUBLE KILL!"
			3: streak_text = "TRIPLE KILL!"
			4: streak_text = "QUAD KILL!"
			5: streak_text = "RAMPAGE!"
			_:
				if recent_kills > 5:
					streak_text = "UNSTOPPABLE!"
		if streak_text != "":
			hud.show_streak(streak_text)


# --- Grenades ---

func _throw_grenade() -> void:
	if grenades <= 0 or is_dead:
		return

	grenades -= 1
	grenade_count_changed.emit(grenades)

	var grenade_scene := load("res://scripts/weapons/grenade.gd")
	var grenade := Area3D.new()
	grenade.set_script(grenade_scene)

	get_tree().root.add_child(grenade)
	var cam_forward := -camera.global_transform.basis.z
	var throw_pos := global_position + Vector3(0, 1.5, 0) + cam_forward * 0.5
	grenade.global_position = throw_pos
	grenade.throw_direction = cam_forward + Vector3(0, 0.4, 0)
	grenade.thrower = self

	_add_screen_shake(0.1)


func add_grenades(amount: int) -> void:
	grenades = mini(grenades + amount, max_grenades)
	grenade_count_changed.emit(grenades)


# --- Weapons ---

func _add_weapon(scene_path: String) -> void:
	var scene = load(scene_path) as PackedScene
	if scene:
		var weapon_instance: Node3D = scene.instantiate()
		weapon_mount.add_child(weapon_instance)
		weapon_instance.visible = false
		weapon_instance.set_process(false)
		weapons.append(weapon_instance)


func _equip_weapon(index: int) -> void:
	if current_weapon:
		current_weapon.visible = false
		current_weapon.set_process(false)
		if current_weapon.has_method("unequip"):
			current_weapon.unequip()

	current_weapon_index = index
	current_weapon = weapons[index]
	current_weapon.visible = true
	current_weapon.set_process(true)
	if current_weapon.has_method("equip"):
		current_weapon.equip()

	var wname: String = current_weapon.weapon_name if "weapon_name" in current_weapon else "Weapon"
	weapon_switched.emit(wname)
	if current_weapon.has_method("get_ammo_info"):
		var info = current_weapon.get_ammo_info()
		ammo_changed.emit(info.current, info.reserve)


func _switch_weapon() -> void:
	if weapons.size() <= 1:
		return
	var next := (current_weapon_index + 1) % weapons.size()
	_equip_weapon(next)
	_add_screen_shake(0.05)


func _fire() -> void:
	if current_weapon and current_weapon.has_method("start_fire"):
		current_weapon.start_fire(camera)
		_add_screen_shake(0.08)


func _stop_fire() -> void:
	if current_weapon and current_weapon.has_method("stop_fire"):
		current_weapon.stop_fire()


func _reload() -> void:
	if current_weapon and current_weapon.has_method("reload"):
		current_weapon.reload()


func _apply_saved_settings() -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs:
		if "sensitivity" in gs:
			mouse_sensitivity = gs.sensitivity
		if "fov" in gs and camera:
			camera.fov = gs.fov


func add_reserve_ammo(amount: int) -> void:
	if current_weapon and current_weapon.has_method("add_ammo"):
		current_weapon.add_ammo(amount)
		var info = current_weapon.get_ammo_info()
		ammo_changed.emit(info.current, info.reserve)
