extends Node

## Global game state singleton — persists across scenes

enum Difficulty { EASY, NORMAL, HARD }

var selected_map: MapData = null
var selected_map_index := 0
var difficulty := Difficulty.NORMAL
var sensitivity := 0.0015
var fov := 75.0


func _ready() -> void:
	if selected_map == null:
		selected_map = MapData.neon_nexus()
	_load_settings()


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		sensitivity = config.get_value("controls", "sensitivity", 0.0015)
		fov = config.get_value("controls", "fov", 75.0)
		difficulty = config.get_value("game", "difficulty", Difficulty.NORMAL)


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("controls", "sensitivity", sensitivity)
	config.set_value("controls", "fov", fov)
	config.set_value("game", "difficulty", difficulty)
	config.save("user://settings.cfg")


func get_difficulty_multiplier() -> float:
	match difficulty:
		Difficulty.EASY:
			return 0.7
		Difficulty.HARD:
			return 1.4
		_:
			return 1.0


func get_difficulty_name() -> String:
	match difficulty:
		Difficulty.EASY:
			return "EASY"
		Difficulty.HARD:
			return "HARD"
		_:
			return "NORMAL"
