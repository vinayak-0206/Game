extends Area3D
class_name RocketProjectile

## Rocket projectile with AOE blast damage and GPU particle explosion

@export var speed := 35.0
@export var lifetime := 6.0
@export var blast_radius := 6.0
@export var blast_damage := 80.0

var damage := 80.0
var velocity_dir := Vector3.FORWARD
var instigator: Node = null
var has_exploded := false

# Visual
var rocket_mesh: MeshInstance3D
var trail_particles: GPUParticles3D
var rocket_light: OmniLight3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_build_visual()

	# Collision
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.2
	col.shape = shape
	add_child(col)
	collision_layer = 8  # Projectile layer
	collision_mask = 0b111  # Environment + Player + Enemy

	await get_tree().create_timer(lifetime).timeout
	if not has_exploded:
		_explode()


func _build_visual() -> void:
	rocket_mesh = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.08
	cyl.height = 0.3
	rocket_mesh.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.6, 0.6)
	mat.metallic = 0.7
	mat.roughness = 0.3
	rocket_mesh.material_override = mat
	rocket_mesh.rotation.x = deg_to_rad(90)
	add_child(rocket_mesh)

	# Nose cone (red)
	var nose := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.05
	cone.height = 0.1
	nose.mesh = cone
	var nose_mat := StandardMaterial3D.new()
	nose_mat.albedo_color = Color(0.9, 0.2, 0.1)
	nose_mat.emission_enabled = true
	nose_mat.emission = Color(1, 0.3, 0.1)
	nose_mat.emission_energy_multiplier = 2.0
	nose.material_override = nose_mat
	nose.rotation.x = deg_to_rad(90)
	nose.position.z = -0.2
	add_child(nose)

	# Trail particles
	trail_particles = ParticleFactory.create_grenade_trail(get_tree())
	add_child(trail_particles)

	# Rocket light
	rocket_light = OmniLight3D.new()
	rocket_light.light_color = Color(1.0, 0.5, 0.1)
	rocket_light.light_energy = 3.0
	rocket_light.omni_range = 4.0
	add_child(rocket_light)


func setup(dmg: float, vel: Vector3, from: Node) -> void:
	damage = dmg
	blast_damage = dmg
	velocity_dir = vel
	instigator = from


func _physics_process(delta: float) -> void:
	if has_exploded:
		return
	global_position += velocity_dir * delta


func _on_body_entered(body: Node3D) -> void:
	if body == instigator or has_exploded:
		return
	_explode()


func _explode() -> void:
	if has_exploded:
		return
	has_exploded = true
	rocket_mesh.visible = false
	if trail_particles:
		trail_particles.emitting = false

	# GPU explosion + scorch
	ParticleFactory.spawn_grenade_explosion(get_tree(), global_position, blast_radius)
	DecalSpawner.spawn_scorch_mark(get_tree(), global_position)

	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_grenade"):
		am.play_grenade()

	# AOE damage to enemies
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist <= blast_radius:
			var falloff := 1.0 - (dist / blast_radius)
			if enemy.has_method("take_damage"):
				enemy.take_damage(blast_damage * falloff, instigator)

	# Self-damage if too close
	if instigator and is_instance_valid(instigator):
		var self_dist := global_position.distance_to(instigator.global_position)
		if self_dist <= blast_radius:
			var falloff := 1.0 - (self_dist / blast_radius)
			if instigator.has_method("take_damage"):
				instigator.take_damage(blast_damage * falloff * 0.5, null)

	# Screen shake
	var players := get_tree().get_nodes_in_group("player")
	for p in players:
		var pdist := global_position.distance_to(p.global_position)
		if pdist < blast_radius * 2 and p.has_method("_add_screen_shake"):
			p._add_screen_shake(0.5 * (1.0 - pdist / (blast_radius * 2)))

	await get_tree().create_timer(0.5).timeout
	queue_free()
