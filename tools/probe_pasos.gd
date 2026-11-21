extends SceneTree

var _failures: int = 0
var _steps: int = 0

func _init() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	if ok:
		print("OK: ", label)
	else:
		_failures += 1
		print("FALLA: ", label)

func _on_footstep() -> void:
	_steps += 1

func _run() -> void:
	var packed: PackedScene = load("res://scenes/player.tscn")
	var player: Node = packed.instantiate()
	root.add_child(player)
	await process_frame
	var sway: Node = player.get_node("ViewmodelSway")
	var steps: Node = player.get_node("FootstepPlayer")
	var audio: AudioStreamPlayer = steps.get_node("FootstepAudio")
	_check(sway != null and steps != null and audio != null, "nodos de pasos presentes")
	_check(steps.step_sound != null, "randomizer asignado al nodo")
	var connected: bool = false
	for connection: Dictionary in sway.footstep.get_connections():
		if connection.callable.get_object() == steps and connection.callable.get_method() == "play_step":
			connected = true
	_check(connected, "senal footstep conectada a play_step")
	sway.footstep.connect(_on_footstep)
	sway.advance_footsteps(PI / sway.bob_speed - 0.01)
	_check(_steps == 0, "sin paso antes del cruce de fase")
	sway.advance_footsteps(0.02)
	_check(_steps == 1, "un paso al cruzar la fase")
	steps.play_step()
	_check(audio.stream == steps.step_sound, "play_step asigna el randomizer al reproductor")
	_check(audio.playing, "reproduccion activa tras play_step")
	print("RESULTADO: ", "TODO OK" if _failures == 0 else ("FALLOS " + str(_failures)))
	quit()
