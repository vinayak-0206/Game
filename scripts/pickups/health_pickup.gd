extends PickupBase

## Restores player health — green glowing orb

@export var heal_amount := 25.0


func _ready() -> void:
	pickup_color = Color(0.1, 1.0, 0.3)
	super._ready()


func _apply_pickup(player: Node3D) -> bool:
	if player.has_method("heal") and player.current_health < player.max_health:
		player.heal(heal_amount)
		return true
	return false
