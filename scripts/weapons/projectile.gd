extends Area3D
class_name Projectile

## Projectile that moves forward and damages on contact

@export var speed := 50.0
@export var lifetime := 5.0

var damage := 25.0
var velocity_dir := Vector3.FORWARD
var instigator: Node = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Auto-destroy after lifetime
	await get_tree().create_timer(lifetime).timeout
	queue_free()


func setup(dmg: float, vel: Vector3, from: Node) -> void:
	damage = dmg
	velocity_dir = vel
	instigator = from


func _physics_process(delta: float) -> void:
	global_position += velocity_dir * delta


func _on_body_entered(body: Node3D) -> void:
	if body == instigator:
		return
	if body.has_method("take_damage"):
		body.take_damage(damage, instigator)
	queue_free()
