extends SceneTree
## Sonda de runtime para el refactor de la linterna: jerarquía HoldableDescriptor,
## FlashlightController, armsy animado y capa ctx_flashlight con/sin arma.

var fallos: int = 0


func ok(cond: bool, msg: String) -> void:
	if cond:
		print("  OK   ", msg)
	else:
		fallos += 1
		print("  FALLA ", msg)


func _initialize() -> void:
	var desc: FlashlightDescriptor = load("res://resources/items/linterna.tres") as FlashlightDescriptor
	ok(desc != null, "linterna.tres es FlashlightDescriptor")
	ok(desc is HoldableDescriptor, "FlashlightDescriptor extiende HoldableDescriptor")
	ok(not (desc as ItemDescriptor is EquippableDescriptor), "FlashlightDescriptor NO es EquippableDescriptor")
	ok(desc.get_hands_required() == 1, "get_hands_required() == 1")
	ok(desc.get_actions().has("equipar"), "get_actions() incluye 'equipar'")

	var packed: PackedScene = load("res://scenes/debug/test.tscn")
	var root: Node = packed.instantiate()
	get_root().add_child(root)
	await process_frame
	await process_frame

	var player: Variant = null
	for n in _todos(root):
		if n is Player:
			player = n
			break
	ok(player != null, "se encontró el Player")
	if player == null:
		quit(1)
		return

	var ctrl: Variant = player.flashlight_controller
	ok(ctrl != null, "Player tiene FlashlightController (%FlashlightController)")
	ok(player.arms_animator != null, "Player tiene ArmsAnimator")
	ok(player.animation_tree.active, "el AnimationTree de armsy está activo")
	ok(player.arms_animator.playback != null, "ArmsAnimator tiene playback del state machine")

	var hands: HandsModel = player.inventory.hands
	var linterna: ItemInstance = ItemInstance.new(desc)
	ok(hands.equip(linterna, HandsModel.Hand.RIGHT), "la linterna se puede equipar en la mano derecha")
	await create_timer(.4).timeout
	ok(player.animation_tree["parameters/context/blend_amount"] > .9, "capa ctx_flashlight activa en armsy sin arma")
	ctrl.toggle_flashlight()
	ok(ctrl._on, "toggle enciende la linterna en la mano derecha")
	ctrl.toggle_flashlight()
	ok(not ctrl._on, "toggle apaga la linterna")

	var gun_desc: EquippableDescriptor = load("res://resources/weapons/firearm/glock-17.tres") as EquippableDescriptor
	ok(gun_desc != null, "glock-17.tres es EquippableDescriptor")
	hands.remove(linterna)
	var arma: ItemInstance = ItemInstance.new(gun_desc)
	ok(hands.equip(arma, HandsModel.Hand.RIGHT), "se equipa el arma en la mano derecha")
	ok(hands.equip(linterna, HandsModel.Hand.LEFT), "la linterna queda en la mano izquierda")
	await create_timer(.4).timeout
	ok(is_instance_valid(player.viewmodel_animator), "existe ViewmodelAnimator del arma")
	ok(player.viewmodel_animation_tree["parameters/context/blend_amount"] > .9, "capa ctx_flashlight activa en el viewmodel")
	ok(player.animation_tree["parameters/context/blend_amount"] > .9, "capa ctx_flashlight activa en armsy con arma")

	hands.remove(arma)
	await create_timer(.4).timeout
	ok(player.animation_tree["parameters/context/blend_amount"] > .9, "al soltar el arma, armsy mantiene la capa de la linterna")

	hands.remove(linterna)
	await create_timer(.4).timeout
	ok(player.animation_tree["parameters/context/blend_amount"] < .1, "al desequipar la linterna, armsy apaga la capa")

	print("=== Fallos: %d ===" % fallos)
	quit(1 if fallos > 0 else 0)


func _todos(node: Node) -> Array[Node]:
	var result: Array[Node] = [node]
	for child in node.get_children():
		result.append_array(_todos(child))
	return result
