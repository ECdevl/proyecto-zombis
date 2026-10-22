extends EquippableDescriptor
class_name Weapon
signal ammo_requested

## MELEE se deja para no mover los valores guardados en los .tres. Lo cuerpo a cuerpo ahora es Melee.
enum WEAPON_TYPE {MELEE, PISTOL, RIFLE, SHOTGUN}
enum AMMO_TYPE {NONE,LOW_CALIBER,MID_CALIBER,HIGH_CALIBER,CAL}
@export var ammo_type : AMMO_TYPE = AMMO_TYPE.NONE
@export var weapon_type : WEAPON_TYPE
@export var reload_time : float

@export var curr_bullets : int
@export var max_bullets : int
@export var ammo_reserve : Array[ItemDescriptor]
@export var mag_size : int

@export var recoil_kick : Vector2
@export var recoil_recovery_speed : float
