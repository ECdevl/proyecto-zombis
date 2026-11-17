extends Node3D
## Sonda de bullet holes (T-017): en zombi pegado al hueso, en mundo icono
## placeholder (fijo), y el rayo atraviesa pickups.
##
##   1) Tiro a zombi → decal blood en el hueso, padriño = BoneAttachment.
##   2) El zombi se mueve 5 m → el decal del hueso se mueve con él (pegado).
##   3) Tiro al piso sin zombi → decal icono de Godot en el punto de impacto.
##   4) Pickup en Capa 1 delante del zombi → el rayo lo atraviesa y aun
##      hay agujero en el zombi.
##
## Uso: godot --headless --path . res://tools/probe_bullet_hole.tscn

const ZOMBIE_SCENE: PackedScene = preload("res://scenes/zombies/zombie.tscn")
const PROJECTILE_SCENE: PackedScene = preload("res://scenes/weapons/projectile.tscn")
const PICKABLE_SCENE: PackedScene = preload("res://scenes/components/pickable_object.tscn")
const MACHETE := preload("res://resources/weapons/melee/machete.tres")
const BLOOD_TEX: Texture2D = preload("res://assets/sprites/blood_particle.png")
const ICON_TEX: Texture2D = preload("res://icon.svg")

var fallos: int = 0
var _camera: Camera3D = null


func ok(cond: bool, msg: String) -> void:
	if cond:
		print("  OK   ", msg)
	else:
		fallos += 1
		print("  FALLA ", msg)


func _ready() -> void:
	_build_floor()
	_camera = Camera3D.new()
	_camera.position = Vector3(0, 1.5, 0)
	_camera.rotation = Vector3.ZERO
	add_child(_camera)
	_camera.current = true
	_camera.fov = 70.0

	print("=== 1) Tiro a zombi: agujero pegado al hueso ===")
	var c1: Dictionary = await _fire_at_zombie(false)
	ok(int(c1.get("blood_holes", 0)) >= 1, "hay agujero blood en el hueso (%d)" % int(c1.get("blood_holes", 0)))
	ok(int(c1.get("on_bone", 0)) == 1, "el agujero es hijo del BoneAttachment (padriño = %s)" % str(c1.get("parent_kind", "?")))

	print("=== 2) Se mueve: el agujero acompaña al zombi ===")
	var moved: float = float(c1.get("moved", 0.0))
	ok(moved > 4.5, "el agujero se movió %.2f m con el zombi" % moved)

	print("=== 3) Tiro al mundo: icono placeholder ===")
	var c2: Dictionary = await _fire_at_floor()
	ok(int(c2.get("icon_holes", 0)) >= 1, "hay agujero icono en el mundo (%d)" % int(c2.get("icon_holes", 0)))
	ok(int(c2.get("wood_holes", 0)) == 0, "ya no hay agujero blood en el mundo (%d)" % int(c2.get("wood_holes", 0)))

	print("=== 4) Pickup en Capa 1 delante: el rayo lo atraviesa ===")
	var c3: Dictionary = await _fire_at_zombie(true)
	ok(int(c3.get("blood_holes", 0)) >= 1, "sigue habiendo agujero en el zombi (%d)" % int(c3.get("blood_holes", 0)))

	if fallos == 0:
		print("RESULTADO: TODO OK")
	else:
		print("RESULTADO: %d FALLO(S)" % fallos)
	get_tree().quit(1 if fallos > 0 else 0)


func _find_decals(tex: Texture2D) -> Array[Decal]:
	var list: Array[Decal] = []
	for node: Node in get_tree().current_scene.find_children("*", "Decal", true, false):
		var d: Decal = node as Decal
		if d != null and d.texture_albedo == tex:
			list.append(d)
	return list


func _fire_at_zombie(with_pickup: bool) -> Dictionary:
	var z: Zombie = ZOMBIE_SCENE.instantiate()
	add_child(z)
	z.global_position = Vector3(0, 0.9, -3.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if with_pickup:
		var pick: PickableItem = PICKABLE_SCENE.instantiate()
		pick.item_descriptor = MACHETE
		add_child(pick)
		pick.global_position = Vector3(0, 1.9, -1.5)
		pick.collision_layer = 1
	# Cámara mira a -Z hacia la cabeza del zombi.
	_camera.look_at(Vector3(0, 1.9, -3.0), Vector3.UP)
	var proj: Node = PROJECTILE_SCENE.instantiate()
	add_child(proj)
	proj.global_position = _camera.global_position
	proj.set_projectile(10.0, 50.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	var blood_holes: Array[Decal] = _find_decals(BLOOD_TEX)
	var on_bone: int = 0
	var parent_kind: String = "null"
	var before: Vector3 = Vector3.ZERO
	if not blood_holes.is_empty():
		var d: Decal = blood_holes[0]
		before = d.global_position
		if d.get_parent() is BoneAttachment3D:
			on_bone = 1
		parent_kind = d.get_parent().get_class() if d.get_parent() != null else "null"
	# Se mueve 5 m en +X: el decal pegado debe acompañar.
	z.global_position = Vector3(5.0, 0.9, -3.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var moved: float = 0.0
	if not blood_holes.is_empty():
		moved = blood_holes[0].global_position.distance_to(before)
	var result: Dictionary = {"blood_holes": blood_holes.size(), "on_bone": on_bone, "parent_kind": parent_kind, "moved": moved}
	z.queue_free()
	_cleanup()
	await get_tree().physics_frame
	return result


func _fire_at_floor() -> Dictionary:
	# Sin zombi: el rayo mira al piso (normal UP).
	_camera.look_at(Vector3(0, 0.0, -3.0), Vector3.UP)
	var proj: Node = PROJECTILE_SCENE.instantiate()
	add_child(proj)
	proj.global_position = _camera.global_position
	proj.set_projectile(10.0, 50.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	var result: Dictionary = {"icon_holes": _find_decals(ICON_TEX).size(), "wood_holes": _find_decals(BLOOD_TEX).size()}
	_cleanup()
	await get_tree().physics_frame
	return result


func _cleanup() -> void:
	for node: Node in get_tree().current_scene.find_children("*", "Decal", true, false):
		node.queue_free()
	for pick: Node in get_tree().current_scene.find_children("*", "PickableItem", true, false):
		pick.queue_free()


func _build_floor() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	cs.shape = box
	cs.position = Vector3(0, -0.5, 0)
	body.add_child(cs)
	add_child(body)
