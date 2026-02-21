extends Area3D

## Throwable grenade — arc trajectory, fuse timer, area explosion

var throw_direction := Vector3.FORWARD
var throw_force := 18.0
var grenade_velocity := Vector3.ZERO
var fuse_time := 3.0
var blast_radius := 5.0
var blast_damage := 60.0
var gravity_val: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var thrower: Node = null
var has_exploded := false
var time_alive := 0.0

# Visual references
var grenade_mesh: MeshInstance3D
var grenade_light: OmniLight3D
var trail_timer := 0.0


func _ready() -> void:
	grenade_velocity = throw_direction.normalized() * throw_force
	_build_visual()

	# Collision
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.15
	col.shape = shape
	add_child(col)
	collision_layer = 8  # Projectile layer
	collision_mask = 1   # Environment only


func _build_visual() -> void:
	grenade_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	grenade_mesh.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.2, 0.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.3, 0.0)
	mat.emission_energy_multiplier = 3.0
	grenade_mesh.material_override = mat
	add_child(grenade_mesh)

	grenade_light = OmniLight3D.new()
	grenade_light.light_color = Color(1.0, 0.4, 0.0)
	grenade_light.light_energy = 2.0
	grenade_light.omni_range = 3.0
	add_child(grenade_light)


func _physics_process(delta: float) -> void:
	if has_exploded:
		return

	time_alive += delta

	# Apply gravity
	grenade_velocity.y -= gravity_val * delta

	# Move
	global_position += grenade_velocity * delta

	# Bounce off floor
	if global_position.y <= 0.15:
		global_position.y = 0.15
		grenade_velocity.y = abs(grenade_velocity.y) * 0.3
		grenade_velocity.x *= 0.7
		grenade_velocity.z *= 0.7

	# Pulse light as fuse burns
	var fuse_pct := time_alive / fuse_time
	grenade_light.light_energy = 2.0 + fuse_pct * 6.0
	var pulse := sin(time_alive * (5.0 + fuse_pct * 20.0)) * 0.5 + 0.5
	grenade_light.light_color = Color(1.0, 0.4 * (1.0 - fuse_pct), 0.0).lerp(Color(1, 1, 1), pulse * fuse_pct)

	# Trail particles (small glowing spheres)
	trail_timer += delta
	if trail_timer >= 0.05:
		trail_timer = 0.0
		_spawn_trail()

	# Fuse done — explode
	if time_alive >= fuse_time:
		_explode()


func _spawn_trail() -> void:
	var trail := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.04
	sphere.height = 0.08
	trail.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.5, 0.0, 0.8)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.3, 0.0)
	mat.emission_energy_multiplier = 4.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail.material_override = mat
	trail.global_position = global_position
	get_tree().root.add_child(trail)

	var tween := trail.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tween.tween_callback(trail.queue_free)


func _explode() -> void:
	has_exploded = true
	grenade_mesh.visible = false
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_grenade"):
		am.play_grenade()

	# Flash light
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.7, 0.2)
	flash.light_energy = 15.0
	flash.omni_range = blast_radius * 2
	flash.global_position = global_position
	get_tree().root.add_child(flash)

	# Expanding sphere visual
	var explosion := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	explosion.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.5, 0.0, 0.8)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.4, 0.0)
	mat.emission_energy_multiplier = 10.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	explosion.material_override = mat
	explosion.global_position = global_position
	get_tree().root.add_child(explosion)

	# Expand + fade
	var tween := explosion.create_tween()
	tween.set_parallel(true)
	var final_scale := blast_radius * 0.8
	tween.tween_property(explosion, "scale", Vector3.ONE * final_scale, 0.3)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tween.chain().tween_callback(explosion.queue_free)

	var flash_tween := flash.create_tween()
	flash_tween.tween_property(flash, "light_energy", 0.0, 0.4)
	flash_tween.tween_callback(flash.queue_free)

	# Debris cubes
	for i in range(6):
		var cube := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3.ONE * randf_range(0.05, 0.15)
		cube.mesh = box
		var cube_mat := StandardMaterial3D.new()
		cube_mat.albedo_color = Color(1.0, randf_range(0.2, 0.6), 0.0, 1.0)
		cube_mat.emission_enabled = true
		cube_mat.emission = Color(1.0, 0.3, 0.0)
		cube_mat.emission_energy_multiplier = 5.0
		cube_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		cube.material_override = cube_mat
		cube.global_position = global_position
		get_tree().root.add_child(cube)

		var dir := Vector3(randf_range(-1, 1), randf_range(0.5, 2), randf_range(-1, 1)).normalized()
		var end_pos := global_position + dir * randf_range(1, blast_radius * 0.6)
		var cube_tween := cube.create_tween()
		cube_tween.set_parallel(true)
		cube_tween.tween_property(cube, "global_position", end_pos, 0.5)
		cube_tween.tween_property(cube, "rotation", Vector3(randf() * 10, randf() * 10, randf() * 10), 0.5)
		cube_tween.tween_property(cube_mat, "albedo_color:a", 0.0, 0.5)
		cube_tween.chain().tween_callback(cube.queue_free)

	# Damage all enemies in radius
	var space_state := get_world_3d().direct_space_state
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist <= blast_radius:
			var falloff := 1.0 - (dist / blast_radius)
			var dmg := blast_damage * falloff
			if enemy.has_method("take_damage"):
				enemy.take_damage(dmg, thrower)

	# Self-damage if too close
	if thrower and is_instance_valid(thrower):
		var self_dist := global_position.distance_to(thrower.global_position)
		if self_dist <= blast_radius:
			var falloff := 1.0 - (self_dist / blast_radius)
			if thrower.has_method("take_damage"):
				thrower.take_damage(blast_damage * falloff * 0.5, null)

	# Screen shake for nearby player
	var players := get_tree().get_nodes_in_group("player")
	for p in players:
		var pdist := global_position.distance_to(p.global_position)
		if pdist < blast_radius * 2 and p.has_method("_add_screen_shake"):
			p._add_screen_shake(0.5 * (1.0 - pdist / (blast_radius * 2)))

	# Remove grenade after effects
	await get_tree().create_timer(0.5).timeout
	queue_free()
