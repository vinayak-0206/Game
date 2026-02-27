extends Control

## Full HUD — health, ammo, score, wave, combo, minimap, stamina, grenades, kill streaks

@onready var health_bar: ProgressBar = get_node_or_null("MarginContainer/VBoxContainer/HealthBar")
@onready var health_label: Label = get_node_or_null("MarginContainer/VBoxContainer/HealthLabel")
@onready var ammo_label: Label = get_node_or_null("AmmoContainer/AmmoLabel")
@onready var score_label: Label = get_node_or_null("ScoreContainer/ScoreLabel")
@onready var timer_label: Label = get_node_or_null("TimerContainer/TimerLabel")
@onready var kill_label: Label = get_node_or_null("ScoreContainer/KillLabel")
@onready var weapon_label: Label = get_node_or_null("AmmoContainer/WeaponLabel")
@onready var wave_label: Label = get_node_or_null("WaveContainer/WaveLabel")
@onready var combo_label: Label = get_node_or_null("ComboContainer/ComboLabel")
@onready var kill_popup_container: VBoxContainer = get_node_or_null("KillPopups")
@onready var damage_overlay: ColorRect = get_node_or_null("DamageOverlay")

var player: CharacterBody3D

# Dynamically created UI
var stamina_bar: ProgressBar
var grenade_label: Label
var streak_label: Label
var minimap_control: Control
var controls_hint: VBoxContainer
var upgrade_shop: Control
var crosshair: DynamicCrosshair
var damage_pp: DamagePostProcess
var boss_health_bar: ProgressBar
var boss_health_bg: Panel
var boss_name_label: Label
var damage_direction_indicator: Control
var last_attacker_pos := Vector3.ZERO
var damage_dir_timer := 0.0
var health_tween: Tween = null
var low_health_pulse_tween: Tween = null


func _ready() -> void:
	await get_tree().process_frame
	player = get_parent() if get_parent() is CharacterBody3D else null
	if not player:
		player = get_tree().get_first_node_in_group("player")

	if player:
		player.health_changed.connect(_on_health_changed)
		player.ammo_changed.connect(_on_ammo_changed)
		player.weapon_switched.connect(_on_weapon_switched)
		if player.has_signal("stamina_changed"):
			player.stamina_changed.connect(_on_stamina_changed)
		if player.has_signal("grenade_count_changed"):
			player.grenade_count_changed.connect(_on_grenade_count_changed)

	var gm = get_tree().get_first_node_in_group("game_manager")
	if gm:
		gm.score_updated.connect(_on_score_updated)
		gm.kill_registered.connect(_on_kill_registered)
		gm.match_timer_updated.connect(_on_timer_updated)
		gm.wave_started.connect(_on_wave_started)
		gm.wave_cleared.connect(_on_wave_cleared)
		gm.combo_updated.connect(_on_combo_updated)

	_build_stamina_bar()
	_build_grenade_display()
	_build_streak_label()
	_build_minimap()
	_build_pause_menu()
	_build_game_over_screen()
	_build_controls_hint()
	_build_upgrade_shop()
	_build_crosshair()
	_build_damage_post_process()
	_build_boss_health_bar()
	_build_damage_direction_indicator()


func _build_stamina_bar() -> void:
	# Below health bar
	var container = get_node_or_null("MarginContainer/VBoxContainer")
	if not container:
		return
	stamina_bar = ProgressBar.new()
	stamina_bar.name = "StaminaBar"
	stamina_bar.custom_minimum_size = Vector2(280, 8)
	stamina_bar.max_value = 100.0
	stamina_bar.value = 100.0
	stamina_bar.show_percentage = false
	stamina_bar.modulate = Color(0.2, 0.6, 1.0)
	container.add_child(stamina_bar)


func _build_grenade_display() -> void:
	var ammo_container = get_node_or_null("AmmoContainer")
	if not ammo_container:
		return
	grenade_label = Label.new()
	grenade_label.name = "GrenadeLabel"
	grenade_label.text = "GRENADES: 3"
	grenade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grenade_label.add_theme_font_size_override("font_size", 14)
	grenade_label.modulate = Color(1.0, 0.5, 0.0)
	ammo_container.add_child(grenade_label)


func _build_streak_label() -> void:
	streak_label = Label.new()
	streak_label.name = "StreakLabel"
	streak_label.text = ""
	streak_label.visible = false
	streak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	streak_label.add_theme_font_size_override("font_size", 36)
	streak_label.set_anchors_preset(Control.PRESET_CENTER)
	streak_label.offset_left = -200
	streak_label.offset_top = -80
	streak_label.offset_right = 200
	streak_label.offset_bottom = -40
	streak_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(streak_label)


func _build_minimap() -> void:
	var minimap_script := load("res://scripts/ui/minimap.gd")
	if minimap_script:
		minimap_control = Control.new()
		minimap_control.set_script(minimap_script)
		minimap_control.name = "Minimap"
		add_child(minimap_control)


func _build_pause_menu() -> void:
	var pause_script := load("res://scripts/ui/pause_menu.gd")
	if pause_script:
		var pause := Control.new()
		pause.set_script(pause_script)
		pause.name = "PauseMenu"
		pause.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(pause)


func _build_game_over_screen() -> void:
	var go_script := load("res://scripts/ui/game_over_screen.gd")
	if go_script:
		var go := Control.new()
		go.set_script(go_script)
		go.name = "GameOverScreen"
		go.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(go)


func _build_controls_hint() -> void:
	controls_hint = VBoxContainer.new()
	controls_hint.name = "ControlsHint"
	controls_hint.set_anchors_preset(Control.PRESET_CENTER)
	controls_hint.offset_left = -140
	controls_hint.offset_top = 80
	controls_hint.offset_right = 140
	controls_hint.offset_bottom = 300
	controls_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH

	var hints := [
		"WASD — Move",
		"Mouse — Look / Aim",
		"Left Click — Shoot",
		"Right Click — Aim Down Sights",
		"Shift — Sprint",
		"Ctrl — Dash",
		"R — Reload",
		"Q — Switch Weapon",
		"G — Throw Grenade",
		"Esc — Pause",
	]
	for h in hints:
		var lbl := Label.new()
		lbl.text = h
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.modulate = Color(1, 1, 1, 0.7)
		controls_hint.add_child(lbl)

	add_child(controls_hint)

	# Fade out after 15 seconds
	var tween := create_tween()
	tween.tween_interval(12.0)
	tween.tween_property(controls_hint, "modulate:a", 0.0, 3.0)
	tween.tween_callback(controls_hint.queue_free)


func _build_upgrade_shop() -> void:
	var shop_script := load("res://scripts/ui/upgrade_shop.gd")
	if shop_script:
		upgrade_shop = Control.new()
		upgrade_shop.set_script(shop_script)
		upgrade_shop.name = "UpgradeShop"
		upgrade_shop.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(upgrade_shop)


func _build_crosshair() -> void:
	crosshair = DynamicCrosshair.new()
	crosshair.name = "DynamicCrosshair"
	add_child(crosshair)


func _build_damage_post_process() -> void:
	damage_pp = DamagePostProcess.new()
	damage_pp.name = "DamagePostProcess"
	add_child(damage_pp)


func _build_boss_health_bar() -> void:
	boss_health_bg = Panel.new()
	boss_health_bg.name = "BossHealthBG"
	boss_health_bg.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_health_bg.offset_left = -300
	boss_health_bg.offset_top = 20
	boss_health_bg.offset_right = 300
	boss_health_bg.offset_bottom = 60
	boss_health_bg.visible = false
	add_child(boss_health_bg)

	boss_name_label = Label.new()
	boss_name_label.text = "BOSS"
	boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name_label.add_theme_font_size_override("font_size", 14)
	boss_name_label.modulate = Color(1.0, 0.3, 0.2)
	boss_name_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_name_label.offset_left = -100
	boss_name_label.offset_top = 4
	boss_name_label.offset_right = 100
	boss_name_label.offset_bottom = 20
	boss_health_bg.add_child(boss_name_label)

	boss_health_bar = ProgressBar.new()
	boss_health_bar.name = "BossHealthBar"
	boss_health_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	boss_health_bar.offset_left = 10
	boss_health_bar.offset_top = 22
	boss_health_bar.offset_right = -10
	boss_health_bar.offset_bottom = -4
	boss_health_bar.max_value = 100.0
	boss_health_bar.value = 100.0
	boss_health_bar.show_percentage = false
	boss_health_bar.modulate = Color(1.0, 0.15, 0.1)
	boss_health_bg.add_child(boss_health_bar)


func _build_damage_direction_indicator() -> void:
	damage_direction_indicator = Control.new()
	damage_direction_indicator.name = "DamageDirection"
	damage_direction_indicator.set_anchors_preset(Control.PRESET_FULL_RECT)
	damage_direction_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_direction_indicator.visible = false
	add_child(damage_direction_indicator)


func show_boss_health(boss_name: String, current_hp: float, max_hp: float) -> void:
	if boss_health_bg:
		boss_health_bg.visible = true
	if boss_name_label:
		boss_name_label.text = boss_name
	if boss_health_bar:
		boss_health_bar.max_value = max_hp
		boss_health_bar.value = current_hp


func update_boss_health(current_hp: float) -> void:
	if boss_health_bar:
		boss_health_bar.value = current_hp


func hide_boss_health() -> void:
	if boss_health_bg:
		boss_health_bg.visible = false


func show_hit_marker() -> void:
	if crosshair:
		crosshair.show_hit_marker()


func show_kill_crosshair_marker() -> void:
	if crosshair:
		crosshair.show_kill_marker()


func show_damage_direction(attacker_pos: Vector3) -> void:
	last_attacker_pos = attacker_pos
	damage_dir_timer = 1.0


func show_upgrade_shop(score: int, wave: int) -> void:
	if upgrade_shop and upgrade_shop.has_method("open_shop"):
		upgrade_shop.open_shop(score, wave)


func _process(delta: float) -> void:
	# Chromatic aberration damage shader (replaces flat overlay)
	if player:
		var flash: float = player.damage_flash if "damage_flash" in player else 0.0
		if damage_pp:
			damage_pp.damage_intensity = flash
		# Hide old overlay if present
		if damage_overlay:
			damage_overlay.visible = false

		# Update crosshair spread from current weapon
		if crosshair and "current_weapon" in player and player.current_weapon:
			var wep = player.current_weapon
			if "current_spread" in wep and "spread_max" in wep:
				crosshair.set_spread(wep.current_spread, wep.spread_max)

	# Damage direction indicator
	if damage_dir_timer > 0:
		damage_dir_timer -= delta
		if damage_direction_indicator:
			damage_direction_indicator.visible = damage_dir_timer > 0
			damage_direction_indicator.queue_redraw()


func _on_health_changed(current: float, max_hp: float) -> void:
	if health_bar:
		health_bar.max_value = max_hp
		# Smooth health bar transition (tween instead of snap)
		if health_tween and health_tween.is_valid():
			health_tween.kill()
		health_tween = create_tween()
		health_tween.tween_property(health_bar, "value", current, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

		var pct := current / max_hp
		if pct > 0.6:
			health_bar.modulate = Color(0.2, 1.0, 0.4)
		elif pct > 0.3:
			health_bar.modulate = Color(1.0, 0.8, 0.1)
		else:
			health_bar.modulate = Color(1.0, 0.15, 0.1)

		# Low health pulse effect
		if pct <= 0.25 and pct > 0:
			if not low_health_pulse_tween or not low_health_pulse_tween.is_valid():
				low_health_pulse_tween = create_tween().set_loops()
				low_health_pulse_tween.tween_property(health_bar, "modulate:a", 0.4, 0.4)
				low_health_pulse_tween.tween_property(health_bar, "modulate:a", 1.0, 0.4)
		else:
			if low_health_pulse_tween and low_health_pulse_tween.is_valid():
				low_health_pulse_tween.kill()
				low_health_pulse_tween = null
			health_bar.modulate.a = 1.0

	if health_label:
		health_label.text = "%d" % int(current)


func _on_ammo_changed(current: int, reserve: int) -> void:
	if ammo_label:
		ammo_label.text = "%d / %d" % [current, reserve]
		if current <= 5:
			ammo_label.modulate = Color(1, 0.3, 0.3)
		else:
			ammo_label.modulate = Color(1, 1, 1)


func _on_weapon_switched(wname: String) -> void:
	if weapon_label:
		weapon_label.text = wname


func _on_score_updated(new_score: int) -> void:
	if score_label:
		score_label.text = "SCORE  %d" % new_score


func _on_kill_registered(total_kills: int) -> void:
	if kill_label:
		kill_label.text = "KILLS  %d" % total_kills


func _on_timer_updated(time: float) -> void:
	if timer_label:
		var minutes := int(time) / 60
		var seconds := int(time) % 60
		timer_label.text = "%d:%02d" % [minutes, seconds]


func _on_wave_started(wave_num: int) -> void:
	if wave_label:
		wave_label.text = "WAVE %d" % wave_num
		wave_label.modulate = Color(1, 0.8, 0, 1)
		wave_label.scale = Vector2(1.5, 1.5)
		wave_label.pivot_offset = wave_label.size / 2
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(wave_label, "scale", Vector2(1, 1), 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.tween_property(wave_label, "modulate", Color(1, 1, 1, 1), 1.5)


func _on_wave_cleared(wave_num: int) -> void:
	if wave_label:
		wave_label.text = "WAVE %d CLEARED!" % wave_num
		wave_label.modulate = Color(0, 1, 0.5, 1)
		wave_label.scale = Vector2(1.3, 1.3)
		wave_label.pivot_offset = wave_label.size / 2
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(wave_label, "scale", Vector2(1, 1), 0.3).set_ease(Tween.EASE_OUT)
		tween.tween_property(wave_label, "modulate", Color(1, 1, 1, 1), 2.0)


func _on_combo_updated(combo_count: int, multiplier: float) -> void:
	if combo_label:
		if combo_count > 1:
			combo_label.text = "x%d COMBO (%.1fx)" % [combo_count, multiplier]
			combo_label.modulate = Color(1, 0.8, 0)
			combo_label.visible = true
			var tween := create_tween()
			tween.tween_property(combo_label, "scale", Vector2(1.3, 1.3), 0.05)
			tween.tween_property(combo_label, "scale", Vector2(1, 1), 0.15)
		else:
			combo_label.visible = false


func _on_stamina_changed(current: float, max_val: float) -> void:
	if stamina_bar:
		stamina_bar.max_value = max_val
		stamina_bar.value = current
		var pct := current / max_val
		if pct > 0.5:
			stamina_bar.modulate = Color(0.2, 0.6, 1.0)
		elif pct > 0.2:
			stamina_bar.modulate = Color(1.0, 0.8, 0.0)
		else:
			stamina_bar.modulate = Color(1.0, 0.2, 0.2)


func _on_grenade_count_changed(count: int) -> void:
	if grenade_label:
		grenade_label.text = "GRENADES: %d" % count
		if count <= 0:
			grenade_label.modulate = Color(0.5, 0.3, 0.3)
		else:
			grenade_label.modulate = Color(1.0, 0.5, 0.0)


func show_streak(text: String) -> void:
	if not streak_label:
		return
	streak_label.text = text
	streak_label.visible = true
	streak_label.modulate = Color(1.0, 0.3, 0.0, 1.0)
	streak_label.scale = Vector2(0.5, 0.5)

	var tween := create_tween()
	tween.tween_property(streak_label, "scale", Vector2(1.2, 1.2), 0.15)
	tween.tween_property(streak_label, "scale", Vector2(1.0, 1.0), 0.1)
	tween.tween_interval(1.5)
	tween.tween_property(streak_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): streak_label.visible = false)


func show_kill_popup(points: int, combo_count: int) -> void:
	if not kill_popup_container:
		return

	var popup := Label.new()
	popup.text = "+%d" % points
	if combo_count > 2:
		popup.text += " (x%d)" % combo_count

	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.add_theme_font_size_override("font_size", 22)

	if combo_count >= 5:
		popup.modulate = Color(1, 0.2, 0.8)
	elif combo_count >= 3:
		popup.modulate = Color(1, 0.8, 0)
	else:
		popup.modulate = Color(1, 1, 1)

	kill_popup_container.add_child(popup)

	var tween := popup.create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "modulate:a", 0.0, 1.5)
	tween.tween_property(popup, "position:y", popup.position.y - 30, 1.5)
	tween.chain().tween_callback(popup.queue_free)


func show_game_over(score_val: int, wave_val: int, kills_val: int, best_combo: int) -> void:
	var go = get_node_or_null("GameOverScreen")
	if go and go.has_method("show_game_over"):
		go.show_game_over(score_val, wave_val, kills_val, best_combo)
