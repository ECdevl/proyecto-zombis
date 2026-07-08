extends Item
class_name Weapon
enum Type {MELEE,GUN}
@export var weapon_type : Type = Type.MELEE
enum Handle {TWO=2,ONE=1}
@export var weapon_handle : Handle = Handle.TWO
@export var weapon_pos_grip : Vector3
@export var weapon_rot_grip : Vector3
@export var weapon_damage : float

func get_actions() -> Array[StringName]:
	return [&"equip",&"drop",&"set quick slot"]
