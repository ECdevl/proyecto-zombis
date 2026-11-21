class_name SkeletonUtils extends RefCounted
## Búsqueda de huesos del brazo izquierdo por nombre normalizado.
## Antes ViewmodelAnimator y WeaponController tenían cada uno su propia copia
## de la normalización; acá vive una sola vez para ambas necesidades:
## capas de animación (ViewmodelAnimator) y anclaje de la linterna (FlashlightController).

static func normalize_bone_name(name: String) -> String:
	var n: String = name.to_lower()
	n = n.replace("_", "")
	n = n.replace(".", "")
	n = n.replace(" ", "")
	return n


## Índice del hueso "upper_arm_left" (o variantes abreviadas), -1 si no está.
static func find_upper_arm_left_index(skeleton: Skeleton3D) -> int:
	if skeleton == null:
		return -1
	for i in skeleton.get_bone_count():
		var norm: String = normalize_bone_name(skeleton.get_bone_name(i))
		if norm == "upperarmleft" or norm == "upperarml":
			return i
	return -1


## Nombres de la cadena izquierda (upperarm → forearm → hand).
## BoneAttachment3D solo acepta el nombre del hueso, de ahí que no se devuelvan índices.
static func find_arm_bones(skeleton: Skeleton3D) -> Dictionary:
	if skeleton == null:
		return {}
	var root_name: String = ""
	var middle_name: String = ""
	var end_name: String = ""
	for i in skeleton.get_bone_count():
		var bname: String = skeleton.get_bone_name(i)
		var norm: String = normalize_bone_name(bname)
		if root_name.is_empty() and (norm == "upperarmleft" or norm == "upperarml"):
			root_name = bname
		elif middle_name.is_empty() and (norm == "forearmleft" or norm == "forearml" or norm == "lowerarmleft" or norm == "lowerarml"):
			middle_name = bname
		elif end_name.is_empty() and (norm == "handleft" or norm == "handl"):
			end_name = bname
	if root_name.is_empty() or middle_name.is_empty() or end_name.is_empty():
		return {}
	return {
		"root_name": root_name,
		"middle_name": middle_name,
		"end_name": end_name,
	}


## Primer Skeleton3D del subtree que tenga cadena de brazo izquierda completa.
static func find_arm_skeleton(root: Node) -> Skeleton3D:
	if root == null:
		return null
	for candidate in root.find_children("*", "Skeleton3D", true, false):
		var sk: Skeleton3D = candidate as Skeleton3D
		if sk != null and not find_arm_bones(sk).is_empty():
			return sk
	return null
