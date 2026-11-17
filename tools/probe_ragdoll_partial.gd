extends Node3D
## Sonda de regresión del ragdoll parcial (bug "el ragdoll se va a la estratosfera").
##
## Replica exactamente lo que hace el botón "Reiniciar simulación" del wizard
## de RagdollDebug, en dos escenarios:
##   - Zombi A: todos los huesos marcados EXCEPTO la pelvis.
##     (La pelvis queda sin simular: KINEMATIC, anclada a la pose de animación.)
##   - Zombi B: solo la pelvis marcada (equivalente al ragdoll completo,
##     porque la pelvis es la raíz del árbol de huesos físicos).
##
## Antes del fix, el zombi A ascendía sin límite (~+0.9 m por frame) porque
## `ragdoll_component._physics_process` teleportaba el CharacterBody3D a la
## posición de la pelvis, que a su vez se teletransportaba a la pose de
## reposo relativa al esqueleto: realimentación positiva body → pelvis → body.
##
## Uso: godot --headless --path . res://tools/probe_ragdoll_partial.tscn

const ZOMBIE_SCENE := preload("res://scenes/zombies/zombie.tscn")

const FRAMES: int = 360
const REPORT_EVERY: int = 60
const MAX_PELVIS_RISE: float = 0.5
## Límite de velocidad de hueso: calibrado contra el ragdoll COMPLETO sano
## (escenario B, caída desde 2 m), que mide 11.7 m/s en el impacto. El umbral
## anterior (8.0) estaba por debajo de ese baseline y marcaba FALLA en una
## simulación que no explota. 12.0 sigue acotando la "estratosfera" (antes
## v≈280 m/s en frame 1) con margen sobre el baseline sano.
const MAX_BONE_SPEED: float = 12.0
const MAX_STRETCH: float = 0.5
const B_MAX_PELVIS_Y: float = 0.7

var fallos: int = 0
var zombie_a: Zombie = null
var zombie_b: Zombie = null
var sim_a: PhysicalBoneSimulator3D = null
var sim_b: PhysicalBoneSimulator3D = null
var pelvis_a: PhysicalBone3D = null
var pelvis_b: PhysicalBone3D = null
var spine_a: PhysicalBone3D = null
var spine_b: PhysicalBone3D = null
var rest_separation: Dictionary = {}
var rest_separation_b: Dictionary = {}
var bones_a: Array[PhysicalBone3D] = []
var bones_b: Array[PhysicalBone3D] = []
var max_rise: float = 0.0
var max_speed_a: float = 0.0
var max_speed_b: float = 0.0
var max_stretch_a: float = 0.0
var max_stretch_b: float = 0.0
var pelvis_a_start_y: float = 0.0
var _bone_physics_backup: Dictionary = {}


func ok(cond: bool, msg: String) -> void:
	if cond:
		print("  OK   ", msg)
	else:
		fallos += 1
		print("  FALLA ", msg)


func _ready() -> void:
	_build_floor()

	zombie_a = ZOMBIE_SCENE.instantiate() as Zombie
	zombie_a.can_debug = false
	add_child(zombie_a)
	zombie_a.global_position = Vector3(-3.0, 2.0, 0.0)

	zombie_b = ZOMBIE_SCENE.instantiate() as Zombie
	zombie_b.can_debug = false
	add_child(zombie_b)
	zombie_b.global_position = Vector3(3.0, 2.0, 0.0)

	# Igual que _on_restart_simulation (RagdollDebug): dar tiempo a que la pose
	# se asiente antes de arrancar. Con 1 frame el joint inyecta un golpe
	# (v≈280 m/s en spine); con 10 frames la caída es estable (v≈1.7 m/s).
	for _i in range(10):
		await get_tree().physics_frame

	sim_a = zombie_a.ragdoll_component.simulator
	sim_b = zombie_b.ragdoll_component.simulator

	var names_a: Array[StringName] = []
	var pelvis_name: StringName = &""
	for child in sim_a.get_children():
		if child is PhysicalBone3D:
			var bone: PhysicalBone3D = child as PhysicalBone3D
			bones_a.append(bone)
			names_a.append(bone.bone_name)
			if bone.bone_name == &"pelvis":
				pelvis_name = bone.bone_name

	names_a.erase(pelvis_name)
	print("=== Zombi A: simulando %d huesos (todos menos pelvis) ===" % names_a.size())
	print("    nombres: %s" % ", ".join(names_a))

	pelvis_a = _find_bone(sim_a, &"pelvis")
	spine_a = _find_bone(sim_a, &"spine")

	sim_a.physical_bones_stop_simulation()
	sim_a.physical_bones_start_simulation(names_a)
	_ghost_unselected_bones()
	zombie_a.ragdoll_component.is_ragdoll = true
	zombie_a.ragdoll_component.permanent = true
	pelvis_a_start_y = pelvis_a.global_position.y

	print("=== Zombi B: simulando solo pelvis ===")
	pelvis_b = _find_bone(sim_b, &"pelvis")
	spine_b = _find_bone(sim_b, &"spine")
	for child in sim_b.get_children():
		if child is PhysicalBone3D:
			bones_b.append(child as PhysicalBone3D)

	sim_b.physical_bones_stop_simulation()
	sim_b.physical_bones_start_simulation([&"pelvis"])
	_ghost_unselected_bones()
	zombie_b.ragdoll_component.is_ragdoll = true
	zombie_b.ragdoll_component.permanent = true

	# Separaciones en reposo (una vez arrancada la simulación, antes de que se mueva nada).
	var skeleton_a: Skeleton3D = sim_a.get_parent() as Skeleton3D
	var skeleton_b: Skeleton3D = sim_b.get_parent() as Skeleton3D
	rest_separation = _collect_rest_separations(sim_a, skeleton_a)
	rest_separation_b = _collect_rest_separations(sim_b, skeleton_b)

	var t: float = 0.0
	for frame in range(FRAMES):
		await get_tree().physics_frame
		t = float(frame + 1) / 60.0
		_track(bones_a, rest_separation, false)
		_track(bones_b, rest_separation_b, true)
		max_rise = maxf(max_rise, pelvis_a.global_position.y - pelvis_a_start_y)
		if (frame + 1) % REPORT_EVERY == 0 or frame < 3:
			_report(frame + 1, t)

	print("=== Resultado final ===")
	print("  A: subida máx pelvis=%.3f  vel máx=%.3f  estir. máx=%.3f" % [
		max_rise, max_speed_a, max_stretch_a])
	print("  B: vel máx=%.3f  estir. máx=%.3f  pelvis final y=%.3f" % [
		max_speed_b, max_stretch_b, pelvis_b.global_position.y])

	ok(not _has_non_finite(bones_a), "A: sin NaN/infinitos")
	ok(not _has_non_finite(bones_b), "B: sin NaN/infinitos")
	ok(not pelvis_a.is_simulating_physics(), "A: la pelvis quedó sin simular (bug reproducible)")
	ok(pelvis_b.is_simulating_physics(), "B: la pelvis simula (raíz → ragdoll completo)")
	ok(max_rise < MAX_PELVIS_RISE,
		"A: la pelvis no asciende (máx %.3f < %.3f m sobre su y inicial %.2f)" % [
			max_rise, MAX_PELVIS_RISE, pelvis_a_start_y])
	ok(max_speed_a < MAX_BONE_SPEED,
		"A: sin explosión de velocidades (máx %.3f < %.3f m/s)" % [max_speed_a, MAX_BONE_SPEED])
	ok(max_stretch_a < MAX_STRETCH,
		"A: joints sin estirarse (máx %.3f < %.3f)" % [max_stretch_a, MAX_STRETCH])
	ok(max_stretch_b < MAX_STRETCH,
		"B: joints sin estirarse (máx %.3f < %.3f)" % [max_stretch_b, MAX_STRETCH])
	ok(pelvis_b.global_position.y < B_MAX_PELVIS_Y,
		"B: el ragdoll cayó al piso (pelvis y=%.3f < %.3f)" % [pelvis_b.global_position.y, B_MAX_PELVIS_Y])

	if fallos == 0:
		print("RESULTADO: TODO OK")
	else:
		print("RESULTADO: %d FALLO(S)" % fallos)
	get_tree().quit(1 if fallos > 0 else 0)


## Espejo de RagdollDebug._ghost_unselected_bones (misma semántica que el wizard).
func _ghost_unselected_bones() -> void:
	for bone in bones_a + bones_b:
		if not _bone_physics_backup.has(bone):
			_bone_physics_backup[bone] = [bone.collision_layer, bone.collision_mask]
		if bone.is_simulating_physics():
			var backup: Array = _bone_physics_backup[bone]
			bone.collision_layer = int(backup[0])
			bone.collision_mask = int(backup[1])
		else:
			bone.collision_layer = 0
			bone.collision_mask = 0


func _find_bone(sim: PhysicalBoneSimulator3D, bone_name: StringName) -> PhysicalBone3D:
	for child in sim.get_children():
		if child is PhysicalBone3D and child.bone_name == bone_name:
			return child as PhysicalBone3D
	return null


func _collect_rest_separations(sim: PhysicalBoneSimulator3D, skeleton: Skeleton3D) -> Dictionary:
	var separations: Dictionary = {}
	for child in sim.get_children():
		if not child is PhysicalBone3D:
			continue
		var bone: PhysicalBone3D = child as PhysicalBone3D
		var bone_id: int = bone.get_bone_id()
		var parent_id: int = skeleton.get_bone_parent(bone_id)
		if parent_id < 0:
			continue
		var parent_bone: PhysicalBone3D = null
		for sibling in sim.get_children():
			if sibling is PhysicalBone3D and (sibling as PhysicalBone3D).get_bone_id() == parent_id:
				parent_bone = sibling as PhysicalBone3D
				break
		if parent_bone == null:
			continue
		separations[bone_id] = bone.global_position.distance_to(parent_bone.global_position)
	return separations


func _track(bones: Array[PhysicalBone3D], rest_separation: Dictionary, is_b: bool) -> void:
	for bone in bones:
		var vel: Vector3 = bone.linear_velocity
		if not vel.is_finite():
			continue
		var speed: float = vel.length()
		if is_b:
			max_speed_b = maxf(max_speed_b, speed)
		else:
			max_speed_a = maxf(max_speed_a, speed)

	for bone in bones:
		var bone_id: int = bone.get_bone_id()
		if not rest_separation.has(bone_id):
			continue
		var parent_bone: PhysicalBone3D = null
		for sibling in sim_bone_parent(bone, bones):
			parent_bone = sibling
			break
		if parent_bone == null:
			continue
		var stretch: float = absf(
			bone.global_position.distance_to(parent_bone.global_position) - float(rest_separation[bone_id]))
		if is_b:
			max_stretch_b = maxf(max_stretch_b, stretch)
		else:
			max_stretch_a = maxf(max_stretch_a, stretch)


func sim_bone_parent(bone: PhysicalBone3D, bones: Array[PhysicalBone3D]) -> Array[PhysicalBone3D]:
	var result: Array[PhysicalBone3D] = []
	var skeleton: Skeleton3D = null
	if bone.get_parent() is PhysicalBoneSimulator3D:
		skeleton = (bone.get_parent() as PhysicalBoneSimulator3D).get_parent() as Skeleton3D
	if skeleton == null:
		return result
	var parent_id: int = skeleton.get_bone_parent(bone.get_bone_id())
	for other in bones:
		if other.get_bone_id() == parent_id:
			result.append(other)
			break
	return result


func _has_non_finite(bones: Array[PhysicalBone3D]) -> bool:
	for bone in bones:
		if not bone.global_position.is_finite() or not bone.linear_velocity.is_finite():
			return true
	return false


func _report(frame: int, t: float) -> void:
	var pa: String = _pos_str(pelvis_a)
	var sa: String = _pos_str(spine_a)
	var pb: String = _pos_str(pelvis_b)
	var sb: String = _pos_str(spine_b)
	var body_a: String = "%.2f,%.2f,%.2f" % [zombie_a.global_position.x, zombie_a.global_position.y, zombie_a.global_position.z]
	var body_b: String = "%.2f,%.2f,%.2f" % [zombie_b.global_position.x, zombie_b.global_position.y, zombie_b.global_position.z]
	var vel_a: float = spine_a.linear_velocity.length() if spine_a != null else -1.0
	var vel_b: float = spine_b.linear_velocity.length() if spine_b != null else -1.0
	print("f=%d t=%.2f | A pelvis=%s spine=%s v=%.2f body=%s | B pelvis=%s spine=%s v=%.2f body=%s" % [
		frame, t, pa, sa, vel_a, body_a, pb, sb, vel_b, body_b])


func _pos_str(bone: PhysicalBone3D) -> String:
	if bone == null:
		return "?"
	var p: Vector3 = bone.global_position
	if not p.is_finite():
		return "INF/NAN"
	return "(%.2f,%.2f,%.2f)" % [p.x, p.y, p.z]


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
