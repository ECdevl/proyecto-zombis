extends EquippableDescriptor
class_name Weapon
signal ammo_requested

enum WEAPON_TYPE {MELEE, PISTOL, RIFLE, SHOTGUN}
enum AMMO_TYPE {NONE,LOW_CALIBER,MID_CALIBER,HIGH_CALIBER,CAL}
@export var ammo_type: AMMO_TYPE = AMMO_TYPE.NONE
@export var weapon_type: WEAPON_TYPE
@export var reload_time: float
@export var curr_bullets: int
@export var max_bullets: int
@export var ammo_reserve: Array[ItemDescriptor]
@export var mag_size: int
@export var bullet_per_reload: int = 0
@export var pellets_per_shot: int = 1
@export var pellet_spread_deg: float = 4.0
@export var recoil_kick: Vector2
@export var recoil_recovery_speed: float

@export_category("SFX")
@export var shoot_sound : AudioStream
@export var reload_sound : AudioStream
@export var push_sound : AudioStream = preload("uid://b0w1tbcqpftu0")
@export var handling_sounds : AudioStream = preload("uid://1l5oje1ucrcv")
@export var run_sounds : AudioStream = preload("uid://desbtdb3ovats")
func _init() -> void:
	behaviour = FirearmBehaviour.new()
