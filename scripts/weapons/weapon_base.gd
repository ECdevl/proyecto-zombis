extends Node3D
class_name WeaponBase
@onready var gun_ap: AnimationPlayer = %gun_ap

@export var weapon_resource : Weapon

@export var main_grip : Marker3D
@export var second_grip : Marker3D
@export var fire_grip : Marker3D
@export var aim_pos : Marker3D

func fired() -> void:
	gun_ap.play("pistols_animations/fire")

func eject_mag() -> void:
	gun_ap.play("pistols_animations/eject_mag")

func insert_mag() -> void:
	gun_ap.play_backwards("pistols_animations/eject_mag")
