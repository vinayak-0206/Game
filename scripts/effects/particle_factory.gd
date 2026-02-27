extends Node
class_name ParticleFactory

## GPU particle factory — replaces mesh-based fake particles with GPUParticles3D
## Auto-cleanup via one_shot + timer, capped at 40 active nodes

const MAX_ACTIVE := 40

static var _active_particles: Array[Node] = []


static func _track(node: Node) -> void:
	_active_particles = _active_particles.filter(func(n): return is_instance_valid(n))
	while _active_particles.size() >= MAX_ACTIVE:
		var old: Node = _active_particles.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	_active_particles.append(node)


static func _auto_free(tree: SceneTree, node: Node, lifetime: float) -> void:
	tree.create_timer(lifetime).timeout.connect(func():
		if is_instance_valid(node):
			node.queue_free()
	)


static func spawn_death_explosion(tree: SceneTree, pos: Vector3, color: Color) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 24
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.lifetime = 0.8
	particles.emitting = true

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 8.0
	mat.gravity = Vector3(0, -6, 0)
	mat.damping_min = 1.0
	mat.damping_max = 3.0
	mat.scale_min = 0.06
	mat.scale_max = 0.18
	mat.color = color
	var color_ramp := Gradient.new()
	color_ramp.set_color(0, color)
	color_ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var color_tex := GradientTexture1D.new()
	color_tex.gradient = color_ramp
	mat.color_ramp = color_tex
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.3
	particles.process_material = mat

	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	particles.draw_pass_1 = mesh

	particles.global_position = pos
	tree.root.add_child(particles)
	_track(particles)
	_auto_free(tree, particles, 1.2)

	# Companion flash light
	var flash := OmniLight3D.new()
	flash.light_color = color
	flash.light_energy = 10.0
	flash.omni_range = 6.0
	flash.global_position = pos
	tree.root.add_child(flash)
	var tween := flash.create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.4)
	tween.tween_callback(flash.queue_free)


static func spawn_hit_sparks(tree: SceneTree, pos: Vector3, normal: Vector3) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 8
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.lifetime = 0.3

	var mat := ParticleProcessMaterial.new()
	mat.direction = normal
	mat.spread = 35.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 5.0
	mat.gravity = Vector3(0, -8, 0)
	mat.scale_min = 0.02
	mat.scale_max = 0.05
	mat.color = Color(1.0, 0.8, 0.3, 1.0)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.9, 0.5, 1.0))
	ramp.set_color(1, Color(1.0, 0.4, 0.1, 0.0))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	mat.color_ramp = ramp_tex
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	particles.process_material = mat

	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	particles.draw_pass_1 = mesh

	particles.global_position = pos
	particles.emitting = true
	tree.root.add_child(particles)
	_track(particles)
	_auto_free(tree, particles, 0.6)


static func spawn_pickup_effect(tree: SceneTree, pos: Vector3, color: Color) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 16
	particles.one_shot = true
	particles.explosiveness = 0.8
	particles.lifetime = 0.6

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 60.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 4.0
	mat.gravity = Vector3(0, 1, 0)
	mat.scale_min = 0.04
	mat.scale_max = 0.08
	mat.color = color
	var ramp := Gradient.new()
	ramp.set_color(0, Color(color.r, color.g, color.b, 1.0))
	ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	mat.color_ramp = ramp_tex
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_radius = 0.3
	mat.emission_ring_inner_radius = 0.1
	mat.emission_ring_height = 0.1
	mat.emission_ring_axis = Vector3(0, 1, 0)
	particles.process_material = mat

	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	particles.draw_pass_1 = mesh

	particles.global_position = pos
	particles.emitting = true
	tree.root.add_child(particles)
	_track(particles)
	_auto_free(tree, particles, 1.0)


static func spawn_muzzle_flash(tree: SceneTree, pos: Vector3, forward: Vector3) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 6
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.lifetime = 0.08

	var mat := ParticleProcessMaterial.new()
	mat.direction = forward
	mat.spread = 15.0
	mat.initial_velocity_min = 4.0
	mat.initial_velocity_max = 8.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.03
	mat.scale_max = 0.08
	mat.color = Color(1.0, 0.85, 0.4, 1.0)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.9, 0.5, 1.0))
	ramp.set_color(1, Color(1.0, 0.5, 0.1, 0.0))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	mat.color_ramp = ramp_tex
	particles.process_material = mat

	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	particles.draw_pass_1 = mesh

	particles.global_position = pos
	particles.emitting = true
	tree.root.add_child(particles)
	_track(particles)
	_auto_free(tree, particles, 0.2)


static func spawn_grenade_explosion(tree: SceneTree, pos: Vector3, radius: float) -> void:
	# Main fireball
	var particles := GPUParticles3D.new()
	particles.amount = 32
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.lifetime = 0.6

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 4.0
	mat.initial_velocity_max = radius * 2.0
	mat.gravity = Vector3(0, -3, 0)
	mat.damping_min = 2.0
	mat.damping_max = 5.0
	mat.scale_min = 0.1
	mat.scale_max = 0.4
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.9, 0.4, 1.0))
	ramp.add_point(0.3, Color(1.0, 0.4, 0.0, 0.9))
	ramp.set_color(1, Color(0.3, 0.1, 0.0, 0.0))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	mat.color_ramp = ramp_tex
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.5
	particles.process_material = mat

	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	particles.draw_pass_1 = mesh

	particles.global_position = pos
	particles.emitting = true
	tree.root.add_child(particles)
	_track(particles)

	# Smoke ring
	var smoke := GPUParticles3D.new()
	smoke.amount = 12
	smoke.one_shot = true
	smoke.explosiveness = 0.7
	smoke.lifetime = 1.2

	var smoke_mat := ParticleProcessMaterial.new()
	smoke_mat.direction = Vector3(0, 1, 0)
	smoke_mat.spread = 90.0
	smoke_mat.initial_velocity_min = 1.0
	smoke_mat.initial_velocity_max = 3.0
	smoke_mat.gravity = Vector3(0, 0.5, 0)
	smoke_mat.scale_min = 0.2
	smoke_mat.scale_max = 0.6
	var smoke_ramp := Gradient.new()
	smoke_ramp.set_color(0, Color(0.4, 0.35, 0.3, 0.6))
	smoke_ramp.set_color(1, Color(0.2, 0.2, 0.2, 0.0))
	var smoke_ramp_tex := GradientTexture1D.new()
	smoke_ramp_tex.gradient = smoke_ramp
	smoke_mat.color_ramp = smoke_ramp_tex
	smoke_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	smoke_mat.emission_sphere_radius = 0.3
	smoke.process_material = smoke_mat

	var smoke_mesh := SphereMesh.new()
	smoke_mesh.radius = 0.5
	smoke_mesh.height = 1.0
	smoke.draw_pass_1 = smoke_mesh

	smoke.global_position = pos
	smoke.emitting = true
	tree.root.add_child(smoke)
	_track(smoke)

	# Flash light
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.7, 0.2)
	flash.light_energy = 20.0
	flash.omni_range = radius * 3
	flash.global_position = pos
	tree.root.add_child(flash)
	var tween := flash.create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.4)
	tween.tween_callback(flash.queue_free)

	_auto_free(tree, particles, 1.0)
	_auto_free(tree, smoke, 1.8)


static func create_grenade_trail(tree: SceneTree) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = 20
	particles.lifetime = 0.4
	particles.explosiveness = 0.0
	particles.one_shot = false

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 0.2
	mat.initial_velocity_max = 0.8
	mat.gravity = Vector3(0, 0.5, 0)
	mat.scale_min = 0.02
	mat.scale_max = 0.05
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.5, 0.0, 0.8))
	ramp.set_color(1, Color(1.0, 0.2, 0.0, 0.0))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	mat.color_ramp = ramp_tex
	particles.process_material = mat

	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	particles.draw_pass_1 = mesh

	particles.emitting = true
	return particles


static func spawn_landing_dust(tree: SceneTree, pos: Vector3) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 10
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.lifetime = 0.5

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0.2, 0)
	mat.spread = 85.0
	mat.initial_velocity_min = 1.5
	mat.initial_velocity_max = 3.5
	mat.gravity = Vector3(0, -2, 0)
	mat.scale_min = 0.04
	mat.scale_max = 0.1
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.6, 0.55, 0.5, 0.5))
	ramp.set_color(1, Color(0.5, 0.45, 0.4, 0.0))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	mat.color_ramp = ramp_tex
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_radius = 0.3
	mat.emission_ring_inner_radius = 0.0
	mat.emission_ring_height = 0.05
	mat.emission_ring_axis = Vector3(0, 1, 0)
	particles.process_material = mat

	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	particles.draw_pass_1 = mesh

	particles.global_position = pos
	particles.emitting = true
	tree.root.add_child(particles)
	_track(particles)
	_auto_free(tree, particles, 0.8)


static func spawn_footstep_dust(tree: SceneTree, pos: Vector3) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 4
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.lifetime = 0.3

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 60.0
	mat.initial_velocity_min = 0.5
	mat.initial_velocity_max = 1.5
	mat.gravity = Vector3(0, -2, 0)
	mat.scale_min = 0.02
	mat.scale_max = 0.04
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.5, 0.45, 0.4, 0.3))
	ramp.set_color(1, Color(0.4, 0.35, 0.3, 0.0))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	mat.color_ramp = ramp_tex
	particles.process_material = mat

	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	particles.draw_pass_1 = mesh

	particles.global_position = pos
	particles.emitting = true
	tree.root.add_child(particles)
	_track(particles)
	_auto_free(tree, particles, 0.5)
