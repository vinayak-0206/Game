extends Control

## Pause menu with resume, restart, settings, quit

var is_paused := false
var settings_visible := false

# Settings
var sens_slider: HSlider
var fov_slider: HSlider
var settings_panel: VBoxContainer


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_load_settings()


func _build_ui() -> void:
	# Dark overlay
	var bg := ColorRect.new()
	bg.name = "BG"
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# Center container
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 15)
	vbox.custom_minimum_size = Vector2(300, 0)
	center.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.modulate = Color(0.8, 0.8, 1.0)
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	# Buttons
	_add_button(vbox, "RESUME", _on_resume)
	_add_button(vbox, "RESTART", _on_restart)
	_add_button(vbox, "SETTINGS", _on_settings_toggle)
	_add_button(vbox, "QUIT", _on_quit)

	# Settings panel (hidden by default)
	settings_panel = VBoxContainer.new()
	settings_panel.name = "SettingsPanel"
	settings_panel.visible = false
	settings_panel.add_theme_constant_override("separation", 10)
	vbox.add_child(settings_panel)

	# Sensitivity
	var sens_label := Label.new()
	sens_label.text = "Mouse Sensitivity"
	sens_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sens_label.add_theme_font_size_override("font_size", 16)
	settings_panel.add_child(sens_label)

	sens_slider = HSlider.new()
	sens_slider.min_value = 0.0005
	sens_slider.max_value = 0.005
	sens_slider.step = 0.0001
	sens_slider.value = 0.0015
	sens_slider.custom_minimum_size = Vector2(250, 20)
	sens_slider.value_changed.connect(_on_sens_changed)
	settings_panel.add_child(sens_slider)

	# FOV
	var fov_label := Label.new()
	fov_label.text = "Field of View"
	fov_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fov_label.add_theme_font_size_override("font_size", 16)
	settings_panel.add_child(fov_label)

	fov_slider = HSlider.new()
	fov_slider.min_value = 60
	fov_slider.max_value = 110
	fov_slider.step = 1
	fov_slider.value = 75
	fov_slider.custom_minimum_size = Vector2(250, 20)
	fov_slider.value_changed.connect(_on_fov_changed)
	settings_panel.add_child(fov_slider)


func _add_button(parent: VBoxContainer, text: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(250, 45)
	btn.add_theme_font_size_override("font_size", 22)
	btn.pressed.connect(callback)
	parent.add_child(btn)


func toggle() -> void:
	if is_paused:
		_unpause()
	else:
		_pause()


func _pause() -> void:
	is_paused = true
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _unpause() -> void:
	is_paused = false
	visible = false
	settings_panel.visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _on_resume() -> void:
	_unpause()


func _on_restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_settings_toggle() -> void:
	settings_panel.visible = not settings_panel.visible


func _on_quit() -> void:
	get_tree().paused = false
	var menu_path := "res://scenes/ui/main_menu.tscn"
	if ResourceLoader.exists(menu_path):
		get_tree().change_scene_to_file(menu_path)
	else:
		get_tree().quit()


func _on_sens_changed(value: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and "mouse_sensitivity" in player:
		player.mouse_sensitivity = value
	_save_settings()


func _on_fov_changed(value: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		var cam = player.get_node_or_null("CameraPivot/SpringArm3D/Camera3D")
		if cam:
			cam.fov = value
	_save_settings()


func _save_settings() -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs:
		gs.sensitivity = sens_slider.value
		gs.fov = fov_slider.value
		gs.save_settings()
	else:
		var config := ConfigFile.new()
		config.set_value("controls", "sensitivity", sens_slider.value)
		config.set_value("controls", "fov", fov_slider.value)
		config.save("user://settings.cfg")


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		if sens_slider:
			sens_slider.value = config.get_value("controls", "sensitivity", 0.0015)
		if fov_slider:
			fov_slider.value = config.get_value("controls", "fov", 75.0)
