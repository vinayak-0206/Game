extends Node

## Global game state singleton — persists across scenes

enum Difficulty { EASY, NORMAL, HARD }

var selected_map: MapData = null
var selected_map_index := 0
var difficulty := Difficulty.NORMAL
var sensitivity := 0.0015
var fov := 75.0

# Weapon unlock progression
var unlocked_weapons: Array[String] = ["Assault Rifle", "Pistol"]

# Score thresholds to unlock weapons
const WEAPON_UNLOCK_THRESHOLDS := {
	"Shotgun": 500,
	"SMG": 1500,
	"Sniper Rifle": 3000,
	"Rocket Launcher": 5000,
}


func _ready() -> void:
	if selected_map == null:
		selected_map = MapData.neon_nexus()
	_load_settings()
	_load_unlocks()


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


func check_weapon_unlocks(total_score: int) -> Array[String]:
	var newly_unlocked: Array[String] = []
	for weapon_name in WEAPON_UNLOCK_THRESHOLDS:
		if weapon_name not in unlocked_weapons:
			if total_score >= WEAPON_UNLOCK_THRESHOLDS[weapon_name]:
				unlocked_weapons.append(weapon_name)
				newly_unlocked.append(weapon_name)
	if newly_unlocked.size() > 0:
		_save_unlocks()
	return newly_unlocked


func is_weapon_unlocked(weapon_name: String) -> bool:
	return weapon_name in unlocked_weapons


func _load_unlocks() -> void:
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		var saved: Variant = config.get_value("weapons", "unlocked", null)
		if saved is Array:
			for w in saved:
				if w is String and w not in unlocked_weapons:
					unlocked_weapons.append(w)


func _save_unlocks() -> void:
	var config := ConfigFile.new()
	config.load("user://settings.cfg")
	config.set_value("weapons", "unlocked", unlocked_weapons)
	config.save("user://settings.cfg")
