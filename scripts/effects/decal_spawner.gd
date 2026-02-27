extends Node
class_name DecalSpawner

## Spawns bullet hole and scorch mark decals using Decal nodes
## Procedurally generates textures (cached) for decal appearance

const MAX_DECALS := 50

static var _active_decals: Array[Node] = []
static var _bullet_hole_tex: Texture2D = null
static var _scorch_mark_tex: Texture2D = null


static func _track(node: Node) -> void:
	_active_decals = _active_decals.filter(func(n): return is_instance_valid(n))
	while _active_decals.size() >= MAX_DECALS:
		var old: Node = _active_decals.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	_active_decals.append(node)


static func _get_bullet_hole_texture() -> Texture2D:
	if _bullet_hole_tex:
		return _bullet_hole_tex
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := Vector2(16, 16)
	for x in range(32):
		for y in range(32):
			var dist := Vector2(x, y).distance_to(center)
			if dist < 6:
				img.set_pixel(x, y, Color(0.05, 0.05, 0.05, 0.9))
			elif dist < 10:
				var t := (dist - 6.0) / 4.0
				img.set_pixel(x, y, Color(0.1, 0.08, 0.06, 0.7 * (1.0 - t)))
			elif dist < 14:
				var t := (dist - 10.0) / 4.0
				img.set_pixel(x, y, Color(0.15, 0.12, 0.1, 0.3 * (1.0 - t)))
	_bullet_hole_tex = ImageTexture.create_from_image(img)
	return _bullet_hole_tex


static func _get_scorch_mark_texture() -> Texture2D:
	if _scorch_mark_tex:
		return _scorch_mark_tex
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := Vector2(32, 32)
	for x in range(64):
		for y in range(64):
			var dist := Vector2(x, y).distance_to(center)
			if dist < 20:
				img.set_pixel(x, y, Color(0.08, 0.05, 0.02, 0.85))
			elif dist < 28:
				var t := (dist - 20.0) / 8.0
				img.set_pixel(x, y, Color(0.15, 0.08, 0.02, 0.6 * (1.0 - t)))
			elif dist < 32:
				var t := (dist - 28.0) / 4.0
				img.set_pixel(x, y, Color(0.2, 0.1, 0.0, 0.2 * (1.0 - t)))
	_scorch_mark_tex = ImageTexture.create_from_image(img)
	return _scorch_mark_tex


static func spawn_bullet_hole(tree: SceneTree, pos: Vector3, normal: Vector3) -> void:
	var decal := Decal.new()
	decal.texture_albedo = _get_bullet_hole_texture()
	decal.size = Vector3(0.15, 0.1, 0.15)
	decal.global_position = pos + normal * 0.01
	decal.modulate = Color(1, 1, 1, 0.9)

	# Orient decal to face along the normal
	if normal.abs() != Vector3.UP:
		decal.look_at(pos + normal, Vector3.UP)
		decal.rotate_object_local(Vector3(1, 0, 0), deg_to_rad(90))
	else:
		# Normal is up/down — use default orientation
		if normal.y < 0:
			decal.rotation.x = deg_to_rad(180)

	tree.root.add_child(decal)
	_track(decal)

	# Fade out and remove after 8 seconds
	tree.create_timer(6.0).timeout.connect(func():
		if is_instance_valid(decal):
			var tween := decal.create_tween()
			tween.tween_property(decal, "modulate:a", 0.0, 2.0)
			tween.tween_callback(decal.queue_free)
	)


static func spawn_scorch_mark(tree: SceneTree, pos: Vector3) -> void:
	var decal := Decal.new()
	decal.texture_albedo = _get_scorch_mark_texture()
	decal.size = Vector3(2.5, 0.5, 2.5)
	decal.global_position = pos + Vector3(0, 0.05, 0)
	decal.modulate = Color(1, 1, 1, 0.85)

	# Scorch marks always face up (on floor)
	tree.root.add_child(decal)
	_track(decal)

	# Random rotation for variety
	decal.rotation.y = randf() * TAU

	# Fade out after 12 seconds
	tree.create_timer(10.0).timeout.connect(func():
		if is_instance_valid(decal):
			var tween := decal.create_tween()
			tween.tween_property(decal, "modulate:a", 0.0, 2.0)
			tween.tween_callback(decal.queue_free)
	)
