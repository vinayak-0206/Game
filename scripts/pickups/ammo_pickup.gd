extends PickupBase

## Adds reserve ammo — yellow glowing orb

@export var ammo_amount := 30


func _ready() -> void:
	pickup_color = Color(1.0, 0.8, 0.0)
	super._ready()


func _apply_pickup(player: Node3D) -> bool:
	if player.has_method("add_reserve_ammo"):
		player.add_reserve_ammo(ammo_amount)
		return true
	return false
