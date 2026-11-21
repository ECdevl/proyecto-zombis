extends Node
class_name FootstepPlayer

@export var step_sound: AudioStream

@onready var footstep_audio: AudioStreamPlayer = %FootstepAudio

func play_step() -> void:
	if step_sound == null:
		return
	footstep_audio.stream = step_sound
	footstep_audio.play()
