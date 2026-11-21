extends Node

## Sonda de verificación (T-021/D-033): comprueba que Camera3D queda exactamente
## en la posición del BoneAttachment3D del cuello, en reposo, al agacharse y con
## yaw/pitch girados, y que su rotación siguen controlándola yaw y pitch.
## Corre como escena:
##   godot --headless --path . res://tools/probe_neck_cam.tscn --quit-after 240

var _errores: int = 0


func _check(ok: bool, mensaje: String) -> void:
	if ok:
		print("  OK  ", mensaje)
	else:
		_errores += 1
		push_error("FALLO: " + mensaje)


func _ready() -> void:
	var packed: PackedScene = load("res://scenes/player.tscn")
	var p: Node = packed.instantiate()
	add_child(p)
	for _i in range(3):
		await get_tree().process_frame

	var att: BoneAttachment3D = p.get_node("Yaw/FPS_BODY/metarig/Skeleton3D/BoneAttachment3D")
	var yaw: Node3D = p.get_node("Yaw")
	var rig: Node3D = p.get_node("Yaw/CameraRig")
	var pitch: Node3D = p.get_node("Yaw/CameraRig/Pitch")
	var cam: Camera3D = p.get_node("Yaw/CameraRig/Pitch/Camera3D")
	var at: AnimationTree = p.get_node("BodyAT")

	print("=== JERARQUÍA ===")
	_check(pitch.get_parent() == rig, "Pitch es hijo de CameraRig")
	_check(rig.get_parent() == yaw, "CameraRig es hijo de Yaw")
	_check(cam.get_parent() == pitch, "Camera3D es hijo de Pitch")
	_check(rig.get("neck_attachment") == att, "neck_attachment resuelto por node_paths")
	_check(rig.process_priority == 1, "CameraRig.process_priority == 1")

	print("=== SEGUIMIENTO (idle) ===")
	await _verificar(yaw, att, cam, pitch, "idle")
	var local_idle: Vector3 = yaw.to_local(att.global_position)
	print("  hueso local en yaw=", local_idle)

	# Con rotación de cámara: la posición debe seguir al hueso y la rotación
	# debe seguir siendo la de Yaw*Pitch, no la del hueso.
	yaw.rotation.y = 0.6
	pitch.rotation.x = 0.25
	await get_tree().process_frame
	await get_tree().process_frame
	print("=== SEGUIMIENTO (yaw=0.6, pitch=0.25) ===")
	await _verificar(yaw, att, cam, pitch, "rotado")

	yaw.rotation.y = 0.0
	pitch.rotation.x = 0.0
	var playback: AnimationNodeStateMachinePlayback = at["parameters/body/playback"]
	playback.travel(&"crouch")
	await get_tree().create_timer(0.6).timeout
	print("=== SEGUIMIENTO (crouch) ===")
	print("  estado body=", playback.get_current_node())
	await _verificar(yaw, att, cam, pitch, "crouch")
	var local_crouch: Vector3 = yaw.to_local(att.global_position)
	print("  hueso local en yaw=", local_crouch)
	_check(local_crouch.y < local_idle.y - 0.05, "el hueso baja respecto a Yaw al agacharse")

	playback.travel(&"idle")
	await get_tree().create_timer(0.6).timeout
	print("=== SEGUIMIENTO (vuelta a idle) ===")
	await _verificar(yaw, att, cam, pitch, "idle final")

	print("=== RESULTADO ===")
	if _errores == 0:
		print("TODO OK")
	else:
		print("ERRORES=", _errores)
	get_tree().quit(1 if _errores > 0 else 0)


func _verificar(yaw: Node3D, att: BoneAttachment3D, cam: Camera3D, pitch: Node3D, etiqueta: String) -> void:
	await get_tree().process_frame
	var dist: float = cam.global_position.distance_to(att.global_position)
	_check(dist < 0.001, etiqueta + ": cámara sobre el hueso (dist=%s)" % str(dist))
	var basis_diff: float = 0.0
	for c in range(3):
		for r in range(3):
			basis_diff += absf(cam.global_transform.basis[c][r] - pitch.global_transform.basis[c][r])
	_check(basis_diff < 0.0001, etiqueta + ": rotación de cámara = rotación de Pitch (diff=%s)" % str(basis_diff))
	_check(yaw.position.y > 1.0, etiqueta + ": Yaw conserva su altura de escena (y=%s)" % str(yaw.position.y))
