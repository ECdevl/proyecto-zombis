class_name FlashlightController extends Node
## Dueño exclusivo de la linterna de mano: estado on/off, rig óseo y modelo.
## Antes vivía dentro de WeaponController, que tenía que avisar a mano desde
## tres sitios y compartía el toggle con el Player (origen de E-022).
## Acá se suscribe a lo que le afecta: manos y viewmodel visible.

var player: Player

var _attachment: BoneAttachment3D
var _instance: Node3D
var _light: SpotLight3D
var _on: bool = false
var _rig_skeleton: Skeleton3D
var _custom_nodes: Array[Node] = []


func _ready() -> void:
	player = owner as Player
	if player == null:
		push_error("FlashlightController: el owner debe ser Player")
		return
	if player.inventory != null and player.inventory.hands != null:
		player.inventory.hands.changed.connect(_on_hands_changed)
	player.weapon_changed.connect(_on_weapon_changed)
	# El animador de armsy se configura en Player._ready(), que corre después
	# del _ready() de este hijo. Diferir el primer refresco evita perder la capa.
	call_deferred("_refresh")


func toggle_flashlight() -> void:
	if _equipped_flashlight() == null:
		return
	_on = not _on
	if is_instance_valid(_light):
		_light.visible = _on


## Se acepta cualquiera de las dos manos: HandsModel permite sostener la
## linterna a la derecha, así que no puede quedarse sin efecto. El anclaje
## visual sigue siendo el hueso de la mano izquierda del viewmodel.
func _equipped_flashlight() -> ItemInstance:
	if player == null or player.inventory == null or player.inventory.hands == null:
		return null
	for hand in [HandsModel.Hand.LEFT, HandsModel.Hand.RIGHT]:
		var item: ItemInstance = player.inventory.hands.get_held(hand)
		if item != null and item.descriptor is FlashlightDescriptor:
			return item
	return null


func _on_hands_changed() -> void:
	_refresh()


func _on_weapon_changed(_gun: EquippableDescriptor) -> void:
	# Cambiar de arma cambia el viewmodel y con él el esqueleto al que anclarse.
	_refresh()


func _get_skeleton() -> Skeleton3D:
	if is_instance_valid(player.current_viewmodel):
		var sk: Skeleton3D = SkeletonUtils.find_arm_skeleton(player.current_viewmodel)
		if sk != null:
			return sk
	if is_instance_valid(player.armsy):
		return player.armsy.get_node_or_null("rig/Skeleton3D") as Skeleton3D
	return null


func _refresh() -> void:
	var item: ItemInstance = _equipped_flashlight()
	if item == null:
		_teardown_rig()
		_on = false
		_set_context_weight(0.0)
		return
	var skeleton: Skeleton3D = _get_skeleton()
	if skeleton == null:
		_teardown_rig()
		_on = false
		_set_context_weight(0.0)
		return
	if skeleton != _rig_skeleton:
		_build_rig(skeleton)
	if _attachment == null:
		return
	_ensure_instance(item.descriptor as FlashlightDescriptor)
	_attachment.visible = true
	_set_context_weight(1.0)


func _set_context_weight(weight: float) -> void:
	if is_instance_valid(player.viewmodel_animator):
		player.viewmodel_animator.set_context(&"ctx_flashlight", weight)
	if player.arms_animator != null:
		player.arms_animator.set_context(&"ctx_flashlight", weight)

func _build_rig(skeleton: Skeleton3D) -> void:
	_teardown_rig()
	var bones: Dictionary = SkeletonUtils.find_arm_bones(skeleton)
	if bones.is_empty():
		return
	# Se marca como construido solo si hay attachment: si el esqueleto no tenía
	# brazo izquierdo, un intento posterior con otro esqueleto debe reconstruir.
	_rig_skeleton = skeleton
	var pivot: Node3D = Node3D.new()
	_attachment = BoneAttachment3D.new()
	_attachment.name = "FlashlightAttachment"
	_attachment.bone_name = bones["end_name"]
	skeleton.add_child(_attachment)
	_attachment.add_child(pivot)
	_custom_nodes.append(_attachment)


func _teardown_rig() -> void:
	if is_instance_valid(_instance):
		_instance.queue_free()
	_instance = null
	_light = null
	for n in _custom_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_custom_nodes.clear()
	_attachment = null
	_rig_skeleton = null


func _ensure_instance(descriptor: FlashlightDescriptor) -> void:
	if descriptor == null or descriptor.held_scene == null:
		return
	if is_instance_valid(_instance):
		return
	_instance = descriptor.held_scene.instantiate() as Node3D
	if _instance == null:
		return
	var pivot: Node = _attachment.get_child(0)
	pivot.add_child(_instance)
	pivot.position = descriptor.hand_offset
	pivot.rotation = descriptor.hand_rot
	if is_instance_valid(_rig_skeleton):
		var sc: Vector3 = _rig_skeleton.global_transform.basis.get_scale().abs()
		if sc.x > 0.0001 and sc.y > 0.0001 and sc.z > 0.0001:
			_instance.scale = _instance.scale / sc
	_light = _instance.find_child("SpotLight3D", true, false) as SpotLight3D
	if _light == null:
		_light = SpotLight3D.new()
		_light.name = "FlashlightLight"
		_instance.add_child(_light)
		_light.shadow_caster_mask = descriptor.caster_mask
		_light.position = Vector3.ZERO
		_light.light_energy = descriptor.light_energy
		_light.spot_range = descriptor.spot_range
		_light.spot_angle = descriptor.spot_angle
		_light.shadow_enabled = descriptor.shadow_enabled
	_light.visible = _on
