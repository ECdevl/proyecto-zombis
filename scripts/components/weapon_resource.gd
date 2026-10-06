extends ItemDescriptor
class_name Weapon
signal ammo_requested

enum WEAPON_TYPE {MELEE, PISTOL, RIFLE, SHOTGUN}
enum AMMO_TYPE {NONE,LOW_CALIBER,MID_CALIBER,HIGH_CALIBER,CAL}
@export var ammo_type : AMMO_TYPE = AMMO_TYPE.NONE
@export var weapon_type : WEAPON_TYPE
@export var fire_rate : float
@export var damage : float
@export var reload_time : float
@export var weapon_range : float

@export var curr_bullets : int
@export var max_bullets : int
@export var ammo_reserve : Array[ItemDescriptor]
@export var mag_size : int


@export var recoil_kick : Vector2
@export var recoil_recovery_speed : float
@export var viewmodel_model : PackedScene

func get_actions() -> Array[String]:
	var lines = super.get_actions()
	lines.append("equipar")
	return lines
