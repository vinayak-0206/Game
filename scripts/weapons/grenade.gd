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
var trail_particles: GPUParticles3D = null


func _ready() -> void:
	grenade_velocity = throw_direction.normalized() * throw_force
	_build_visual()

	# GPU trail particles
	trail_particles = ParticleFactory.create_grenade_trail(get_tree())
	add_child(trail_particles)

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

	# Trail handled by GPU particles (auto-emitting)

	# Fuse done — explode
	if time_alive >= fuse_time:
		_explode()



func _explode() -> void:
	has_exploded = true
	grenade_mesh.visible = false
	if trail_particles:
		trail_particles.emitting = false
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_grenade"):
		am.play_grenade()

	# GPU explosion particles + flash + scorch decal
	ParticleFactory.spawn_grenade_explosion(get_tree(), global_position, blast_radius)
	DecalSpawner.spawn_scorch_mark(get_tree(), global_position)

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
