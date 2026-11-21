extends Node3D
## Sonda del ataque melee por el camino real de input: M1 -> ArmsFSM/normal ->
## WeaponController.attack -> MeleeBehaviour -> MeleeAttack -> swing.

const MELEE_RES: Melee = preload("res://resources/weapons/melee/machete.tres")

var fallos: int = 0

func ok(cond: bool, msg: String) -> void:
	if cond:
		print("  OK   ", msg)
	else:
		fallos += 1
		print("  FALLA ", msg)


func _ready() -> void:
	var packed: PackedScene = load("res://scenes/debug/test.tscn")
	if packed == null:
		print("  FALLA no se pudo cargar test.tscn")
		get_tree().quit(1)
		return
	var root: Node = packed.instantiate()
	add_child(root)
	await get_tree().process_frame
	await get_tree().process_frame

	var player: Player = _find_player(root)
	if player == null:
		print("  FALLA no se encontró el Player")
		get_tree().quit(1)
		return
	var wc: WeaponController = player.weapon_controller
	ok(wc != null, "el Player tiene WeaponController")
	if wc == null:
		get_tree().quit(1)
		return

	player.camera.current = true
	var item: ItemInstance = ItemInstance.new(MELEE_RES)
	player.inventory.hands.equip(item, HandsModel.Hand.RIGHT)
	await get_tree().create_timer(0.7).timeout
	print("  FSM=", _fsm_state(player))
	print("  current_weapon=", wc.current_weapon)
	print("  behaviour=", wc.current_weapon.behaviour if wc.current_weapon != null else "<null>")
	wc.fire_rate.stop()

	print("  weapon_ap=", wc.weapon_ap)
	print("  has_swing1=", wc.weapon_ap.has_animation(&"swing1") if wc.weapon_ap != null else "n/a")
	print("  playback antes=", wc.player.viewmodel_animator.playback.get_current_node() if wc.player.viewmodel_animator != null and wc.player.viewmodel_animator.playback != null else "<null>")

	var before: int = wc.swing_index
	print("  esperando input M1...")
	Input.action_press("M1")
	await get_tree().create_timer(0.08).timeout
	var during: int = wc.swing_index
	Input.action_release("M1")
	await get_tree().create_timer(0.8).timeout
	print("  swing_index antes=", before, " durante=", during, " despues=", wc.swing_index)
	print("  FSM after=", _fsm_state(player))
	print("  anim='", wc.weapon_ap.current_animation if wc.weapon_ap != null else "<null>", "'")
	print("  playback after=", wc.player.viewmodel_animator.playback.get_current_node() if wc.player.viewmodel_animator != null and wc.player.viewmodel_animator.playback != null else "<null>")
	print("  op_activa=", wc.is_active_operation(wc._active_operation) if wc._active_operation != null else "null")
	print("  reloading=", wc.reloading)
	var hit_found: bool = false
	for c in player.get_children():
		if c is MeleeProjectile:
			hit_found = true
	print("  hit_melee_projectile=", hit_found)
	if fallos == 0:
		print("RESULTADO: TODO OK")
	else:
		print("RESULTADO: %d FALLO(S)" % fallos)
	get_tree().quit(1 if fallos > 0 else 0)


func _fsm_state(player: Player) -> String:
	var machine: StateMachine = player.get_node("%ArmsFSM") as StateMachine
	if machine == null or machine.state == null:
		return "<null>"
	return machine.state.name


func _find_player(root: Node) -> Player:
	for node in root.find_children("*", "Player", true, false):
		return node as Player
	return null
