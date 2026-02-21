extends Node3D
class_name WeaponBase

## Base weapon with hitscan/projectile, recoil, spread, tracers, and impact effects

@export_group("Stats")
@export var weapon_name := "Weapon"
@export var damage := 25.0
@export var fire_rate := 0.1
@export var range_distance := 100.0

@export_group("Ammo")
@export var max_ammo := 30
@export var max_reserve := 120
@export var reload_time := 2.0

@export_group("Projectile")
@export var use_projectile := false
@export var projectile_scene: PackedScene
@export var projectile_speed := 50.0

@export_group("Recoil & Spread")
@export var recoil_amount := 0.003
@export var spread_base := 0.005
@export var spread_increase := 0.002
@export var spread_max := 0.025
@export var spread_recovery := 0.03
@export var headshot_multiplier := 1.5

const MAX_EFFECT_NODES := 30

var current_ammo: int
var reserve_ammo: int
var is_firing := false
var can_fire := true
var is_reloading := false
var fire_timer := 0.0
var camera_ref: Camera3D
var current_spread := 0.0
var _active_effects: Array[Node] = []

@onready var muzzle: Marker3D = get_node_or_null("MuzzlePoint")
@onready var fire_sound: AudioStreamPlayer3D = get_node_or_null("FireSound")
@onready var reload_sound: AudioStreamPlayer3D = get_node_or_null("ReloadSound")

signal ammo_updated(current: int, reserve: int)
signal weapon_fired
signal reload_complete


func _ready() -> void:
	current_ammo = max_ammo
	reserve_ammo = max_reserve


func _process(delta: float) -> void:
	if not can_fire:
		fire_timer -= delta
		if fire_timer <= 0:
			can_fire = true
			if is_firing:
				fire()

	# Spread recovery
	if not is_firing and current_spread > 0:
		current_spread = maxf(current_spread - spread_recovery * delta, 0)


func start_fire(camera: Camera3D = null) -> void:
	camera_ref = camera
	is_firing = true
	if can_fire and not is_reloading:
		fire()


func stop_fire() -> void:
	is_firing = false


func fire() -> void:
	if current_ammo <= 0:
		reload()
		return
	if is_reloading:
		return

	can_fire = false
	fire_timer = fire_rate
	current_ammo -= 1

	if use_projectile:
		_fire_projectile()
	else:
		_fire_hitscan()

	_play_fire_effects()
	_apply_recoil()
	var am = Engine.get_singleton("AudioManager") if Engine.has_singleton("AudioManager") else get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_fire"):
		am.play_fire()

	# Increase spread
	current_spread = minf(current_spread + spread_increase, spread_max)

	ammo_updated.emit(current_ammo, reserve_ammo)
	weapon_fired.emit()

	var player = _get_player()
	if player:
		player.ammo_changed.emit(current_ammo, reserve_ammo)


func _fire_hitscan() -> void:
	if not camera_ref:
		return

	var space_state := get_world_3d().direct_space_state
	var screen_center := camera_ref.get_viewport().get_visible_rect().size / 2

	# Apply spread
	var spread_offset := Vector2(
		randf_range(-current_spread, current_spread),
		randf_range(-current_spread, current_spread)
	) * 1000.0
	var aim_point := screen_center + spread_offset

	var ray_origin := camera_ref.project_ray_origin(aim_point)
	var ray_end := ray_origin + camera_ref.project_ray_normal(aim_point) * range_distance

	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var p = _get_player()
	if p:
		query.exclude = [p.get_rid()]
	query.collision_mask = 0b11111

	var result := space_state.intersect_ray(query)

	var hit_pos := ray_end
	if result:
		hit_pos = result.position
		var hit_body = result.collider
		if hit_body.has_method("take_damage"):
			var final_damage := damage
			# Headshot detection — upper 25% of enemy
			if "global_position" in hit_body:
				var hit_height: float = result.position.y - hit_body.global_position.y
				var enemy_height: float = 1.8 * (hit_body.enemy_scale if "enemy_scale" in hit_body else 1.0)
				if hit_height > enemy_height * 0.75:
					final_damage *= headshot_multiplier
			hit_body.take_damage(final_damage, _get_player())

		# Hit sparks
		EffectSpawner.spawn_hit_sparks(get_tree(), result.position, result.normal)
		_spawn_impact(result.position, result.normal)

	# Tracer
	var muzzle_pos := muzzle.global_position if muzzle else global_position
	_spawn_tracer(muzzle_pos, hit_pos)


func _fire_projectile() -> void:
	if not projectile_scene or not camera_ref:
		return

	var spawn_pos: Vector3
	if muzzle:
		spawn_pos = muzzle.global_position
	else:
		spawn_pos = global_position + Vector3(0, 0, -0.5)

	var screen_center := camera_ref.get_viewport().get_visible_rect().size / 2
	var aim_dir := camera_ref.project_ray_normal(screen_center)

	# Apply spread to projectile
	aim_dir += Vector3(
		randf_range(-current_spread, current_spread),
		randf_range(-current_spread, current_spread),
		0
	)
	aim_dir = aim_dir.normalized()

	var projectile = projectile_scene.instantiate()
	get_tree().root.add_child(projectile)
	projectile.global_position = spawn_pos
	projectile.look_at(spawn_pos + aim_dir)
	if projectile.has_method("setup"):
		projectile.setup(damage, aim_dir * projectile_speed, _get_player())


func _apply_recoil() -> void:
	var player = _get_player()
	if not player:
		return
	if "target_pitch" in player:
		player.target_pitch += recoil_amount
		player.target_pitch = clampf(player.target_pitch, deg_to_rad(-50.0), deg_to_rad(70.0))


func reload() -> void:
	if is_reloading or reserve_ammo <= 0 or current_ammo >= max_ammo:
		return

	is_reloading = true
	is_firing = false
	current_spread = 0.0

	if reload_sound:
		reload_sound.play()
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_reload"):
		am.play_reload()

	await get_tree().create_timer(reload_time).timeout

	var ammo_needed := max_ammo - current_ammo
	var ammo_to_load := mini(ammo_needed, reserve_ammo)
	current_ammo += ammo_to_load
	reserve_ammo -= ammo_to_load
	is_reloading = false

	ammo_updated.emit(current_ammo, reserve_ammo)
	reload_complete.emit()

	var player = _get_player()
	if player:
		player.ammo_changed.emit(current_ammo, reserve_ammo)


func equip() -> void:
	current_spread = 0.0


func unequip() -> void:
	is_firing = false
	is_reloading = false
	current_spread = 0.0


func add_ammo(amount: int) -> void:
	reserve_ammo = clampi(reserve_ammo + amount, 0, max_reserve)
	ammo_updated.emit(current_ammo, reserve_ammo)


func get_ammo_info() -> Dictionary:
	return {"current": current_ammo, "reserve": reserve_ammo}


func _play_fire_effects() -> void:
	if fire_sound:
		fire_sound.play()

	# Muzzle flash — bright light + quick mesh burst
	if muzzle:
		var flash := OmniLight3D.new()
		flash.light_color = Color(1, 0.85, 0.3)
		flash.light_energy = 8.0
		flash.omni_range = 4.0
		muzzle.add_child(flash)
		var tween := flash.create_tween()
		tween.tween_property(flash, "light_energy", 0.0, 0.1)
		tween.tween_callback(flash.queue_free)

		# Muzzle flash mesh (star-like burst)
		var flash_mesh := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.05
		sphere.height = 0.1
		flash_mesh.mesh = sphere
		var flash_mat := StandardMaterial3D.new()
		flash_mat.albedo_color = Color(1, 0.9, 0.5, 1)
		flash_mat.emission_enabled = true
		flash_mat.emission = Color(1, 0.8, 0.3)
		flash_mat.emission_energy_multiplier = 15.0
		flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		flash_mesh.material_override = flash_mat
		muzzle.add_child(flash_mesh)
		var mtween := flash_mesh.create_tween()
		mtween.set_parallel(true)
		mtween.tween_property(flash_mesh, "scale", Vector3(2.5, 2.5, 2.5), 0.05)
		mtween.tween_property(flash_mat, "albedo_color:a", 0.0, 0.08)
		mtween.chain().tween_callback(flash_mesh.queue_free)


func _track_effect(node: Node) -> void:
	_active_effects = _active_effects.filter(func(n): return is_instance_valid(n))
	while _active_effects.size() >= MAX_EFFECT_NODES:
		var old: Node = _active_effects.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	_active_effects.append(node)


func _spawn_tracer(from_pos: Vector3, to_pos: Vector3) -> void:
	var tracer := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.008
	cyl.bottom_radius = 0.008
	var dist := from_pos.distance_to(to_pos)
	cyl.height = dist
	tracer.mesh = cyl

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.9, 0.4, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(1, 0.8, 0.2)
	mat.emission_energy_multiplier = 6.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tracer.material_override = mat

	get_tree().root.add_child(tracer)
	_track_effect(tracer)
	var mid := (from_pos + to_pos) / 2.0
	tracer.global_position = mid
	tracer.look_at(to_pos)
	tracer.rotate_object_local(Vector3(1, 0, 0), deg_to_rad(90))

	var tween := tracer.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.1)
	tween.tween_callback(tracer.queue_free)


func _spawn_impact(pos: Vector3, normal: Vector3) -> void:
	# Impact flash
	var flash := OmniLight3D.new()
	flash.light_color = Color(1, 0.6, 0.2)
	flash.light_energy = 3.0
	flash.omni_range = 2.0
	flash.position = pos + normal * 0.05
	get_tree().root.add_child(flash)
	_track_effect(flash)

	var tween := flash.create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.15)
	tween.tween_callback(flash.queue_free)

	# Impact marker mesh
	var marker := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.1
	marker.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.7, 0.2, 1)
	mat.emission_enabled = true
	mat.emission = Color(1, 0.5, 0.1)
	mat.emission_energy_multiplier = 8.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker.material_override = mat
	marker.position = pos

	get_tree().root.add_child(marker)
	_track_effect(marker)
	var mtween := marker.create_tween()
	mtween.tween_property(mat, "albedo_color:a", 0.0, 0.3)
	mtween.tween_callback(marker.queue_free)


func _get_player() -> CharacterBody3D:
	var parent = get_parent()
	while parent:
		if parent is CharacterBody3D:
			return parent
		parent = parent.get_parent()
	return null
