extends Control

## Between-wave upgrade shop — spend score points on weapon upgrades and perks

var is_open := false
var available_upgrades: Array[Dictionary] = []
var btn_container: VBoxContainer
var points_label: Label
var title_label: Label
var timer_label: Label
var countdown := 10.0
var countdown_active := false

signal shop_closed


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func _build_ui() -> void:
	# Dark overlay
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# Center panel
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -280
	panel.offset_top = -250
	panel.offset_right = 280
	panel.offset_bottom = 250
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Title
	title_label = Label.new()
	title_label.text = "WAVE CLEARED — UPGRADES"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.modulate = Color(1.0, 0.8, 0.0)
	vbox.add_child(title_label)

	# Points display
	points_label = Label.new()
	points_label.text = "POINTS: 0"
	points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	points_label.add_theme_font_size_override("font_size", 22)
	points_label.modulate = Color(0.3, 1.0, 0.5)
	vbox.add_child(points_label)

	# Timer
	timer_label = Label.new()
	timer_label.text = "Next wave in: 10s"
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 16)
	timer_label.modulate = Color(0.7, 0.7, 0.8)
	vbox.add_child(timer_label)

	# Upgrade buttons container
	btn_container = VBoxContainer.new()
	btn_container.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_container)

	# Skip button
	var skip_btn := Button.new()
	skip_btn.text = "SKIP (SPACE)"
	skip_btn.custom_minimum_size = Vector2(400, 40)
	skip_btn.add_theme_font_size_override("font_size", 18)
	skip_btn.pressed.connect(_close_shop)
	vbox.add_child(skip_btn)


func open_shop(current_score: int, wave: int) -> void:
	is_open = true
	visible = true
	countdown = 10.0 + wave * 0.5  # More time on later waves
	countdown_active = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	points_label.text = "POINTS: %d" % current_score
	title_label.text = "WAVE %d CLEARED — UPGRADES" % wave

	_generate_upgrades(current_score, wave)
	_refresh_buttons(current_score)


func _generate_upgrades(score: int, wave: int) -> void:
	available_upgrades.clear()

	# Pool of all possible upgrades
	var all_upgrades: Array[Dictionary] = [
		{"name": "Damage +15%", "cost": 200, "type": "damage_up", "desc": "All weapons deal 15% more damage"},
		{"name": "Fire Rate +10%", "cost": 250, "type": "fire_rate_up", "desc": "All weapons fire 10% faster"},
		{"name": "Reload Speed +20%", "cost": 150, "type": "reload_up", "desc": "Reload 20% faster"},
		{"name": "Max Ammo +50%", "cost": 300, "type": "ammo_up", "desc": "+50% max ammo capacity"},
		{"name": "Health +25", "cost": 100, "type": "heal", "desc": "Restore 25 HP"},
		{"name": "Max HP +20", "cost": 350, "type": "max_hp_up", "desc": "Permanently increase max HP by 20"},
		{"name": "Sprint Speed +15%", "cost": 200, "type": "speed_up", "desc": "Sprint 15% faster"},
		{"name": "Grenade +1", "cost": 150, "type": "grenade", "desc": "Get 1 grenade"},
		{"name": "Armor Plating", "cost": 400, "type": "armor", "desc": "Take 15% less damage for this run"},
		{"name": "Vampire Rounds", "cost": 500, "type": "lifesteal", "desc": "Heal 5% of damage dealt"},
	]

	# Shuffle and pick 4
	all_upgrades.shuffle()
	var count := mini(4, all_upgrades.size())
	for i in range(count):
		available_upgrades.append(all_upgrades[i])


func _refresh_buttons(current_score: int) -> void:
	for child in btn_container.get_children():
		child.queue_free()

	for i in range(available_upgrades.size()):
		var upgrade: Dictionary = available_upgrades[i]
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)

		var btn := Button.new()
		var cost: int = int(upgrade.cost)
		btn.text = "%s — %d pts" % [str(upgrade.name), cost]
		btn.custom_minimum_size = Vector2(400, 45)
		btn.add_theme_font_size_override("font_size", 17)
		btn.disabled = current_score < cost
		btn.pressed.connect(_buy_upgrade.bind(i))

		if current_score < cost:
			btn.modulate = Color(0.5, 0.5, 0.5)
		else:
			btn.modulate = Color(1, 1, 1)

		hbox.add_child(btn)
		btn_container.add_child(hbox)


func _buy_upgrade(index: int) -> void:
	if index >= available_upgrades.size():
		return

	var upgrade: Dictionary = available_upgrades[index]
	var cost: int = int(upgrade.cost)

	# Get game manager to deduct score
	var gm = get_tree().get_first_node_in_group("game_manager")
	if not gm or gm.score < cost:
		return

	gm.score -= cost
	points_label.text = "POINTS: %d" % gm.score

	# Apply upgrade
	_apply_upgrade(str(upgrade.type))

	# Remove purchased upgrade and refresh
	available_upgrades.remove_at(index)
	_refresh_buttons(gm.score)

	# Audio feedback
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_pickup"):
		am.play_pickup()


func _apply_upgrade(upgrade_type: String) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	match upgrade_type:
		"damage_up":
			# Boost all weapon damage by 15%
			if "weapons" in player:
				for w in player.weapons:
					if "damage" in w:
						w.damage *= 1.15
		"fire_rate_up":
			if "weapons" in player:
				for w in player.weapons:
					if "fire_rate" in w:
						w.fire_rate *= 0.9  # Lower = faster
		"reload_up":
			if "weapons" in player:
				for w in player.weapons:
					if "reload_time" in w:
						w.reload_time *= 0.8
		"ammo_up":
			if "weapons" in player:
				for w in player.weapons:
					if "max_ammo" in w:
						w.max_ammo = int(w.max_ammo * 1.5)
						w.max_reserve = int(w.max_reserve * 1.5)
		"heal":
			if player.has_method("heal"):
				player.heal(25.0)
		"max_hp_up":
			if "max_health" in player:
				player.max_health += 20.0
				player.current_health = minf(player.current_health + 20.0, player.max_health)
				player.health_changed.emit(player.current_health, player.max_health)
		"speed_up":
			if "sprint_speed" in player:
				player.sprint_speed *= 1.15
		"grenade":
			if player.has_method("add_grenades"):
				player.add_grenades(1)
		"armor":
			# Store on player for damage reduction
			if not "damage_reduction" in player:
				player.set_meta("damage_reduction", 0.0)
			var current_dr: float = player.get_meta("damage_reduction", 0.0)
			player.set_meta("damage_reduction", minf(current_dr + 0.15, 0.5))
		"lifesteal":
			player.set_meta("lifesteal", 0.05)


func _process(delta: float) -> void:
	if not is_open:
		return

	if countdown_active:
		countdown -= delta
		timer_label.text = "Next wave in: %ds" % maxi(int(countdown), 0)
		if countdown <= 0:
			_close_shop()


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_close_shop()


func _close_shop() -> void:
	is_open = false
	visible = false
	countdown_active = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	shop_closed.emit()
