extends Node3D
## Sonda numérica del ragdoll del zombi.
##
## Instancia `zombie.tscn`, lo suelta desde 2 m y arranca el ragdoll en modo
## permanente. Durante 5 s (300 frames de física) mide:
##   - posición del pelvis y altura,
##   - velocidad máxima de cualquier PhysicalBone3D,
##   - separación máxima entre huesos conectados (padre/hijo del Skeleton3D),
##   - NaN/infinitos.
## Al final imprime la pose de huesos clave y falla si el ragdoll explotó,
## atravesó el piso o no se estabilizó.
##
## Uso: godot --headless --path . res://tools/probe_ragdoll_behavior.tscn

const ZOMBIE_SCENE := preload("res://scenes/zombies/zombie.tscn")

const FRAMES: int = 300
const REPORT_EVERY: int = 60
const MAX_SPEED_LIMIT: float = 3.0
const MAX_STRETCH_LIMIT: float = 0.2
const MIN_PELVIS_Y: float = -0.25
const MAX_PELVIS_Y: float = 1.5

var fallos: int = 0
var bones: Array[PhysicalBone3D] = []
var bone_by_id: Dictionary = {}
var parent_by_id: Dictionary = {}
var rest_separation: Dictionary = {}
var skeleton_ref: Skeleton3D = null
var max_speed: float = 0.0
var max_stretch: float = 0.0
var max_stretch_pair: String = ""
var saw_non_finite: bool = false
var zombie: Zombie = null


func ok(cond: bool, msg: String) -> void:
	if cond:
		print("  OK   ", msg)
	else:
		fallos += 1
		print("  FALLA ", msg)


func _ready() -> void:
	_build_floor()
	zombie = ZOMBIE_SCENE.instantiate()
	zombie.can_debug = false
	add_child(zombie)
	zombie.global_position = Vector3(0, 2, 0)

	await get_tree().physics_frame

	var sim: PhysicalBoneSimulator3D = zombie.ragdoll_component.simulator
	var skeleton: Skeleton3D = sim.get_parent() as Skeleton3D
	_collect_bones(sim, skeleton)

	print("=== Ragdoll: %d huesos, %d joints ===" % [bones.size(), rest_separation.size()])
	zombie.ragdoll_component.start(true)

	for frame in range(FRAMES):
		await get_tree().physics_frame
		_sample(frame)
		if (frame + 1) % REPORT_EVERY == 0:
			_print_report(frame + 1)

	_check_final()
	get_tree().quit(1 if fallos > 0 else 0)


func _collect_bones(sim: PhysicalBoneSimulator3D, skeleton: Skeleton3D) -> void:
	skeleton_ref = skeleton
	for child in sim.get_children():
		if child is PhysicalBone3D:
			var bone: PhysicalBone3D = child as PhysicalBone3D
			bones.append(bone)
			bone_by_id[bone.get_bone_id()] = bone

	for bone in bones:
		var bone_id: int = bone.get_bone_id()
		var parent_id: int = skeleton.get_bone_parent(bone_id)
		if not bone_by_id.has(parent_id):
			continue
		var parent_bone: PhysicalBone3D = bone_by_id[parent_id]
		parent_by_id[bone_id] = parent_bone
		rest_separation[bone_id] = bone.global_position.distance_to(parent_bone.global_position)


func _sample(frame: int) -> void:
	var pelvis: PhysicalBone3D = zombie.ragdoll_component.pelvis
	if not pelvis.global_position.is_finite():
		saw_non_finite = true

	for bone in bones:
		var vel: Vector3 = bone.linear_velocity
		var pos: Vector3 = bone.global_position
		if not vel.is_finite() or not pos.is_finite():
			saw_non_finite = true
			continue
		max_speed = maxf(max_speed, vel.length())

	for bone in bones:
		var bone_id: int = bone.get_bone_id()
		if not parent_by_id.has(bone_id):
			continue
		var parent_bone: PhysicalBone3D = parent_by_id[bone_id]
		var separation: float = bone.global_position.distance_to(parent_bone.global_position)
		var stretch: float = absf(separation - float(rest_separation[bone_id]))
		if stretch > max_stretch:
			max_stretch = stretch
			max_stretch_pair = "%s/%s" % [_bone_label(parent_bone), _bone_label(bone)]

	if frame == 0:
		print("  t=0.00  pelvis_y=%.3f  max_speed=%.3f  max_stretch=%.3f" % [
			pelvis.global_position.y, max_speed, max_stretch])


func _print_report(frame: int) -> void:
	var pelvis: PhysicalBone3D = zombie.ragdoll_component.pelvis
	var t: float = float(frame) / 60.0
	print("  t=%.2f  pelvis=(%.3f, %.3f, %.3f)  max_speed=%.3f  max_stretch=%.3f (%s)" % [
		t, pelvis.global_position.x, pelvis.global_position.y, pelvis.global_position.z,
		max_speed, max_stretch, max_stretch_pair])


func _check_final() -> void:
	var pelvis: PhysicalBone3D = zombie.ragdoll_component.pelvis
	var final_speed: float = 0.0
	var final_stretch: float = 0.0
	var final_stretch_pair: String = ""
	var final_max_y: float = -INF
	var final_min_y: float = INF

	for bone in bones:
		var vel: Vector3 = bone.linear_velocity
		var pos: Vector3 = bone.global_position
		if not vel.is_finite() or not pos.is_finite():
			saw_non_finite = true
			continue
		final_speed = maxf(final_speed, vel.length())
		final_max_y = maxf(final_max_y, pos.y)
		final_min_y = minf(final_min_y, pos.y)

	for bone in bones:
		var bone_id: int = bone.get_bone_id()
		if not parent_by_id.has(bone_id):
			continue
		var parent_bone: PhysicalBone3D = parent_by_id[bone_id]
		var separation: float = bone.global_position.distance_to(parent_bone.global_position)
		var stretch: float = absf(separation - float(rest_separation[bone_id]))
		if stretch > final_stretch:
			final_stretch = stretch
			final_stretch_pair = "%s/%s" % [_bone_label(parent_bone), _bone_label(bone)]

	print("=== Resultado final ===")
	print("  pelvis=(%.3f, %.3f, %.3f)" % [
		pelvis.global_position.x, pelvis.global_position.y, pelvis.global_position.z])
	print("  velocidad final=%.3f  estiramiento final=%.3f (%s)" % [
		final_speed, final_stretch, final_stretch_pair])
	print("  rango Y de huesos=[%.3f, %.3f]" % [final_min_y, final_max_y])
	print("  velocidad máxima histórica=%.3f  estiramiento máximo histórico=%.3f (%s)" % [
		max_speed, max_stretch, max_stretch_pair])

	ok(not saw_non_finite, "no hay NaN/infinitos")
	ok(pelvis.global_position.y > MIN_PELVIS_Y and pelvis.global_position.y < MAX_PELVIS_Y,
		"pelvis dentro del rango vertical (y=%.3f)" % pelvis.global_position.y)
	ok(final_speed < MAX_SPEED_LIMIT, "ragdoll estabilizado (vel=%.3f < %.3f)" % [
		final_speed, MAX_SPEED_LIMIT])
	ok(final_stretch < MAX_STRETCH_LIMIT, "joints sin estirarse (stretch=%.3f < %.3f)" % [
		final_stretch, MAX_STRETCH_LIMIT])
	ok(max_stretch < 0.5, "sin explosión de joints (máx=%.3f < 0.5)" % max_stretch)
	ok(final_min_y > -0.5, "ningún hueso atravesó el piso (y mínima=%.3f)" % final_min_y)

	if fallos == 0:
		print("RESULTADO: TODO OK")
	else:
		print("RESULTADO: %d FALLO(S)" % fallos)


func _bone_label(bone: PhysicalBone3D) -> String:
	return skeleton_ref.get_bone_name(bone.get_bone_id())


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
