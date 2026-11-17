extends Node3D
## Sonda diagnóstica de POSTURA y LÍMITES del ragdoll del zombi.
##
## Reproduce la muerte del juego en distintas variantes y mide, por joint,
## el ángulo relativo real (horneando los mismos frames que el motor usa en
## `_reload_joint()`) contra los límites 6DOF configurados:
##   - PRE-START: violación angular ya presente con los huesos kinemáticos
##     (cero del joint = pose de carga de la escena ≠ pose animada).
##   - START: el mismo ángulo en el primer frame de simulación.
##   - MAX/FINAL: máximo histórico y promedio final por eje.
##   - DEV: desviación angular total respecto al cero del joint
##     (Quaternion.IDENTITY.angle_to(rel), independiente de la descomposición
##     euleriana; elimina falsas lecturas cerca de gimbal).
## Postura: flexión del torso (pelvis→chest vs UP), alturas y distancias
## cabeza-rodillas, medidas sobre los CUERPOS físicos (no sobre el esqueleto).
##
## Escenarios:
##   A: start(true) sin impulso, tras 0.5 s de "walk" (muerte en animación, como el juego).
##   B: igual + impulso de bate (500 N·s) al chest desde el frente.
##   C: igual que A + 10 frames de espera extra con la animación siguiendo (asentamiento).
##   D: igual que A pero re-horneando los joints a la pose animada (fix candidato).
##   E: igual que A pero huesos colisionan SOLO con el piso (descarta auto-colisión).
##
## Uso: godot --headless --path . res://tools/probe_ragdoll_posture.tscn

const ZOMBIE_SCENE := preload("res://scenes/zombies/zombie.tscn")

const AXES: Array[String] = ["x", "y", "z"]
const KEY_JOINTS: Array[String] = ["spine", "chest", "neck", "thigh", "shin"]
const WALK_FRAMES: int = 30
const RUN_FRAMES: int = 360
const FINAL_AVG: int = 30
const SETTLE_FRAMES: int = 10
const BAT_FORCE: float = 500.0
const MARGIN_DEG: float = 2.0
const FOLD_STANDING_MAX: float = 110.0

var fallos: int = 0
var zombie: Zombie = null
var bones: Array[PhysicalBone3D] = []
var bone_by_id: Dictionary = {}
var parent_by_id: Dictionary = {}
var joints: Array[Dictionary] = []
var skeleton_ref: Skeleton3D = null
var saw_non_finite: bool = false
var belly_sign: float = 1.0
var server_joints: Array[RID] = []


func _crear_joints_server() -> void:
	for j in joints:
		var child: PhysicalBone3D = j["child"] as PhysicalBone3D
		var parent_bone: PhysicalBone3D = j["parent"] as PhysicalBone3D
		var world_b: Transform3D = child.global_transform * child.joint_offset
		var local_a: Transform3D = parent_bone.global_transform.affine_inverse() * world_b
		local_a = Transform3D(local_a.basis.orthonormalized(), local_a.origin)
		var rid: RID = PhysicsServer3D.joint_create()
		PhysicsServer3D.joint_make_generic_6dof(rid, parent_bone.get_rid(), local_a, child.get_rid(), child.joint_offset)
		var limits: Dictionary = j["limits"]
		for axis_i in range(3):
			var axis: Vector3.Axis = axis_i as Vector3.Axis
			var lim: Dictionary = limits[AXES[axis_i]]
			PhysicsServer3D.generic_6dof_joint_set_flag(rid, axis, PhysicsServer3D.G6DOF_JOINT_FLAG_ENABLE_LINEAR_LIMIT, true)
			PhysicsServer3D.generic_6dof_joint_set_param(rid, axis, PhysicsServer3D.G6DOF_JOINT_LINEAR_UPPER_LIMIT, 0.0)
			PhysicsServer3D.generic_6dof_joint_set_param(rid, axis, PhysicsServer3D.G6DOF_JOINT_LINEAR_LOWER_LIMIT, 0.0)
			if bool(lim["enabled"]):
				PhysicsServer3D.generic_6dof_joint_set_flag(rid, axis, PhysicsServer3D.G6DOF_JOINT_FLAG_ENABLE_ANGULAR_LIMIT, true)
				PhysicsServer3D.generic_6dof_joint_set_param(rid, axis, PhysicsServer3D.G6DOF_JOINT_ANGULAR_UPPER_LIMIT, deg_to_rad(float(lim["upper"])))
				PhysicsServer3D.generic_6dof_joint_set_param(rid, axis, PhysicsServer3D.G6DOF_JOINT_ANGULAR_LOWER_LIMIT, deg_to_rad(float(lim["lower"])))
		server_joints.append(rid)


func _agregar_excepciones_huesos() -> void:
	for ji in range(joints.size()):
		var child: PhysicalBone3D = joints[ji]["child"] as PhysicalBone3D
		var parent_bone: PhysicalBone3D = joints[ji]["parent"] as PhysicalBone3D
		PhysicsServer3D.body_add_collision_exception(child.get_rid(), parent_bone.get_rid())
		PhysicsServer3D.body_add_collision_exception(parent_bone.get_rid(), child.get_rid())
	for a_i in range(bones.size()):
		for b_i in range(a_i + 1, bones.size()):
			var ba: PhysicalBone3D = bones[a_i]
			var bb: PhysicalBone3D = bones[b_i]
			PhysicsServer3D.body_add_collision_exception(ba.get_rid(), bb.get_rid())
			PhysicsServer3D.body_add_collision_exception(bb.get_rid(), ba.get_rid())


func _libera_joints_server() -> void:
	for rid in server_joints:
		PhysicsServer3D.free_rid(rid)
	server_joints.clear()


func _ready() -> void:
	_build_floor()
	await _run_scenario("A", false, 0.0, false, false, false, "")
	await _run_scenario("T", false, 0.0, false, false, false, "excepciones")
	print("RESULTADO: %d FALLO(S)" % fallos)
	get_tree().quit(1 if fallos > 0 else 0)


func _run_scenario(id: String, with_impulse: bool, force: float, with_settle: bool, rebake: bool, floor_only: bool, post_fix: String) -> void:
	saw_non_finite = false
	_limpia_zombi()

	zombie = ZOMBIE_SCENE.instantiate()
	zombie.can_debug = false
	add_child(zombie)
	zombie.global_position = Vector3(0, 0.2, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var sim: PhysicalBoneSimulator3D = zombie.ragdoll_component.simulator
	skeleton_ref = sim.get_parent() as Skeleton3D
	_recolecta_huesos(sim)
	_captura_joints()

	var ap: AnimationPlayer = zombie.get_node("ZombiConRig/AnimationPlayer") as AnimationPlayer
	ap.play("walk")
	for i in range(WALK_FRAMES):
		await get_tree().physics_frame

	if with_settle:
		for i in range(SETTLE_FRAMES):
			await get_tree().physics_frame

	if rebake:
		_rebake_joints()
		_captura_joints()

	if floor_only:
		for bone in bones:
			bone.collision_layer = 2
			bone.collision_mask = 1

	belly_sign = signf(_belly_raw())
	if belly_sign == 0.0:
		belly_sign = 1.0

	if id == "A":
		_dump_diagnostico()

	var pre: Dictionary = _mide_actual()
	var pre_dev: Dictionary = _mide_dev()
	var fold_pre: float = _fold_torso()
	print("=== ESCENARIO %s ===" % id)
	_reporta_fase("PRE-START", pre)
	print("  postura pre-start: fold_torso=%.1f° (0°=torso vertical)" % fold_pre)

	var chest: PhysicalBone3D = _busca_hueso("chest")
	var dir: Vector3 = -zombie.global_transform.basis.z
	if with_impulse:
		zombie.ragdoll_component.start(true, dir, force, chest)
	else:
		zombie.ragdoll_component.start(true)

	if post_fix == "params":
		_repusa_params()
		_reset_stats()
		print("  [intervención F: parámetros de joints re-empujados tras activar simulación]")
	elif post_fix == "remake":
		_rebake_joints()
		_captura_joints()
		pre = _mide_actual()
		pre_dev = _mide_dev()
		print("  [intervención G: joints re-creados tras activar simulación (cero = pose actual)]")
	elif post_fix == "server":
		_crear_joints_server()
		_reset_stats()
		print("  [intervención S: joints 6DOF propios por PhysicsServer3D entre los huesos]")
	elif post_fix == "excepciones":
		_agregar_excepciones_huesos()
		print("  [intervención T: excepciones de colisión entre huesos conectados]")

	var start_eul: Dictionary = {}
	var start_dev: Dictionary = {}
	var max_speed: float = 0.0
	for frame in range(RUN_FRAMES):
		await get_tree().physics_frame
		if frame == 0:
			start_eul = _mide_actual()
			start_dev = _mide_dev()
		for bone in bones:
			var vel: Vector3 = bone.linear_velocity
			if not vel.is_finite():
				saw_non_finite = true
				continue
			max_speed = maxf(max_speed, vel.length())
		_acumula_final()
		if not zombie.ragdoll_component.pelvis.global_position.is_finite():
			saw_non_finite = true

	print("  velocidad máxima en simulación=%.2f m/s" % max_speed)
	_reporta_tabla_final(pre, start_eul, start_dev, pre_dev)
	_veredicto(id, rebake, pre, fold_pre, post_fix)


func _limpia_zombi() -> void:
	_libera_joints_server()
	if zombie != null:
		zombie.queue_free()
		zombie = null
		await get_tree().physics_frame
		await get_tree().physics_frame
	bones.clear()
	bone_by_id.clear()
	parent_by_id.clear()
	joints.clear()


func _recolecta_huesos(sim: PhysicalBoneSimulator3D) -> void:
	for child in sim.get_children():
		if child is PhysicalBone3D:
			var bone: PhysicalBone3D = child as PhysicalBone3D
			bones.append(bone)
			bone_by_id[bone.get_bone_id()] = bone
	for bone in bones:
		var bone_id: int = bone.get_bone_id()
		var parent_id: int = skeleton_ref.get_bone_parent(bone_id)
		if bone_by_id.has(parent_id):
			parent_by_id[bone_id] = bone_by_id[parent_id]


func _captura_joints() -> void:
	joints.clear()
	for bone in bones:
		var bone_id: int = bone.get_bone_id()
		if not parent_by_id.has(bone_id):
			continue
		var parent_bone: PhysicalBone3D = parent_by_id[bone_id]
		var frame_b: Transform3D = bone.global_transform * bone.joint_offset
		var local_a: Transform3D = parent_bone.global_transform.affine_inverse() * frame_b
		var limits: Dictionary = {}
		for axis_i in range(3):
			var base: String = "joint_constraints/%s/" % AXES[axis_i]
			var ena_v: Variant = bone.get(base + "angular_limit_enabled")
			var lo_v: Variant = bone.get(base + "angular_limit_lower")
			var hi_v: Variant = bone.get(base + "angular_limit_upper")
			var ena: bool = false
			var lo: float = 0.0
			var hi: float = 0.0
			if typeof(ena_v) == TYPE_BOOL:
				ena = ena_v
			if typeof(lo_v) == TYPE_FLOAT or typeof(lo_v) == TYPE_INT:
				lo = float(lo_v)
			if typeof(hi_v) == TYPE_FLOAT or typeof(hi_v) == TYPE_INT:
				hi = float(hi_v)
			limits[AXES[axis_i]] = {"enabled": ena, "lower": lo, "upper": hi}
		joints.append({
			"child": bone,
			"parent": parent_bone,
			"local_a0": local_a,
			"name": String(skeleton_ref.get_bone_name(bone_id)),
			"limits": limits,
			"maxabs": Vector3.ZERO,
			"devmax": 0.0,
			"fsum": Vector3.ZERO,
			"dsum": 0.0,
			"fn": 0,
		})


func _rebake_joints() -> void:
	for bone in bones:
		var bone_id: int = bone.get_bone_id()
		if not parent_by_id.has(bone_id):
			continue
		var jt: int = bone.joint_type
		if jt == PhysicalBone3D.JOINT_TYPE_NONE:
			continue
		var saved: Dictionary = {}
		for pinfo in bone.get_property_list():
			var pname: String = String(pinfo.get("name", ""))
			if pname.begins_with("joint_constraints/"):
				saved[pname] = bone.get(pname)
		bone.joint_type = PhysicalBone3D.JOINT_TYPE_NONE
		bone.joint_type = jt
		for pname in saved.keys():
			bone.set(pname, saved[pname])


func _rel_basis(j: Dictionary) -> Basis:
	var child: PhysicalBone3D = j["child"] as PhysicalBone3D
	var parent_bone: PhysicalBone3D = j["parent"] as PhysicalBone3D
	var local_a0: Transform3D = j["local_a0"] as Transform3D
	var frame_b: Transform3D = child.global_transform * child.joint_offset
	var frame_a: Transform3D = parent_bone.global_transform * local_a0
	return frame_a.basis.inverse() * frame_b.basis


func _euler_deg(j: Dictionary) -> Vector3:
	var eul: Vector3 = _rel_basis(j).get_euler()
	return Vector3(rad_to_deg(eul.x), rad_to_deg(eul.y), rad_to_deg(eul.z))


func _dev_deg(j: Dictionary) -> float:
	var q: Quaternion = _rel_basis(j).get_rotation_quaternion()
	return rad_to_deg(Quaternion.IDENTITY.angle_to(q))


func _mide_actual() -> Dictionary:
	var out: Dictionary = {}
	for ji in range(joints.size()):
		out[ji] = _euler_deg(joints[ji])
	return out


func _mide_dev() -> Dictionary:
	var out: Dictionary = {}
	for ji in range(joints.size()):
		out[ji] = _dev_deg(joints[ji])
	return out


func _acumula_final() -> void:
	for ji in range(joints.size()):
		var j: Dictionary = joints[ji]
		var eul: Vector3 = _euler_deg(j)
		var dev: float = _dev_deg(j)
		var maxabs: Vector3 = j["maxabs"]
		maxabs.x = maxf(maxabs.x, absf(eul.x))
		maxabs.y = maxf(maxabs.y, absf(eul.y))
		maxabs.z = maxf(maxabs.z, absf(eul.z))
		j["maxabs"] = maxabs
		j["devmax"] = maxf(float(j["devmax"]), dev)
		j["fsum"] = (j["fsum"] as Vector3) + eul
		j["dsum"] = float(j["dsum"]) + dev
		j["fn"] = int(j["fn"]) + 1


func _fuera_de_limites(j: Dictionary, eul: Vector3) -> Array[String]:
	var out: Array[String] = []
	var limits: Dictionary = j["limits"]
	for axis_i in range(3):
		var axis: String = AXES[axis_i]
		var lim: Dictionary = limits[axis]
		if not bool(lim["enabled"]):
			continue
		var ang: float = eul[axis_i]
		var lo: float = float(lim["lower"])
		var hi: float = float(lim["upper"])
		if ang < lo - MARGIN_DEG or ang > hi + MARGIN_DEG:
			out.append("%s=%.1f°[%.0f,%.0f]" % [axis, ang, lo, hi])
	return out


func _reporta_fase(label: String, medicion: Dictionary) -> void:
	var count: int = 0
	for ji in range(joints.size()):
		var j: Dictionary = joints[ji]
		var eul: Vector3 = medicion[ji]
		var fuera: Array[String] = _fuera_de_limites(j, eul)
		if fuera.size() > 0:
			print("  %s  %s: %s  VIOLACIÓN" % [label, j["name"], ", ".join(fuera)])
			count += 1
	if count == 0:
		print("  %s: sin violaciones (margen %.0f°)" % [label, MARGIN_DEG])


func _reporta_tabla_final(pre: Dictionary, start_eul: Dictionary, start_dev: Dictionary, pre_dev: Dictionary) -> void:
	print("  %-18s %9s %9s %9s %9s" % ["joint/eje", "PRE", "START", "MAX", "FINAL"])
	for ji in range(joints.size()):
		var j: Dictionary = joints[ji]
		var nombre: String = j["name"]
		var interesante: bool = false
		for key in KEY_JOINTS:
			if nombre.contains(key):
				interesante = true
				break
		if not interesante:
			continue
		var eul_pre: Vector3 = pre[ji]
		var eul_start: Vector3 = start_eul[ji]
		var maxabs: Vector3 = j["maxabs"]
		var fn: int = int(j["fn"])
		var final_eul: Vector3 = Vector3.ZERO if fn == 0 else (j["fsum"] as Vector3) / float(fn)
		var limits: Dictionary = j["limits"]
		var lim_txt: String = ""
		for axis_i in range(3):
			var lim: Dictionary = limits[AXES[axis_i]]
			if bool(lim["enabled"]):
				lim_txt += "%s[%.0f,%.0f] " % [AXES[axis_i], float(lim["lower"]), float(lim["upper"])]
		print("  %-18s %s" % [nombre, lim_txt])
		for axis_i in range(3):
			print("     %s                  %8.1f° %8.1f° %8.1f° %8.1f°" % [
				AXES[axis_i], eul_pre[axis_i], eul_start[axis_i], maxabs[axis_i], final_eul[axis_i]])
		print("     DEV                %8.1f° %8.1f° %8.1f° %8.1f°" % [
			float(pre_dev[ji]), float(start_dev[ji]), float(j["devmax"]),
			0.0 if fn == 0 else float(j["dsum"]) / float(fn)])
	var final_avg: Dictionary = _final_promedio()
	_reporta_fase("FINAL", final_avg)
	_reporta_dev_final(final_avg)


func _final_promedio() -> Dictionary:
	var out: Dictionary = {}
	for ji in range(joints.size()):
		var j: Dictionary = joints[ji]
		var fn: int = int(j["fn"])
		out[ji] = Vector3.ZERO if fn == 0 else (j["fsum"] as Vector3) / float(fn)
	return out


func _reporta_dev_final(final_avg: Dictionary) -> void:
	var peores: Array[String] = []
	for ji in range(joints.size()):
		var j: Dictionary = joints[ji]
		var fn: int = int(j["fn"])
		var dev_fin: float = 0.0 if fn == 0 else float(j["dsum"]) / float(fn)
		if dev_fin > 40.0:
			peores.append("%s dev_final=%.0f° dev_max=%.0f°" % [j["name"], dev_fin, float(j["devmax"])])
	if peores.size() > 0:
		print("  DEV>40° al reposo: %s" % ", ".join(peores))
	else:
		print("  DEV: ningún joint queda a más de 40° de su cero al reposo")


func _belly_raw() -> float:
	var pelvis: PhysicalBone3D = _busca_hueso("pelvis")
	var chest: PhysicalBone3D = _busca_hueso("chest")
	var tl: PhysicalBone3D = _busca_hueso("thigh_left")
	var tr: PhysicalBone3D = _busca_hueso("thigh_right")
	if pelvis == null or chest == null or tl == null or tr == null:
		return 0.0
	var spine_dir: Vector3 = (chest.global_position - pelvis.global_position).normalized()
	var hip_axis: Vector3 = (tl.global_position - tr.global_position).normalized()
	var n: Vector3 = spine_dir.cross(hip_axis).normalized()
	return n.dot(-zombie.global_transform.basis.z)


func _dump_diagnostico() -> void:
	print("  DIAGNÓSTICO de escala y sincronía (PRE-start):")
	var esc_sk: Vector3 = skeleton_ref.global_transform.basis.get_scale()
	for frag in ["spine", "thigh_left"]:
		var b: PhysicalBone3D = _busca_hueso(frag)
		if b == null:
			continue
		var pose: Transform3D = skeleton_ref.get_bone_global_pose(b.get_bone_id())
		var deseada: Transform3D = (skeleton_ref.global_transform * pose * b.body_offset).orthonormalized()
		var dpos: float = (deseada.origin - b.global_position).length()
		var qd: Quaternion = deseada.basis.get_rotation_quaternion().inverse() * b.global_transform.basis.get_rotation_quaternion()
		var drot: float = rad_to_deg(Quaternion.IDENTITY.angle_to(qd))
		print("    %s: esc_nodo=%s esc_joint_offset=%s esc_body_offset=%s esc_skels=%s | sync dpos=%.1f mm drot=%.1f°" % [
			frag, b.global_transform.basis.get_scale(), b.joint_offset.basis.get_scale(),
			b.body_offset.basis.get_scale(), esc_sk, dpos * 1000.0, drot])


func _fold_torso() -> float:
	var pelvis: PhysicalBone3D = _busca_hueso("pelvis")
	var chest: PhysicalBone3D = _busca_hueso("chest")
	if pelvis == null or chest == null:
		return -1.0
	var dir: Vector3 = (chest.global_position - pelvis.global_position).normalized()
	return rad_to_deg(dir.angle_to(Vector3.UP))


func _veredicto(id: String, rebake: bool, pre: Dictionary, fold_pre: float, post_fix: String) -> void:
	var pelvis: PhysicalBone3D = zombie.ragdoll_component.pelvis
	var chest: PhysicalBone3D = _busca_hueso("chest")
	var neck: PhysicalBone3D = _busca_hueso("neck")
	var thigh_l: PhysicalBone3D = _busca_hueso("thigh_left")
	var thigh_r: PhysicalBone3D = _busca_hueso("thigh_right")
	var fold: float = _fold_torso()
	var head_knee_l: float = -1.0
	var head_knee_r: float = -1.0
	if thigh_l != null and neck != null:
		head_knee_l = neck.global_position.distance_to(thigh_l.global_position)
	if thigh_r != null and neck != null:
		head_knee_r = neck.global_position.distance_to(thigh_r.global_position)
	print("  POSTURA final (cuerpos físicos): fold_torso=%.1f°  chest_y=%.2f  pelvis_y=%.2f  cabeza-rodilla L=%.2f R=%.2f" % [
		fold, chest.global_position.y, pelvis.global_position.y, head_knee_l, head_knee_r])
	var face_metric: float = _belly_raw() * belly_sign
	print("  vientre·UP=%.2f  (+1=cara arriba, -1=cara abajo)" % face_metric)
	var thigh_dev: float = _dev_promedio_thighs()
	print("  desviación media de muslos al reposo=%.1f°" % thigh_dev)

	if saw_non_finite:
		fallos += 1
		print("  FALLA  NaN/infinitos detectados")
	if id == "A" or id == "B" or id == "E":
		if fold > FOLD_STANDING_MAX:
			fallos += 1
			print("  FALLA  plegado reproducido (fold=%.1f° > %.0f°)" % [fold, FOLD_STANDING_MAX])
		if face_metric < -0.5:
			fallos += 1
			print("  FALLA  caída boca abajo (vientre·UP=%.2f)" % face_metric)
		if thigh_dev > 60.0:
			fallos += 1
			print("  FALLA  piernas retorcidas fuera de límites (dev muslos=%.1f° > 60°)" % thigh_dev)
		if fold <= FOLD_STANDING_MAX and face_metric >= -0.5 and thigh_dev <= 60.0:
			print("  OK     sin plegado, de cara arriba y piernas dentro de límites")
	if rebake:
		var violaciones_pre: int = 0
		for ji in range(joints.size()):
			if _fuera_de_limites(joints[ji], pre[ji]).size() > 0:
				violaciones_pre += 1
		if violaciones_pre > 0:
			fallos += 1
			print("  FALLA  re-bake no eliminó la violación inicial (%d joints)" % violaciones_pre)
		else:
			print("  OK     re-bake: violación inicial eliminada (pre fold=%.1f°)" % fold_pre)
	if post_fix != "":
		var final_avg: Dictionary = _final_promedio()
		var viol: int = 0
		for ji in range(joints.size()):
			var nombre: String = joints[ji]["name"]
			if nombre.contains("spine") or nombre.contains("chest") or nombre.contains("neck") or nombre.contains("thigh"):
				if _fuera_de_limites(joints[ji], final_avg[ji]).size() > 0:
					viol += 1
		if viol > 0 or thigh_dev > 60.0:
			fallos += 1
			print("  FALLA  la intervención no restauró los límites (%d joints clave fuera, dev muslos=%.1f°)" % [
				viol, thigh_dev])
		else:
			print("  OK     límites respetados tras la intervención")


func _repusa_params() -> void:
	for bone in bones:
		var bone_id: int = bone.get_bone_id()
		if not parent_by_id.has(bone_id):
			continue
		for pinfo in bone.get_property_list():
			var pname: String = String(pinfo.get("name", ""))
			if pname.begins_with("joint_constraints/"):
				bone.set(pname, bone.get(pname))


func _reset_stats() -> void:
	for j in joints:
		j["maxabs"] = Vector3.ZERO
		j["devmax"] = 0.0
		j["fsum"] = Vector3.ZERO
		j["dsum"] = 0.0
		j["fn"] = 0


func _dev_promedio_thighs() -> float:
	var suma: float = 0.0
	var n: int = 0
	for j in joints:
		var nombre: String = j["name"]
		if nombre.contains("thigh"):
			var fn: int = int(j["fn"])
			if fn > 0:
				suma += float(j["dsum"]) / float(fn)
				n += 1
	if n == 0:
		return 0.0
	return suma / float(n)


func _busca_hueso(fragmento: String) -> PhysicalBone3D:
	for bone in bones:
		if skeleton_ref.get_bone_name(bone.get_bone_id()).contains(fragmento):
			return bone
	return null


func _build_floor() -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	cs.shape = box
	cs.position = Vector3(0, -0.5, 0)
	body.add_child(cs)
	add_child(body)
