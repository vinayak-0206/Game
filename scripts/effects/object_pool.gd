extends Node
class_name ObjectPool

## DEPRECATED — GPU particles via ParticleFactory handle effects now.
## Generic object pool — reuses MeshInstance3D nodes instead of creating/destroying them.
## Reduces GC pressure and node allocation overhead during combat.

var _pool: Array[MeshInstance3D] = []
var _active: Array[MeshInstance3D] = []
var _pool_size: int
var _parent: Node


static func create(parent: Node, size: int, mesh: Mesh, material: Material = null) -> ObjectPool:
	var pool := ObjectPool.new()
	pool._pool_size = size
	pool._parent = parent
	pool.name = "ObjectPool_%d" % size
	parent.add_child(pool)

	for i in range(size):
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		if material:
			instance.material_override = material
		instance.visible = false
		pool.add_child(instance)
		pool._pool.append(instance)

	return pool


func acquire() -> MeshInstance3D:
	var instance: MeshInstance3D
	if _pool.size() > 0:
		instance = _pool.pop_back()
	elif _active.size() > 0:
		# Recycle oldest active instance
		instance = _active.pop_front()
	else:
		return null

	instance.visible = true
	_active.append(instance)
	return instance


func release(instance: MeshInstance3D) -> void:
	instance.visible = false
	instance.position = Vector3.ZERO
	instance.rotation = Vector3.ZERO
	instance.scale = Vector3.ONE
	_active.erase(instance)
	_pool.append(instance)


func release_all() -> void:
	for instance in _active.duplicate():
		release(instance)
