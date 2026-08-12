extends Node3D
@onready var muzzle_flash: GPUParticles3D = %MuzzleFlash
@onready var light: OmniLight3D = %Light

func start_effect() -> void:
	muzzle_flash.restart()
	light.show()
	await get_tree().create_timer(0.05).timeout
	light.hide()
