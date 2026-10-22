class_name ZombieHitReaction extends Node
## Reacción al impacto: el miembro golpeado (y lo que cuelga de él) pasa a física
## un instante y después vuelve suavemente a la animación.
## Es independiente de ZombieRagdoll (ragdoll total): si ese está activo, no hace nada.

@export var ragdoll: ZombieRagdoll
@export var simulator: PhysicalBoneSimulator3D
@export var skeleton: Skeleton3D
## Cuántos niveles hacia abajo se simulan desde el hueso golpeado.
## 2 = hueso + hijo + nieto (brazo: upper_arm → forearm → hand).
@export var limb_depth: int = 2
## Segundos con la física al 100% antes de empezar a volver.
@export var hold_time: float = 0.2
## Segundos que tarda en volver a la animación.
@export var blend_time: float = 0.3

var _bones: Dictionary[StringName, PhysicalBone3D] = {}  # nombre del hueso → hueso físico
var _active: Array[StringName] = []  # huesos simulándose ahora
var _tween: Tween


func _ready() -> void:
	for child in simulator.get_children():
		var physical := child as PhysicalBone3D
		if physical:
			_bones[StringName(skeleton.get_bone_name(physical.get_bone_id()))] = physical
	# Si empieza el ragdoll total (muerte, caída), esta reacción se cancela.
	ragdoll.ragdoll_started.connect(_cancel)


## hitbox: el Area3D golpeado. direction: hacia dónde empuja (mundo). force: fuerza del impulso.
func react(hitbox: Node, direction: Vector3, force: float) -> void:
	if ragdoll.is_ragdoll:
		return
	var attachment := hitbox.get_parent() as BoneAttachment3D
	if attachment == null:
		return
	var root := skeleton.find_bone(attachment.bone_name)
	if root == -1:
		return

	var limb: Array[StringName] = []
	_collect(root, limb_depth, limb)
	if limb.is_empty():
		push_warning("HitReaction: '%s' no tiene hueso físico" % attachment.bone_name)
		return

	# Dos golpes seguidos: se suman los huesos y se reinicia el tiempo.
	for bone_name in limb:
		if bone_name not in _active:
			_active.append(bone_name)
	simulator.influence = 1.0
	simulator.physical_bones_start_simulation(_active)
	_bones[limb[0]].apply_central_impulse(direction.normalized() * force)

	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(hold_time)
	_tween.tween_property(simulator, "influence", 0.0, blend_time)
	_tween.tween_callback(_finish)


## Junta el hueso y sus descendientes (hasta `depth` niveles) que tengan hueso físico.
func _collect(bone_idx: int, depth: int, out: Array[StringName]) -> void:
	var bone_name := StringName(skeleton.get_bone_name(bone_idx))
	if _bones.has(bone_name):
		out.append(bone_name)
	if depth <= 0:
		return
	for child in skeleton.get_bone_children(bone_idx):
		_collect(child, depth - 1, out)


func _finish() -> void:
	simulator.physical_bones_stop_simulation()
	simulator.influence = 1.0
	_active.clear()


## Llega el ragdoll total: no se debe detener su simulación ni dejar la influencia a medias.
func _cancel() -> void:
	if _tween:
		_tween.kill()
	simulator.influence = 1.0
	_active.clear()
