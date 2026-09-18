class_name MeleeHitbox extends ShapeCast3D

var damage: float
var _hit: Array[Object] = []
var active: bool = false

func start_attack(dmg: float, radius: float, dist: float) -> void:
	_hit.clear()
	damage = dmg
	target_position = Vector3(0, 0, -dist)
	(shape as CapsuleShape3D).radius = radius
	active = true

func stop_attack() -> void:
	active = false

func _physics_process(_d):
	if not active: return
	force_shapecast_update()
	for i in get_collision_count():
		var c = get_collider(i)
		if c in _hit: continue
		if c.owner is Zombie:
			c.owner.health_component.hurt(damage, c)
		_hit.append(c)
