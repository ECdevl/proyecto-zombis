extends Item
class_name Weapon
enum Type {MELEE,GUN}
@export var weapon_type : Type = Type.MELEE
enum Handle {TWO=2,ONE=1}
@export var weapon_viewmodel : PackedScene

@export var weapon_handle : Handle = Handle.TWO
@export var weapon_damage : float
@export var fire_rate : float = 0.2
@export_category("firearm properties")
@export var weapon_mag_size : int = 0
@export var weapon_max_bullets : int = 0
@export var weapon_current_ammo : int = 0
@export var weapon_current_bullets : int = 0
@export var weapon_range : float = 1200.0

@export var headshot_multiplier : float = 1.5
@export_category("recoil")
@export var recoil_kick : Vector2 = Vector2(2.0, 0.5)   # x = vertical, y = dispersión horizontal
@export var recoil_recovery_speed : float = 8.0

func get_actions() -> Array[StringName]:
	return [&"equip",&"drop",&"set quick slot",&"move"]
