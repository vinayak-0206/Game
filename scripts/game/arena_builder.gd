extends Node3D

## Builds themed procedural arenas based on MapData configuration

var env: Environment
var sky_mat: ProceduralSkyMaterial
var theme: MapData
var half_size: float


func _ready() -> void:
	# Use selected map or default to Neon Nexus
	var gs = Engine.get_singleton("GameState") if Engine.has_singleton("GameState") else null
	if gs == null:
		gs = get_node_or_null("/root/GameState")
	if gs and "selected_map" in gs and gs.selected_map != null:
		theme = gs.selected_map
	else:
		theme = MapData.neon_nexus()

	half_size = theme.arena_size / 2.0

	_build_environment()
	_build_floor()
	if theme.has_walls:
		_build_walls()
	_build_covers()
	_build_pillars()
	_build_crates()
	_build_platforms()
	_build_lights()
	_build_pickups()

	# Hazards
	if theme.has_lava:
		_build_lava_hazards()
	if theme.has_void:
		_build_void_kill_zone()


func _build_environment() -> void:
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = theme.sky_top
	sky_mat.sky_horizon_color = theme.sky_horizon
	sky_mat.ground_bottom_color = theme.ground_bottom
	sky_mat.ground_horizon_color = theme.ground_horizon
	sky_mat.sky_energy_multiplier = 0.3

	var sky := Sky.new()
	sky.sky_material = sky_mat

	env = Environment.new()
	env.set("background_mode", 2)
	env.sky = sky
	env.set("ambient_light_source", 1)
	env.ambient_light_energy = theme.ambient_energy
	env.ambient_light_color = theme.ambient_color

	env.set("tonemap_mode", 2)
	env.tonemap_exposure = 1.1

	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.1
	env.set("glow_blend_mode", 2)

	env.fog_enabled = true
	env.fog_light_color = theme.fog_color
	env.fog_density = theme.fog_density

	env.ssao_enabled = true
	env.ssao_radius = 2.0
	env.ssao_intensity = 2.0

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)


func _build_floor() -> void:
	var size := theme.arena_size
	var body := StaticBody3D.new()
	body.name = "Floor"
	body.position = Vector3(0, -0.1, 0)
	add_child(body)

	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(size, 0.2, size)
	mesh_inst.mesh = box
	mesh_inst.material_override = _mat(theme.floor_color, 0.2, 0.6)
	body.add_child(mesh_inst)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size, 0.2, size)
	col.shape = shape
	body.add_child(col)

	# Glowing edge strips
	var edge_mat := _glow_mat(theme.glow_color, theme.glow_energy)
	var hs := size / 2.0
	var edges := [
		[Vector3(0, 0.01, hs - 0.5), Vector3(size, 0.05, 0.15)],
		[Vector3(0, 0.01, -(hs - 0.5)), Vector3(size, 0.05, 0.15)],
		[Vector3(hs - 0.5, 0.01, 0), Vector3(0.15, 0.05, size)],
		[Vector3(-(hs - 0.5), 0.01, 0), Vector3(0.15, 0.05, size)],
	]
	for edge_data in edges:
		var edge_mesh := MeshInstance3D.new()
		var edge_box := BoxMesh.new()
		edge_box.size = edge_data[1]
		edge_mesh.mesh = edge_box
		edge_mesh.material_override = edge_mat
		edge_mesh.position = edge_data[0]
		add_child(edge_mesh)

	# Ice floor visual - lighter shimmer
	if theme.has_ice:
		var ice_overlay := MeshInstance3D.new()
		var ice_box := BoxMesh.new()
		ice_box.size = Vector3(size - 1, 0.02, size - 1)
		ice_overlay.mesh = ice_box
		var ice_mat := StandardMaterial3D.new()
		ice_mat.albedo_color = Color(0.7, 0.8, 0.95, 0.3)
		ice_mat.metallic = 0.9
		ice_mat.roughness = 0.05
		ice_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ice_overlay.material_override = ice_mat
		ice_overlay.position = Vector3(0, 0.02, 0)
		add_child(ice_overlay)


func _build_walls() -> void:
	var mat := _mat(theme.wall_color, 0.3, 0.7)
	var trim_mat := _glow_mat(theme.glow_color * 0.8, 2.0)
	var hs := half_size
	var wh := theme.wall_height

	var walls := [
		["Wall_N", Vector3(0, wh / 2, hs), Vector3(theme.arena_size, wh, 0.5)],
		["Wall_S", Vector3(0, wh / 2, -hs), Vector3(theme.arena_size, wh, 0.5)],
		["Wall_E", Vector3(hs, wh / 2, 0), Vector3(0.5, wh, theme.arena_size)],
		["Wall_W", Vector3(-hs, wh / 2, 0), Vector3(0.5, wh, theme.arena_size)],
	]

	for data in walls:
		_create_static_box(data[0], data[1], data[2], mat)

		var trim := MeshInstance3D.new()
		var trim_box := BoxMesh.new()
		var trim_size: Vector3
		if data[2].x > data[2].z:
			trim_size = Vector3(data[2].x, 0.1, 0.6)
		else:
			trim_size = Vector3(0.6, 0.1, data[2].z)
		trim_box.size = trim_size
		trim.mesh = trim_box
		trim.material_override = trim_mat
		trim.position = Vector3(data[1].x, wh + 0.05, data[1].z)
		add_child(trim)


func _build_covers() -> void:
	var mat := _mat(theme.cover_color, 0.4, 0.6)
	var glow := _glow_mat(theme.glow_color, 2.5)

	var scale_factor := theme.arena_size / 44.0
	var covers := [
		["Cover_C1", Vector3(3, 0.75, 2), Vector3(4.5, 1.5, 0.3)],
		["Cover_C2", Vector3(-3, 0.75, -2), Vector3(4.5, 1.5, 0.3)],
		["Cover_C3", Vector3(0, 0.75, 5), Vector3(0.3, 1.5, 3.5)],
		["Cover_C4", Vector3(0, 0.75, -5), Vector3(0.3, 1.5, 3.5)],
		["Cover_NE1", Vector3(10, 0.75, 10), Vector3(5, 1.5, 0.3)],
		["Cover_NE2", Vector3(12, 0.75, 8.5), Vector3(0.3, 1.5, 2.7)],
		["Cover_SW1", Vector3(-10, 0.75, -10), Vector3(5, 1.5, 0.3)],
		["Cover_SW2", Vector3(-12, 0.75, -8.5), Vector3(0.3, 1.5, 2.7)],
		["Cover_NW1", Vector3(-10, 0.75, 10), Vector3(5, 1.5, 0.3)],
		["Cover_SE1", Vector3(10, 0.75, -10), Vector3(5, 1.5, 0.3)],
		["Cover_ME", Vector3(7, 0.75, 0), Vector3(0.3, 1.5, 5)],
		["Cover_MW", Vector3(-7, 0.75, 0), Vector3(0.3, 1.5, 5)],
	]

	for data in covers:
		var pos: Vector3 = data[1] * scale_factor
		pos.y = data[1].y
		_create_static_box(data[0], pos, data[2], mat)
		var strip := MeshInstance3D.new()
		var strip_box := BoxMesh.new()
		strip_box.size = Vector3(data[2].x + 0.05, 0.06, data[2].z + 0.05)
		strip.mesh = strip_box
		strip.material_override = glow
		strip.position = Vector3(pos.x, 1.53, pos.z)
		add_child(strip)


func _build_pillars() -> void:
	var mat := _mat(theme.cover_color * 0.9, 0.5, 0.5)
	var ring_mat := _glow_mat(theme.accent_color, 4.0)

	var scale_factor := theme.arena_size / 44.0
	var positions := [
		Vector3(6, 0, 6), Vector3(-6, 0, -6),
		Vector3(6, 0, -6), Vector3(-6, 0, 6),
		Vector3(14, 0, 0), Vector3(-14, 0, 0),
		Vector3(0, 0, 14), Vector3(0, 0, -14),
	]

	for i in range(positions.size()):
		var pos: Vector3 = positions[i] * scale_factor
		var body := StaticBody3D.new()
		body.name = "Pillar_%d" % i
		body.position = pos + Vector3(0, 2, 0)
		add_child(body)

		var mesh_inst := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.45
		cyl.bottom_radius = 0.5
		cyl.height = 4.0
		mesh_inst.mesh = cyl
		mesh_inst.material_override = mat
		body.add_child(mesh_inst)

		var col := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 0.5
		shape.height = 4.0
		col.shape = shape
		body.add_child(col)

		var ring := MeshInstance3D.new()
		var ring_mesh := TorusMesh.new()
		ring_mesh.inner_radius = 0.45
		ring_mesh.outer_radius = 0.65
		ring.mesh = ring_mesh
		ring.material_override = ring_mat
		ring.position = Vector3(pos.x, 0.05, pos.z)
		ring.rotation.x = deg_to_rad(90)
		ring.scale = Vector3(1, 1, 0.3)
		add_child(ring)


func _build_crates() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = theme.cover_color * 1.2
	mat.roughness = 0.8

	var scale_factor := theme.arena_size / 44.0
	var positions := [
		Vector3(5, 0.5, 7), Vector3(5, 1.5, 7),
		Vector3(-6, 0.5, 8), Vector3(8, 0.5, -5),
		Vector3(-8, 0.5, -7), Vector3(-4, 0.5, 14),
		Vector3(12, 0.5, 4), Vector3(-14, 0.5, -3),
	]

	for i in range(positions.size()):
		var pos: Vector3 = positions[i]
		pos.x *= scale_factor
		pos.z *= scale_factor
		_create_static_box("Crate_%d" % i, pos, Vector3(1, 1, 1), mat)


func _build_platforms() -> void:
	var mat := _mat(theme.floor_color * 1.1, 0.6, 0.4)
	var glow_edge := _glow_mat(theme.glow_color * Color(0.5, 1.0, 0.8), 3.0)

	var scale_factor := theme.arena_size / 44.0

	# Center platform
	_create_static_box("Platform_Center", Vector3(0, 0.4, 0), Vector3(6, 0.8, 6), mat)
	_add_platform_trim(Vector3(0, 0.82, 0), Vector3(6.1, 0.06, 6.1), glow_edge)

	# Elevated perches
	var ne_pos := Vector3(16 * scale_factor, 1.5, 16 * scale_factor)
	_create_static_box("Platform_NE", ne_pos, Vector3(5, 3, 5), mat)
	_add_platform_trim(Vector3(ne_pos.x, 3.02, ne_pos.z), Vector3(5.1, 0.06, 5.1), glow_edge)

	var sw_pos := Vector3(-16 * scale_factor, 1.5, -16 * scale_factor)
	_create_static_box("Platform_SW", sw_pos, Vector3(5, 3, 5), mat)
	_add_platform_trim(Vector3(sw_pos.x, 3.02, sw_pos.z), Vector3(5.1, 0.06, 5.1), glow_edge)

	# Ramps
	var ramp_mat := mat
	_create_static_box("Ramp_E", Vector3(4.5, 0.2, 0), Vector3(4, 0.15, 3), ramp_mat)
	_create_static_box("Ramp_W", Vector3(-4.5, 0.2, 0), Vector3(4, 0.15, 3), ramp_mat)
	_create_static_box("Ramp_NE", Vector3(ne_pos.x - 2, 0.75, ne_pos.z), Vector3(4, 0.15, 3), ramp_mat)
	_create_static_box("Ramp_SW", Vector3(sw_pos.x + 2, 0.75, sw_pos.z), Vector3(4, 0.15, 3), ramp_mat)

	# Void station — extra floating platforms
	if theme.has_void:
		var void_positions := [
			Vector3(8, 3, 0), Vector3(-8, 3, 0),
			Vector3(0, 3, 8), Vector3(0, 3, -8),
			Vector3(12, 5, 12), Vector3(-12, 5, -12),
		]
		for i in range(void_positions.size()):
			var vp: Vector3 = void_positions[i]
			_create_static_box("VoidPlat_%d" % i, vp, Vector3(4, 0.4, 4), mat)
			_add_platform_trim(Vector3(vp.x, vp.y + 0.22, vp.z), Vector3(4.1, 0.06, 4.1), glow_edge)


func _build_lights() -> void:
	var light_positions := [
		Vector3(0, 8, 0),
		Vector3(10, 6, 10), Vector3(-10, 6, -10),
		Vector3(10, 6, -10), Vector3(-10, 6, 10),
		Vector3(half_size * 0.7, 8, half_size * 0.7),
		Vector3(-half_size * 0.7, 8, -half_size * 0.7),
	]

	for i in range(light_positions.size()):
		var omni := OmniLight3D.new()
		omni.name = "Light_%d" % i
		omni.position = light_positions[i]
		omni.omni_range = 18.0
		omni.light_energy = 1.5
		omni.light_color = theme.sun_color
		omni.shadow_enabled = true
		add_child(omni)

	var accent_lights := [
		[Vector3(0, 1.5, 0), theme.accent_color, 8.0],
		[Vector3(half_size * 0.7, 4.5, half_size * 0.7), theme.accent_color * Color(1.5, 0.5, 0.2), 6.0],
		[Vector3(-half_size * 0.7, 4.5, -half_size * 0.7), theme.accent_color * Color(0.2, 1.5, 0.5), 6.0],
	]

	for data in accent_lights:
		var accent := OmniLight3D.new()
		accent.position = data[0]
		accent.light_color = data[1]
		accent.omni_range = data[2]
		accent.light_energy = 2.0
		add_child(accent)


func _build_pickups() -> void:
	var health_scene := load("res://scenes/pickups/health_pickup.tscn") as PackedScene
	var ammo_scene := load("res://scenes/pickups/ammo_pickup.tscn") as PackedScene

	if not health_scene or not ammo_scene:
		return

	var s := half_size * 0.45

	var health_positions := [
		Vector3(-s, 0, 0),
		Vector3(s * 0.6, 0, s),
		Vector3(-s * 0.4, 0, -s),
	]
	for pos in health_positions:
		var hp = health_scene.instantiate()
		add_child(hp)
		hp.global_position = pos

	var ammo_positions := [
		Vector3(s, 0, 0),
		Vector3(-s * 0.6, 0, -s),
		Vector3(s * 0.4, 0, s),
	]
	for pos in ammo_positions:
		var ammo = ammo_scene.instantiate()
		add_child(ammo)
		ammo.global_position = pos


func _build_lava_hazards() -> void:
	# Lava pits — glowing red damage zones
	var lava_positions := [
		Vector3(-8, -0.05, 8), Vector3(8, -0.05, -8),
		Vector3(-12, -0.05, -4), Vector3(12, -0.05, 4),
		Vector3(0, -0.05, 12), Vector3(0, -0.05, -12),
	]

	for i in range(lava_positions.size()):
		# Visual
		var lava_mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(4, 0.1, 4)
		lava_mesh.mesh = box
		var lava_mat := StandardMaterial3D.new()
		lava_mat.albedo_color = Color(1.0, 0.2, 0.0, 0.9)
		lava_mat.emission_enabled = true
		lava_mat.emission = Color(1.0, 0.15, 0.0)
		lava_mat.emission_energy_multiplier = 6.0
		lava_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		lava_mesh.material_override = lava_mat
		lava_mesh.position = lava_positions[i]
		add_child(lava_mesh)

		# Light
		var lava_light := OmniLight3D.new()
		lava_light.light_color = Color(1.0, 0.3, 0.0)
		lava_light.light_energy = 3.0
		lava_light.omni_range = 5.0
		lava_light.position = lava_positions[i] + Vector3(0, 0.5, 0)
		add_child(lava_light)

		# Damage zone (Area3D)
		var area := Area3D.new()
		area.name = "LavaZone_%d" % i
		area.position = lava_positions[i] + Vector3(0, 0.5, 0)
		area.collision_layer = 0
		area.collision_mask = 6  # Player + Enemy
		add_child(area)

		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(4, 1, 4)
		col.shape = shape
		area.add_child(col)

		# Damage timer
		var timer := Timer.new()
		timer.wait_time = 0.5
		timer.autostart = true
		area.add_child(timer)
		timer.timeout.connect(_lava_damage.bind(area))


func _lava_damage(area: Area3D) -> void:
	for body in area.get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(15.0, null)


func _build_void_kill_zone() -> void:
	# Kill zone below the void platforms
	var kill_area := Area3D.new()
	kill_area.name = "VoidKillZone"
	kill_area.position = Vector3(0, -5, 0)
	kill_area.collision_layer = 0
	kill_area.collision_mask = 6
	add_child(kill_area)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(100, 1, 100)
	col.shape = shape
	kill_area.add_child(col)

	kill_area.body_entered.connect(_on_void_death)


func _on_void_death(body: Node3D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(9999.0, null)


# --- Material helpers ---

func _mat(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	return mat


func _glow_mat(color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	return mat


func _add_platform_trim(pos: Vector3, s: Vector3, mat: StandardMaterial3D) -> void:
	var trim := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = s
	trim.mesh = box
	trim.material_override = mat
	trim.position = pos
	add_child(trim)


func _create_static_box(obj_name: String, pos: Vector3, box_size: Vector3, mat: StandardMaterial3D) -> void:
	var body := StaticBody3D.new()
	body.name = obj_name
	body.position = pos
	add_child(body)

	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = box_size
	mesh_inst.mesh = box
	mesh_inst.material_override = mat
	body.add_child(mesh_inst)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box_size
	col.shape = shape
	body.add_child(col)
