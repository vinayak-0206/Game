extends Node
class_name EffectSpawner

## Static helper for spawning visual effects with node limits

const MAX_EFFECT_NODES := 60

static var _active_effects: Array[Node] = []


static func _track(node: Node) -> void:
	_active_effects = _active_effects.filter(func(n): return is_instance_valid(n))
	while _active_effects.size() >= MAX_EFFECT_NODES:
		var old: Node = _active_effects.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	_active_effects.append(node)


static func spawn_death_explosion(tree: SceneTree, pos: Vector3, color: Color) -> void:
	var count := randi_range(6, 8)
	for i in range(count):
		var cube := MeshInstance3D.new()
		var box := BoxMesh.new()
		var s := randf_range(0.04, 0.12)
		box.size = Vector3(s, s, s)
		cube.mesh = box

		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = randf_range(3.0, 8.0)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		cube.material_override = mat
		cube.global_position = pos + Vector3(randf_range(-0.2, 0.2), randf_range(0, 0.3), randf_range(-0.2, 0.2))
		tree.root.add_child(cube)
		_track(cube)

		var dir := Vector3(randf_range(-1, 1), randf_range(0.5, 2.5), randf_range(-1, 1)).normalized()
		var end := pos + dir * randf_range(1.5, 4.0)
		var tween := cube.create_tween()
		tween.set_parallel(true)
		tween.tween_property(cube, "global_position", end, randf_range(0.4, 0.8))
		tween.tween_property(cube, "rotation", Vector3(randf() * 15, randf() * 15, randf() * 15), 0.7)
		tween.tween_property(mat, "albedo_color:a", 0.0, randf_range(0.5, 0.8))
		tween.chain().tween_callback(cube.queue_free)


static func spawn_hit_sparks(tree: SceneTree, pos: Vector3, normal: Vector3) -> void:
	var count := randi_range(3, 5)
	for i in range(count):
		var spark := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.02, 0.02, 0.02)
		spark.mesh = box

		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.8, 0.3, 1.0)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.6, 0.1)
		mat.emission_energy_multiplier = 10.0
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		spark.material_override = mat
		spark.global_position = pos
		tree.root.add_child(spark)
		_track(spark)

		var dir := (normal + Vector3(randf_range(-0.5, 0.5), randf_range(0, 1), randf_range(-0.5, 0.5))).normalized()
		var end := pos + dir * randf_range(0.3, 1.0)
		var tween := spark.create_tween()
		tween.set_parallel(true)
		tween.tween_property(spark, "global_position", end, 0.2)
		tween.tween_property(mat, "albedo_color:a", 0.0, 0.25)
		tween.chain().tween_callback(spark.queue_free)


static func spawn_pickup_effect(tree: SceneTree, pos: Vector3, color: Color) -> void:
	for i in range(8):
		var dot := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.04
		sphere.height = 0.08
		dot.mesh = sphere

		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 5.0
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dot.material_override = mat

		var angle := float(i) / 8.0 * TAU
		dot.global_position = pos + Vector3(cos(angle) * 0.3, 0, sin(angle) * 0.3)
		tree.root.add_child(dot)
		_track(dot)

		var end_pos := pos + Vector3(cos(angle + PI) * 0.1, 2.0, sin(angle + PI) * 0.1)
		var delay := float(i) * 0.05
		var tween := dot.create_tween()
		tween.tween_interval(delay)
		tween.set_parallel(true)
		tween.tween_property(dot, "global_position", end_pos, 0.5)
		tween.tween_property(mat, "albedo_color:a", 0.0, 0.6)
		tween.chain().tween_callback(dot.queue_free)
