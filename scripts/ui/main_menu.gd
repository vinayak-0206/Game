extends Control

## Main menu — title, play, map select, settings, quit

var maps: Array[MapData] = []
var selected_index := 0
var map_buttons: Array[Button] = []
var map_desc_label: Label
var main_buttons: VBoxContainer
var map_select_panel: VBoxContainer
var settings_panel: VBoxContainer
var scores_panel: VBoxContainer
var is_map_select := false
var is_settings := false

var sens_slider: HSlider
var fov_slider: HSlider
var diff_button: Button
var current_difficulty := 1  # 0=Easy, 1=Normal, 2=Hard


func _ready() -> void:
	maps = MapData.get_all_maps()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build_ui()
	_load_settings()


func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.06)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Animated accent lines
	for i in range(5):
		var line := ColorRect.new()
		line.color = Color(0.0, 0.4 + i * 0.1, 0.8, 0.15)
		line.set_anchors_preset(Control.PRESET_FULL_RECT)
		line.offset_left = -200
		line.offset_right = -200 + 3
		line.offset_top = 100 + i * 120
		line.offset_bottom = 103 + i * 120
		add_child(line)
		var tween := line.create_tween().set_loops()
		tween.tween_property(line, "offset_left", 2200.0, 4.0 + i * 0.5)
		tween.tween_property(line, "offset_left", -200.0, 0.0)

	# Title
	var title := Label.new()
	title.text = "SHOOTER ARENA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_top = 80
	title.offset_left = -400
	title.offset_right = 400
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(title)

	# Title glow animation
	var glow_tween := title.create_tween().set_loops()
	glow_tween.tween_property(title, "modulate", Color(0.0, 0.8, 1.0), 2.0)
	glow_tween.tween_property(title, "modulate", Color(1.0, 1.0, 1.0), 2.0)

	# Subtitle
	var subtitle := Label.new()
	subtitle.text = "WAVE-BASED SURVIVAL SHOOTER"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.modulate = Color(0.5, 0.5, 0.6)
	subtitle.set_anchors_preset(Control.PRESET_CENTER_TOP)
	subtitle.offset_top = 170
	subtitle.offset_left = -300
	subtitle.offset_right = 300
	subtitle.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(subtitle)

	# Main buttons container
	main_buttons = VBoxContainer.new()
	main_buttons.name = "MainButtons"
	main_buttons.set_anchors_preset(Control.PRESET_CENTER)
	main_buttons.offset_left = -150
	main_buttons.offset_top = -80
	main_buttons.offset_right = 150
	main_buttons.offset_bottom = 150
	main_buttons.add_theme_constant_override("separation", 12)
	add_child(main_buttons)

	_add_menu_button(main_buttons, "PLAY", _on_play)
	_add_menu_button(main_buttons, "SETTINGS", _on_settings)
	_add_menu_button(main_buttons, "HIGH SCORES", _on_high_scores)
	_add_menu_button(main_buttons, "QUIT", _on_quit)

	# Map selection panel (hidden)
	map_select_panel = VBoxContainer.new()
	map_select_panel.name = "MapSelectPanel"
	map_select_panel.visible = false
	map_select_panel.set_anchors_preset(Control.PRESET_CENTER)
	map_select_panel.offset_left = -200
	map_select_panel.offset_top = -150
	map_select_panel.offset_right = 200
	map_select_panel.offset_bottom = 200
	map_select_panel.add_theme_constant_override("separation", 10)
	add_child(map_select_panel)

	var select_title := Label.new()
	select_title.text = "SELECT MAP"
	select_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	select_title.add_theme_font_size_override("font_size", 32)
	map_select_panel.add_child(select_title)

	for i in range(maps.size()):
		var btn := Button.new()
		btn.text = maps[i].map_name
		btn.custom_minimum_size = Vector2(350, 50)
		btn.add_theme_font_size_override("font_size", 20)
		btn.pressed.connect(_on_map_selected.bind(i))
		map_select_panel.add_child(btn)
		map_buttons.append(btn)

	map_desc_label = Label.new()
	map_desc_label.text = ""
	map_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_desc_label.add_theme_font_size_override("font_size", 14)
	map_desc_label.modulate = Color(0.6, 0.6, 0.7)
	map_select_panel.add_child(map_desc_label)

	var back_btn := Button.new()
	back_btn.text = "BACK"
	back_btn.custom_minimum_size = Vector2(350, 40)
	back_btn.add_theme_font_size_override("font_size", 18)
	back_btn.pressed.connect(_on_back)
	map_select_panel.add_child(back_btn)

	# Settings panel (hidden)
	settings_panel = VBoxContainer.new()
	settings_panel.name = "SettingsPanel"
	settings_panel.visible = false
	settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	settings_panel.offset_left = -200
	settings_panel.offset_top = -100
	settings_panel.offset_right = 200
	settings_panel.offset_bottom = 100
	settings_panel.add_theme_constant_override("separation", 10)
	add_child(settings_panel)

	var settings_title := Label.new()
	settings_title.text = "SETTINGS"
	settings_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_title.add_theme_font_size_override("font_size", 32)
	settings_panel.add_child(settings_title)

	var sens_label := Label.new()
	sens_label.text = "Mouse Sensitivity"
	sens_label.add_theme_font_size_override("font_size", 16)
	settings_panel.add_child(sens_label)

	sens_slider = HSlider.new()
	sens_slider.min_value = 0.0005
	sens_slider.max_value = 0.005
	sens_slider.step = 0.0001
	sens_slider.value = 0.0015
	sens_slider.custom_minimum_size = Vector2(300, 20)
	settings_panel.add_child(sens_slider)

	var fov_label := Label.new()
	fov_label.text = "Field of View"
	fov_label.add_theme_font_size_override("font_size", 16)
	settings_panel.add_child(fov_label)

	fov_slider = HSlider.new()
	fov_slider.min_value = 60
	fov_slider.max_value = 110
	fov_slider.step = 1
	fov_slider.value = 75
	fov_slider.custom_minimum_size = Vector2(300, 20)
	settings_panel.add_child(fov_slider)

	var diff_label := Label.new()
	diff_label.text = "Difficulty"
	diff_label.add_theme_font_size_override("font_size", 16)
	settings_panel.add_child(diff_label)

	diff_button = Button.new()
	diff_button.text = "NORMAL"
	diff_button.custom_minimum_size = Vector2(300, 35)
	diff_button.add_theme_font_size_override("font_size", 18)
	diff_button.pressed.connect(_on_difficulty_cycle)
	settings_panel.add_child(diff_button)

	var save_btn := Button.new()
	save_btn.text = "SAVE & BACK"
	save_btn.custom_minimum_size = Vector2(300, 40)
	save_btn.add_theme_font_size_override("font_size", 18)
	save_btn.pressed.connect(_on_settings_save)
	settings_panel.add_child(save_btn)

	# High scores panel (hidden)
	scores_panel = VBoxContainer.new()
	scores_panel.name = "ScoresPanel"
	scores_panel.visible = false
	scores_panel.set_anchors_preset(Control.PRESET_CENTER)
	scores_panel.offset_left = -200
	scores_panel.offset_top = -200
	scores_panel.offset_right = 200
	scores_panel.offset_bottom = 200
	scores_panel.add_theme_constant_override("separation", 8)
	add_child(scores_panel)

	var scores_title := Label.new()
	scores_title.text = "HIGH SCORES"
	scores_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scores_title.add_theme_font_size_override("font_size", 32)
	scores_title.modulate = Color(1.0, 0.8, 0.0)
	scores_panel.add_child(scores_title)

	var scores_back := Button.new()
	scores_back.text = "BACK"
	scores_back.custom_minimum_size = Vector2(300, 40)
	scores_back.add_theme_font_size_override("font_size", 18)
	scores_back.pressed.connect(_on_back)
	scores_panel.add_child(scores_back)

	# Version
	var ver := Label.new()
	ver.text = "v1.0"
	ver.modulate = Color(0.3, 0.3, 0.4)
	ver.add_theme_font_size_override("font_size", 12)
	ver.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ver.offset_left = 20
	ver.offset_bottom = -10
	ver.offset_top = -30
	add_child(ver)


func _add_menu_button(parent: VBoxContainer, text: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(300, 55)
	btn.add_theme_font_size_override("font_size", 24)
	btn.pressed.connect(callback)
	parent.add_child(btn)


func _on_play() -> void:
	main_buttons.visible = false
	map_select_panel.visible = true


func _on_settings() -> void:
	main_buttons.visible = false
	settings_panel.visible = true


func _on_high_scores() -> void:
	# Clear old score entries (keep title + back button)
	while scores_panel.get_child_count() > 2:
		scores_panel.get_child(1).queue_free()

	# Load scores
	var scores: Array = []
	var path := "user://highscores.json"
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		if file:
			var json := JSON.new()
			if json.parse(file.get_as_text()) == OK and json.data is Array:
				scores = json.data

	if scores.size() == 0:
		var no_scores := Label.new()
		no_scores.text = "No scores yet. Play a game!"
		no_scores.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_scores.add_theme_font_size_override("font_size", 16)
		no_scores.modulate = Color(0.6, 0.6, 0.7)
		scores_panel.add_child(no_scores)
		scores_panel.move_child(no_scores, 1)
	else:
		for i in range(mini(scores.size(), 10)):
			var entry = scores[i]
			var lbl := Label.new()
			lbl.text = "#%d  Score: %d  |  Wave: %d  |  Kills: %d" % [
				i + 1,
				int(entry.get("score", 0)),
				int(entry.get("wave", 0)),
				int(entry.get("kills", 0))
			]
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 15)
			if i == 0:
				lbl.modulate = Color(1.0, 0.8, 0.0)
			elif i <= 2:
				lbl.modulate = Color(0.8, 0.8, 0.9)
			else:
				lbl.modulate = Color(0.6, 0.6, 0.7)
			scores_panel.add_child(lbl)
			scores_panel.move_child(lbl, i + 1)

	main_buttons.visible = false
	scores_panel.visible = true


func _on_quit() -> void:
	get_tree().quit()


func _on_map_selected(index: int) -> void:
	selected_index = index
	GameState.selected_map = maps[index]
	GameState.selected_map_index = index

	# Fade and start
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fade)

	var tween := fade.create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.5)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/levels/arena.tscn"))


func _on_back() -> void:
	map_select_panel.visible = false
	settings_panel.visible = false
	scores_panel.visible = false
	main_buttons.visible = true


func _on_difficulty_cycle() -> void:
	current_difficulty = (current_difficulty + 1) % 3
	var names := ["EASY", "NORMAL", "HARD"]
	diff_button.text = names[current_difficulty]


func _on_settings_save() -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs:
		gs.sensitivity = sens_slider.value
		gs.fov = fov_slider.value
		gs.difficulty = current_difficulty
		gs.save_settings()
	else:
		var config := ConfigFile.new()
		config.set_value("controls", "sensitivity", sens_slider.value)
		config.set_value("controls", "fov", fov_slider.value)
		config.save("user://settings.cfg")
	settings_panel.visible = false
	main_buttons.visible = true


func _load_settings() -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs:
		if sens_slider:
			sens_slider.value = gs.sensitivity
		if fov_slider:
			fov_slider.value = gs.fov
		current_difficulty = gs.difficulty
		if diff_button:
			var names := ["EASY", "NORMAL", "HARD"]
			diff_button.text = names[current_difficulty]
	else:
		var config := ConfigFile.new()
		if config.load("user://settings.cfg") == OK:
			if sens_slider:
				sens_slider.value = config.get_value("controls", "sensitivity", 0.0015)
			if fov_slider:
				fov_slider.value = config.get_value("controls", "fov", 75.0)
