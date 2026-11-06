extends Node3D
## Sonda de ejes de flexión del ragdoll.
##
## Instancia `zombie.tscn`, espera a que el esqueleto y los huesos físicos se
## inicialicen y, para cada `PhysicalBone3D`, calcula en el frame del joint:
##   * la dirección del miembro (eje largo del hueso),
##   * qué eje local (X/Y/Z) coincide con el eje derecha del personaje
##     (flexión sagital: rodilla/codo),
##   * qué eje local coincide con el eje adelante (abducción),
##   * el sentido de giro que mueve la punta del miembro hacia adelante.
##
## La geometría se toma del rest pose del `Skeleton3D`, que es independiente
## de la pose de animación y por tanto da el mapa anatómico estable.
##
## Uso: godot --headless --path . res://tools/probe_ragdoll_axes.tscn

const ZOMBIE_SCENE: PackedScene = preload("res://scenes/zombies/zombie.tscn")

const AXIS_NAMES: Array[String] = ["X", "Y", "Z"]


func _ready() -> void:
	var zombie: Node3D = ZOMBIE_SCENE.instantiate()
	add_child(zombie)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var skeleton: Skeleton3D = zombie.get_node_or_null("ZombiConRig/rig/Skeleton3D") as Skeleton3D
	var simulator: PhysicalBoneSimulator3D = zombie.get_node_or_null(
		"ZombiConRig/rig/Skeleton3D/PhysicalBoneSimulator3D") as PhysicalBoneSimulator3D
	if skeleton == null or simulator == null:
		print("FALLA: no se encontró Skeleton3D o PhysicalBoneSimulator3D")
		get_tree().quit(1)
		return

	# Frame del personaje. En la escena de prueba el zombi mira a -Z (Godot).
	var char_basis: Basis = zombie.global_basis.orthonormalized()
	var right_world: Vector3 = char_basis * Vector3.RIGHT
	var forward_world: Vector3 = char_basis * Vector3.FORWARD
	var up_world: Vector3 = char_basis * Vector3.UP
	print("frame personaje: right=%s forward=%s up=%s" % [right_world, forward_world, up_world])

	var bones: Array[PhysicalBone3D] = []
	for child in simulator.get_children():
		var bone: PhysicalBone3D = child as PhysicalBone3D
		if bone != null:
			bones.append(bone)

	print("")
	print("=== Ejes por hueso (rest pose) ===")
	for bone in bones:
		_print_bone(bone, skeleton, right_world, forward_world, up_world)

	print("")
	print("=== Resumen de flexión ===")
	for bone in bones:
		_print_flexion(bone, skeleton, right_world, forward_world)

	get_tree().quit(0)


func _rest_bone_global(bone: PhysicalBone3D, skeleton: Skeleton3D) -> Transform3D:
	var bone_id: int = bone.get_bone_id()
	if bone_id < 0:
		return bone.global_transform
	return skeleton.global_transform * skeleton.get_bone_global_rest(bone_id)


func _rest_joint(bone: PhysicalBone3D, skeleton: Skeleton3D) -> Transform3D:
	return _rest_bone_global(bone, skeleton) * bone.body_offset * bone.joint_offset


func _limb_local(bone: PhysicalBone3D, skeleton: Skeleton3D, basis: Basis) -> Vector3:
	# El hueso crece a lo largo de su +Y local; en el frame del cuerpo eso es -Z.
	var bone_global: Transform3D = _rest_bone_global(bone, skeleton)
	var dir_world: Vector3 = (bone_global.basis * Vector3.UP).normalized()
	return (basis.inverse() * dir_world).normalized()


func _print_bone(bone: PhysicalBone3D, skeleton: Skeleton3D, right_world: Vector3,
		forward_world: Vector3, up_world: Vector3) -> void:
	var joint: Transform3D = _rest_joint(bone, skeleton)
	var basis: Basis = joint.basis.orthonormalized()
	var inv: Basis = basis.inverse()

	var right_local: Vector3 = (inv * right_world).normalized()
	var forward_local: Vector3 = (inv * forward_world).normalized()
	var up_local: Vector3 = (inv * up_world).normalized()
	var limb_local: Vector3 = _limb_local(bone, skeleton, basis)

	print("%-18s tipo=%d  limb=%s  right=%s (%s)  fwd=%s (%s)  up=%s (%s)" % [
		bone.name,
		bone.joint_type,
		_fmt(limb_local),
		_fmt(right_local), _dominant(right_local),
		_fmt(forward_local), _dominant(forward_local),
		_fmt(up_local), _dominant(up_local),
	])


func _print_flexion(bone: PhysicalBone3D, skeleton: Skeleton3D, right_world: Vector3,
		forward_world: Vector3) -> void:
	var joint: Transform3D = _rest_joint(bone, skeleton)
	var basis: Basis = joint.basis.orthonormalized()
	var inv: Basis = basis.inverse()
	var right_local: Vector3 = (inv * right_world).normalized()
	var limb_local: Vector3 = _limb_local(bone, skeleton, basis)

	# Eje local dominante del eje derecha del personaje.
	var flex_axis: Vector3 = _dominant_axis_vector(right_local)
	# Para un giro pequeño +theta alrededor de flex_axis, la punta del miembro
	# se mueve en la dirección flex_axis x limb (en el frame del joint).
	var move_local: Vector3 = flex_axis.cross(limb_local)
	var move_world: Vector3 = (basis * move_local).normalized()
	var dot_forward: float = move_world.dot(forward_world)
	var sentido: String = "ADELANTE" if dot_forward > 0.0 else "ATRAS"
	print("%-18s flex_axis=%s  +giro mueve punta %s (dot fwd=%.2f)" % [
		bone.name, _dominant(right_local), sentido, dot_forward])


func _dominant(v: Vector3) -> String:
	var ax: int = 0
	if absf(v.y) > absf(v[ax]):
		ax = 1
	if absf(v.z) > absf(v[ax]):
		ax = 2
	return "%s%s" % [AXIS_NAMES[ax], "+" if v[ax] >= 0.0 else "-"]


func _dominant_axis_vector(v: Vector3) -> Vector3:
	var ax: int = 0
	if absf(v.y) > absf(v[ax]):
		ax = 1
	if absf(v.z) > absf(v[ax]):
		ax = 2
	var out: Vector3 = Vector3.ZERO
	out[ax] = 1.0 if v[ax] >= 0.0 else -1.0
	return out


func _fmt(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]
