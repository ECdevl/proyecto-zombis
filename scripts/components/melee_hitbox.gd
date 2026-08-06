# melee_hitbox.gd
extends ShapeCast3D
class_name MeleeHitbox

@export var damage: int = 25
var _already_hit: Array[Object] = []
var active: bool = false

func _physics_process(_delta):
	if not active:
		return
	force_shapecast_update()
	for i in get_collision_count():
		var collider = get_collider(i)
		if collider in _already_hit:
			continue
		if collider.owner is Zombie:
			collider.owner.health_component.hurt(damage,collider)
		_already_hit.append(collider)

func start_attack():
	_already_hit.clear()
	active = true

func stop_attack():
	active = false
