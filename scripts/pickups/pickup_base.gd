extends Area3D
class_name PickupBase

## Base class for all pickups with rotating glowing visual

@export var rotation_speed := 2.0
@export var bob_height := 0.3
@export var bob_speed := 2.0
@export var respawn_time := 15.0

var start_y: float
var is_active := true
var time := 0.0
var pickup_color := Color(1, 1, 1)
var visual_node: Node3D


func _ready() -> void:
	start_y = global_position.y + 0.5
	global_position.y = start_y
	body_entered.connect(_on_body_entered)
	add_to_group("pickups")
	_build_visual()


func _build_visual() -> void:
	visual_node = get_node_or_null("Visual")
	if not visual_node:
		visual_node = Node3D.new()
		visual_node.name = "Visual"
		add_child(visual_node)

	# Try loading Blender model
	var model_path := _get_pickup_model_path()
	var model_scene = load(model_path) as PackedScene if model_path != "" else null
	if model_scene:
		var model_instance := model_scene.instantiate()
		model_instance.name = "PickupGLB"
		visual_node.add_child(model_instance)
	else:
		# Fallback: primitive visuals
		var orb := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.3
		sphere.height = 0.6
		orb.mesh = sphere
		var mat := StandardMaterial3D.new()
		mat.albedo_color = pickup_color
		mat.emission_enabled = true
		mat.emission = pickup_color
		mat.emission_energy_multiplier = 4.0
		mat.metallic = 0.5
		mat.roughness = 0.3
		orb.material_override = mat
		visual_node.add_child(orb)

		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.35
		torus.outer_radius = 0.5
		ring.mesh = torus
		var ring_mat := StandardMaterial3D.new()
		ring_mat.albedo_color = pickup_color * 0.6
		ring_mat.emission_enabled = true
		ring_mat.emission = pickup_color * 0.8
		ring_mat.emission_energy_multiplier = 2.0
		ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring_mat.albedo_color.a = 0.6
		ring.material_override = ring_mat
		visual_node.add_child(ring)

	# Point light (always add regardless of model)
	var light := OmniLight3D.new()
	light.light_color = pickup_color
	light.light_energy = 2.0
	light.omni_range = 4.0
	visual_node.add_child(light)


func _get_pickup_model_path() -> String:
	# Green = health, Yellow = ammo
	if pickup_color.g > 0.8 and pickup_color.r < 0.3:
		return "res://models/SM_HealthPickup.glb"
	elif pickup_color.r > 0.8 and pickup_color.g > 0.5:
		return "res://models/SM_AmmoPickup.glb"
	return ""


func _process(delta: float) -> void:
	if not is_active:
		return
	time += delta
	if visual_node:
		visual_node.rotation.y += rotation_speed * delta
	global_position.y = start_y + sin(time * bob_speed) * bob_height


func _on_body_entered(body: Node3D) -> void:
	if not is_active:
		return
	if body.is_in_group("player"):
		if _apply_pickup(body):
			_consume()


func _apply_pickup(_player: Node3D) -> bool:
	return false


func _consume() -> void:
	is_active = false
	visible = false
	_set_light_enabled(false)
	ParticleFactory.spawn_pickup_effect(get_tree(), global_position, pickup_color)
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_pickup"):
		am.play_pickup()
	await get_tree().create_timer(respawn_time).timeout
	is_active = true
	visible = true
	_set_light_enabled(true)


func _set_light_enabled(enabled: bool) -> void:
	if visual_node:
		for child in visual_node.get_children():
			if child is OmniLight3D:
				child.visible = enabled
