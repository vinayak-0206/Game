extends Control

## Game Over screen — shows final stats, restart/quit options

var final_score := 0
var final_wave := 0
var final_kills := 0
var final_combo := 0
var best_label: Label

@onready var title_label: Label = get_node_or_null("Panel/VBox/TitleLabel")
@onready var score_label: Label = get_node_or_null("Panel/VBox/ScoreLabel")
@onready var stats_label: Label = get_node_or_null("Panel/VBox/StatsLabel")
@onready var hint_label: Label = get_node_or_null("Panel/VBox/HintLabel")


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func _build_ui() -> void:
	# Full screen dark overlay
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# Center panel
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -250
	panel.offset_top = -200
	panel.offset_right = 250
	panel.offset_bottom = 200
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)

	# Title
	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "GAME OVER"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.modulate = Color(1.0, 0.2, 0.2)
	vbox.add_child(title_label)

	# Score
	score_label = Label.new()
	score_label.name = "ScoreLabel"
	score_label.text = "SCORE: 0"
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 36)
	score_label.modulate = Color(1.0, 0.8, 0.0)
	vbox.add_child(score_label)

	# Stats
	stats_label = Label.new()
	stats_label.name = "StatsLabel"
	stats_label.text = ""
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(stats_label)

	# Personal best
	best_label = Label.new()
	best_label.name = "BestLabel"
	best_label.text = ""
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	best_label.add_theme_font_size_override("font_size", 22)
	best_label.modulate = Color(0.3, 1.0, 0.5)
	vbox.add_child(best_label)

	# Hints
	hint_label = Label.new()
	hint_label.name = "HintLabel"
	hint_label.text = "[R] RESTART    [ESC] QUIT"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 18)
	hint_label.modulate = Color(0.7, 0.7, 0.7)
	vbox.add_child(hint_label)


func show_game_over(score_val: int, wave_val: int, kills_val: int, best_combo: int) -> void:
	final_score = score_val
	final_wave = wave_val
	final_kills = kills_val
	final_combo = best_combo

	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	score_label.text = "SCORE: %d" % final_score
	stats_label.text = "Wave: %d  |  Kills: %d  |  Best Combo: x%d" % [final_wave, final_kills, final_combo]

	# Show personal best
	var pb := _get_personal_best()
	if pb > 0:
		if final_score >= pb:
			best_label.text = "NEW PERSONAL BEST!"
			best_label.modulate = Color(1.0, 0.8, 0.0)
		else:
			best_label.text = "PERSONAL BEST: %d" % pb
			best_label.modulate = Color(0.3, 1.0, 0.5)
	else:
		best_label.text = ""

	# Animate score counting up
	var tween := create_tween()
	tween.tween_method(_animate_score, 0, final_score, 1.5)

	# Title pulse
	title_label.modulate = Color(1, 1, 1)
	var t2 := create_tween()
	t2.tween_property(title_label, "modulate", Color(1.0, 0.2, 0.2), 0.5)


func _animate_score(value: int) -> void:
	if score_label:
		score_label.text = "SCORE: %d" % value


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R:
				_restart()
			KEY_ESCAPE:
				_quit_to_menu()


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _get_personal_best() -> int:
	var path := "user://highscores.json"
	if not FileAccess.file_exists(path):
		return 0
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return 0
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Array:
		var scores: Array = json.data
		if scores.size() > 0 and "score" in scores[0]:
			return int(scores[0].score)
	return 0


func _quit_to_menu() -> void:
	get_tree().paused = false
	var menu_path := "res://scenes/ui/main_menu.tscn"
	if ResourceLoader.exists(menu_path):
		get_tree().change_scene_to_file(menu_path)
	else:
		get_tree().reload_current_scene()
