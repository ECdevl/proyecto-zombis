class_name NeckCameraRig
extends Node3D

## Rig intermedio entre Yaw y Pitch. Copia SOLO la posición del hueso del
## cuello (BoneAttachment3D) al espacio local de Yaw; la rotación siguen
## controlándola Yaw (mouse horizontal) y Pitch (mouse vertical).
##
## No se mueve Yaw: FPS_BODY es su hijo, así que moverlo realimentaría el
## seguimiento. Tampoco se mueve Pitch: su position:x la usa el lean y su
## position.z guarda el retroceso de la cámara.

@export var neck_attachment: BoneAttachment3D
@export var camera_offset : Vector3 = Vector3.ZERO
var _yaw: Node3D
var _pitch: Node3D
## Pitch ya adelanta la cámara 14,5 cm en Z. Se guarda ese desplazamiento para
## restarlo y dejar el origen de Camera3D exactamente sobre el hueso. Solo se
## toma Z: LeanController mueve Pitch en X y ese desplazamiento SÍ debe verse.
var _pitch_z: float = 0.0


func _ready() -> void:
	_yaw = get_parent() as Node3D
	_pitch = get_node_or_null("Pitch") as Node3D
	if _pitch != null:
		_pitch_z = _pitch.position.z
	# La pose final del esqueleto se calcula en AnimationPlayer/AnimationTree,
	# que tienen prioridad 0: este nodo corre después dentro del mismo frame.
	process_priority = 1
	if neck_attachment == null:
		push_error("NeckCameraRig: falta neck_attachment")


func _process(_delta: float) -> void:
	if neck_attachment == null or _yaw == null:
		return
	# to_local() es obligatorio: global_position del hueso gira con Yaw, y
	# asignarlo como posición local haría que la cámara orbitara con el mouse.
	var bone_in_yaw: Vector3 = _yaw.to_local(neck_attachment.global_position)
	position = bone_in_yaw - Vector3(0.0, 0.0, _pitch_z) + camera_offset
