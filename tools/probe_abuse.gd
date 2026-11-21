extends Node3D
## Probe de abuso: ejecuta UN caso por proceso para aislar errores de runtime.
## Uso: godot --headless --path . res://tools/probe_abuse.tscn -- --case=ammo
## No modifica código de juego.

var test_scene: Node3D
var player: Player
var ui: UI
var death_count: int = 0


func _ready() -> void:
	var case_name: String = "fall"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):
			case_name = arg.trim_prefix("--case=")
	print("CASE=" + case_name)

	var guard: SceneTreeTimer = get_tree().create_timer(15.0)
	guard.timeout.connect(_on_guard_timeout)

	match case_name:
		"ammo":
			await _case_ammo()
		"attack_ui":
			await _case_attack_ui()
		"death":
			await _case_death()
		"fall":
			await _case_fall()
		"lean":
			await _case_lean()
		"grab_consume":
			await _case_grab_consume()
		"escape":
			await _case_escape()
		"multigrab":
			await _case_multigrab()
		"heal":
			await _case_heal()
		"quick_slot":
			await _case_quick_slot()
		"pause":
			await _case_pause()
		"claw":
			await _case_claw()
		"zombie_hurt":
			await _case_zombie_hurt()
		"door":
			await _case_door()
		"icons":
			await _case_icons()
		"inventory_move":
			await _case_inventory_move()
		"prone":
			await _case_prone()
		_:
			print("UNKNOWN CASE")
	get_tree().quit()


func _on_guard_timeout() -> void:
	print("GUARD_TIMEOUT")
	get_tree().quit()


func _wait(seconds: float) -> void:
	var frames: int = int(seconds * 120.0)
	for i in range(frames):
		await get_tree().physics_frame


func _spawn(keep_zombies: bool) -> void:
	var packed: PackedScene = load("res://scenes/debug/test.tscn") as PackedScene
	test_scene = packed.instantiate() as Node3D
	add_child(test_scene)
	await _wait(0.35)
	player = _find_player(test_scene)
	ui = _find_ui(test_scene)
	print("PLAYER=", player != null, " UI=", ui != null)
	if player == null or ui == null:
		return
	if not keep_zombies:
		for zombie in _find_zombies(test_scene):
			zombie.queue_free()
		await _wait(0.1)


func _find_player(node: Node) -> Player:
	if node is Player:
		return node as Player
	for child in node.get_children():
		var found: Player = _find_player(child)
		if found != null:
			return found
	return null


func _find_ui(node: Node) -> UI:
	if node is UI:
		return node as UI
	for child in node.get_children():
		var found: UI = _find_ui(child)
		if found != null:
			return found
	return null


func _find_zombies(node: Node) -> Array[Zombie]:
	var result: Array[Zombie] = []
	if node is Zombie:
		result.append(node as Zombie)
		return result
	for child in node.get_children():
		result.append_array(_find_zombies(child))
	return result


func _fsm_state(machine_name: String) -> String:
	var machine: StateMachine = player.get_node("%" + machine_name) as StateMachine
	if machine == null or machine.state == null:
		return "<null>"
	return machine.state.name


func _equip(path: String) -> bool:
	var descriptor: ItemDescriptor = load(path) as ItemDescriptor
	if descriptor == null:
		print("EQUIP_LOAD_FAIL ", path)
		return false
	var item: ItemInstance = ItemInstance.new(descriptor)
	return player.inventory.hands.equip(item, HandsModel.Hand.RIGHT)


func _count_death() -> void:
	death_count += 1


# ---------------------------------------------------------------------------

func _case_ammo() -> void:
	await _spawn(false)
	if player == null:
		return
	var ok: bool = _equip("res://resources/weapons/firearm/glock-17.tres")
	await _wait(0.7)
	var weapon: Resource = player.get_current_weapon()
	print("AMMO equip=", ok, " weapon=", weapon.resource_path if weapon != null else "<null>")
	print("AMMO curr=", player.get_current_weapon().curr_bullets if weapon != null else -1)
	print("AMMO hud_visible=", ui.ammo_count.visible, " hud_text='", ui.ammo_count.text, "'")
	print("AMMO arms_fsm=", _fsm_state("ArmsFSM"))


func _case_attack_ui() -> void:
	await _spawn(false)
	if player == null:
		return
	var ok: bool = _equip("res://resources/weapons/melee/machete.tres")
	await _wait(0.7)
	ui.toggle_inventory()
	await _wait(0.2)
	var weapon_ap_before: AnimationPlayer = player.weapon_controller.weapon_ap
	print("ATTACK inventory_open=", ui.inventory.visible, " mouse=", Input.mouse_mode, " anim_before='", weapon_ap_before.current_animation if weapon_ap_before != null else "<null>", "'")
	Input.action_press("M1")
	await _wait(0.25)
	Input.action_release("M1")
	await _wait(0.1)
	var weapon_ap: AnimationPlayer = player.weapon_controller.weapon_ap
	print("ATTACK equip=", ok, " arms_fsm=", _fsm_state("ArmsFSM"), " anim='", weapon_ap.current_animation if weapon_ap != null else "<null>", "'")


func _case_death() -> void:
	await _spawn(false)
	if player == null:
		return
	player.player_death.connect(_count_death)
	var ok: bool = _equip("res://resources/weapons/melee/machete.tres")
	await _wait(0.7)
	ui.toggle_inventory()
	await _wait(0.15)
	print("DEATH before health=", player.health_component.current_health, " fsm=", _fsm_state("StateMachine"), " can_move=", player.can_move)
	player.health_component.hurt(9999.0, {})
	await _wait(0.8)
	print("DEATH after health=", player.health_component.current_health, " death_count=", death_count)
	print("DEATH death_screen=", ui.death_screen.visible, " inventory=", ui.inventory.visible, " mouse=", Input.mouse_mode)
	print("DEATH fsm=", _fsm_state("StateMachine"), " arms=", _fsm_state("ArmsFSM"), " can_move=", player.can_move)
	var before: Vector3 = player.global_position
	Input.action_press("forward")
	await _wait(0.5)
	Input.action_release("forward")
	var moved: float = before.distance_to(player.global_position)
	Input.action_press("M1")
	await _wait(0.25)
	Input.action_release("M1")
	var weapon_ap: AnimationPlayer = player.weapon_controller.weapon_ap
	print("DEATH moved=", moved, " anim='", weapon_ap.current_animation if weapon_ap != null else "<null>", "'")
	player.health_component.hurt(1.0, {})
	await _wait(0.1)
	print("DEATH death_count_repeated=", death_count)


func _case_fall() -> void:
	await _spawn(false)
	if player == null:
		return
	player.global_position = Vector3(-8.0, 5.0, 0.0)
	player.velocity = Vector3.ZERO
	await _wait(0.1)
	var prev: String = _fsm_state("StateMachine")
	var changes: int = 0
	var seen: Array[String] = []
	for i in range(90):
		await get_tree().physics_frame
		var now: String = _fsm_state("StateMachine")
		if now != prev:
			changes += 1
			if seen.size() < 12:
				seen.append(now)
			prev = now
	print("FALL changes=", changes, " sequence=", seen, " y=", player.global_position.y)


func _lean(action: StringName, pressed: bool) -> void:
	var lean_node: Node = player.get_node("LeanController")
	var ev: InputEventAction = InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	lean_node._input(ev)


func _case_lean() -> void:
	await _spawn(false)
	if player == null:
		return
	var pitch: Node3D = player.pitch
	var camera: Camera3D = player.get_node("Yaw/CameraRig/Pitch/Camera3D") as Camera3D
	_lean(&"lean_left", true)
	await _wait(0.35)
	print("LEAN left pitch_z=", pitch.rotation_degrees.z, " pitch_x=", pitch.position.x)
	_lean(&"lean_left", false)
	await _wait(0.35)
	print("LEAN release pitch_z=", pitch.rotation_degrees.z, " pitch_x=", pitch.position.x)

	_lean(&"lean_left", true)
	await _wait(0.1)
	_lean(&"lean_right", true)
	await _wait(0.25)
	print("LEAN both pitch_z=", pitch.rotation_degrees.z, " pitch_x=", pitch.position.x)
	_lean(&"lean_left", false)
	await _wait(0.35)
	print("LEAN release_left_only pitch_z=", pitch.rotation_degrees.z, " pitch_x=", pitch.position.x)
	_lean(&"lean_right", false)
	await _wait(0.25)

	player.global_position = Vector3(-0.9, 1.5, 1.8)
	player.velocity = Vector3.ZERO
	await _wait(0.7)
	_lean(&"lean_right", true)
	await _wait(0.35)
	print("LEAN wall player_x=", player.global_position.x, " cam_x=", camera.global_position.x, " wall_west=-0.5")
	_lean(&"lean_right", false)
	await _wait(0.25)

	Input.action_press(player.jump)
	await _wait(0.15)
	Input.action_release(player.jump)
	_lean(&"lean_left", true)
	await _wait(0.2)
	print("LEAN air y=", player.global_position.y, " pitch_z=", pitch.rotation_degrees.z, " fsm=", _fsm_state("StateMachine"))
	_lean(&"lean_left", false)


func _case_grab_consume() -> void:
	await _spawn(true)
	if player == null:
		return
	var zombies: Array[Zombie] = _find_zombies(test_scene)
	if zombies.is_empty():
		print("GRAB no zombie")
		return
	var zombie: Zombie = zombies[0]
	for i in range(1, zombies.size()):
		zombies[i].queue_free()
	await _wait(0.1)
	zombie.global_position = player.global_position + Vector3(0.0, 0.0, -1.0)
	zombie.set_physics_process(false)
	zombie.state_machine.set_process(false)
	var anchor: Node3D = zombie.get_node("GrabPoint") as Node3D
	player.get_grabbed(zombie, anchor)
	await _wait(0.25)
	print("GRAB player_fsm=", _fsm_state("StateMachine"), " arms=", _fsm_state("ArmsFSM"), " grabber=", player.grabber != null)
	ui.toggle_inventory()
	await _wait(0.15)
	print("GRAB inventory_open=", ui.inventory.visible, " mouse=", Input.mouse_mode)

	var descriptor: ConsumableItemDescriptor = ConsumableItemDescriptor.new()
	descriptor.item_name = "probe_food"
	descriptor.effect_amount = 20.0
	descriptor.effect_duration = 0.3
	descriptor.consume_type = ConsumableItemDescriptor.ConsumeType.EAT
	var item: ItemInstance = ItemInstance.new(descriptor)
	player.use_item(item)
	await _wait(0.15)
	print("GRAB consume_mid fsm=", _fsm_state("StateMachine"), " arms=", _fsm_state("ArmsFSM"))
	await _wait(0.5)
	print("GRAB consume_end player_fsm=", _fsm_state("StateMachine"), " arms=", _fsm_state("ArmsFSM"), " grabber=", player.grabber != null, " push_enabled=", player.weapon_controller.push_enabled)


func _case_escape() -> void:
	await _spawn(true)
	if player == null:
		return
	var zombies: Array[Zombie] = _find_zombies(test_scene)
	if zombies.is_empty():
		print("ESCAPE no zombie")
		return
	var zombie: Zombie = zombies[0]
	for i in range(1, zombies.size()):
		zombies[i].queue_free()
	await _wait(0.1)
	# Aislar el escape de la transición diferida de idle (bug aparte).
	var idle_state: State = zombie.state_machine.get_node("idle") as State
	for connection in idle_state.finished.get_connections():
		idle_state.finished.disconnect(connection.callable)
	zombie.set_physics_process(false)
	zombie.global_position = player.global_position + Vector3(0.0, 0.0, -1.0)
	zombie.vision.target = player
	zombie.state_machine._transition_to_next_state("grab")
	await _wait(0.35)
	print("ESCAPE grabbed player=", _fsm_state("StateMachine"), " arms=", _fsm_state("ArmsFSM"), " zombie=", zombie.state_machine.state.name)
	var arms_machine: StateMachine = player.get_node("%ArmsFSM") as StateMachine
	for i in range(8):
		var ev: InputEventAction = InputEventAction.new()
		ev.action = &"struggle"
		ev.pressed = true
		arms_machine.state.handle_input(ev)
	print("ESCAPE progress_before_last=", arms_machine.state.progress, " arms=", _fsm_state("ArmsFSM"))
	var last_ev: InputEventAction = InputEventAction.new()
	last_ev.action = &"struggle"
	last_ev.pressed = true
	arms_machine.state.handle_input(last_ev)
	await _wait(0.5)
	print("ESCAPE after player=", _fsm_state("StateMachine"), " arms=", _fsm_state("ArmsFSM"), " zombie=", zombie.state_machine.state.name, " grabber=", player.grabber != null)
	var view_punch: ViewPunch = player.get_node("%ViewPunch") as ViewPunch
	print("ESCAPE viewpunch_camera=", view_punch.camera.name if view_punch.camera != null else "<null>", " path=", String(view_punch.camera.get_path()) if view_punch.camera != null else "-")


func _case_multigrab() -> void:
	await _spawn(true)
	if player == null:
		return
	var zombies: Array[Zombie] = _find_zombies(test_scene)
	if zombies.size() < 2:
		print("MULTIGRAB not enough zombies")
		return
	for i in range(2, zombies.size()):
		zombies[i].queue_free()
	await _wait(0.1)
	var z1: Zombie = zombies[0]
	var z2: Zombie = zombies[1]
	for zombie in [z1, z2]:
		var idle_state: State = zombie.state_machine.get_node("idle") as State
		for connection in idle_state.finished.get_connections():
			idle_state.finished.disconnect(connection.callable)
		zombie.set_physics_process(false)
	z1.global_position = player.global_position + Vector3(-0.5, 0.0, -1.0)
	z2.global_position = player.global_position + Vector3(0.5, 0.0, -1.0)
	for zombie in [z1, z2]:
		zombie.vision.target = player
	z1.state_machine._transition_to_next_state("grab")
	await _wait(0.3)
	print("MULTIGRAB first player=", _fsm_state("StateMachine"), " z1=", z1.state_machine.state.name, " grabber_is_z1=", player.grabber == z1)
	z2.state_machine._transition_to_next_state("grab")
	await _wait(0.3)
	print("MULTIGRAB second player=", _fsm_state("StateMachine"), " z1=", z1.state_machine.state.name, " z2=", z2.state_machine.state.name, " grabber_is_z1=", player.grabber == z1)
	player.end_grab()
	await _wait(0.3)
	print("MULTIGRAB after_end player=", _fsm_state("StateMachine"), " z1=", z1.state_machine.state.name, " z2=", z2.state_machine.state.name, " grabber=", player.grabber != null)


func _push_action(action: StringName) -> void:
	var ev: InputEventAction = InputEventAction.new()
	ev.action = action
	ev.pressed = true
	get_viewport().push_input(ev)


func _case_pause() -> void:
	await _spawn(false)
	if player == null:
		return
	ui.toggle_inventory()
	await _wait(0.15)
	print("PAUSE before paused=", get_tree().paused, " inventory=", ui.inventory.visible, " mouse=", Input.mouse_mode)
	_push_action(&"ui_cancel")
	await _wait(0.2)
	var gm: Node = get_node("/root/GameManager")
	var menu: Node = gm.get("_pause_menu") as Node
	print("PAUSE esc paused=", get_tree().paused, " menu_visible=", menu != null and menu is CanvasLayer and (menu as CanvasLayer).visible, " inventory=", ui.inventory.visible, " mouse=", Input.mouse_mode)
	_push_action(&"ui_cancel")
	await _wait(0.2)
	print("PAUSE resume paused=", get_tree().paused, " inventory=", ui.inventory.visible, " mouse=", Input.mouse_mode)


func _case_claw() -> void:
	await _spawn(true)
	if player == null:
		return
	var zombies: Array[Zombie] = _find_zombies(test_scene)
	var zombie: Zombie = zombies[0]
	for i in range(1, zombies.size()):
		zombies[i].queue_free()
	await _wait(0.1)
	var idle_state: State = zombie.state_machine.get_node("idle") as State
	for connection in idle_state.finished.get_connections():
		idle_state.finished.disconnect(connection.callable)
	zombie.state_machine._transition_to_next_state("chase")
	await _wait(0.1)
	var timer: Timer = zombie.get_node("%claw_timer") as Timer
	timer.start(0.1)
	await _wait(0.3)
	print("CLAW state=", zombie.state_machine.state.name, " timer_stopped=", timer.is_stopped())


func _case_inventory_move() -> void:
	await _spawn(false)
	if player == null:
		return
	ui.toggle_inventory()
	await _wait(0.1)
	var before: Vector3 = player.global_position
	Input.action_press("forward")
	await _wait(0.6)
	Input.action_release("forward")
	await _wait(0.1)
	print("INVMOVE inventory=", ui.inventory.visible, " moved=", before.distance_to(player.global_position), " fsm=", _fsm_state("StateMachine"))


func _case_icons() -> void:
	await _spawn(false)
	if player == null:
		return
	var descriptor: ItemDescriptor = load("res://resources/weapons/melee/machete.tres") as ItemDescriptor
	var item: ItemInstance = ItemInstance.new(descriptor)
	var added: bool = player.inventory.pick_up(item)
	ui.toggle_inventory()
	await _wait(1.5)
	print("ICONS added=", added, " icon=", descriptor.get_icon() != null)
	if descriptor.get_icon() != null:
		print("ICONS size=", descriptor.get_icon().get_size())


func _case_door() -> void:
	var packed: PackedScene = load("res://scenes/components/door_components.tscn") as PackedScene
	var door: Node = packed.instantiate()
	add_child(door)
	await _wait(0.2)
	print("DOOR added=", is_instance_valid(door))


func _case_zombie_hurt() -> void:
	await _spawn(true)
	if player == null:
		return
	var zombies: Array[Zombie] = _find_zombies(test_scene)
	var zombie: Zombie = zombies[0]
	for i in range(1, zombies.size()):
		zombies[i].queue_free()
	await _wait(0.1)
	zombie.hurted(10.0, {"who": player, "attacker": player, "hit_pos": zombie.global_position, "swing": Vector3.RIGHT})
	await _wait(0.3)
	print("ZHURT state=", zombie.state_machine.state.name)


func _case_quick_slot() -> void:
	await _spawn(false)
	if player == null:
		return
	var descriptor: ItemDescriptor = load("res://resources/weapons/melee/machete.tres") as ItemDescriptor
	var item: ItemInstance = ItemInstance.new(descriptor)
	var added: bool = player.inventory.pick_up(item)
	print("QUICK added=", added, " slots_box=", player.inventory.quick_slots != null)
	if player.inventory.quick_slots != null:
		player.inventory.add_quick_slot()
		await _wait(0.1)
		var slot: QuickSlot = player.inventory.quick_slots.get_child(0) as QuickSlot
		slot.change_linked_item(item)
		print("QUICK slot_linked=", slot.instance_item == item)
	player.inventory.remove(item)
	player.drop_item(item)
	await _wait(0.3)
	var pickables: Array[PickableItem] = _find_pickables(self)
	print("QUICK in_inventory_before=", _inventory_has(item), " pickables=", pickables.size())
	player.inventory._quick_slot_called(item)
	await _wait(0.2)
	print("QUICK after_call in_inventory=", _inventory_has(item), " in_hands=", _hands_has(item), " pickables_still=", pickables.size())
	var same_instance_world: bool = false
	for pickable in pickables:
		if pickable.item == item:
			same_instance_world = true
	print("QUICK same_instance_world=", same_instance_world)


func _inventory_has(item: ItemInstance) -> bool:
	for model in player.inventory.models:
		if model.has_item(item):
			return true
	return false


func _hands_has(item: ItemInstance) -> bool:
	return item in player.inventory.hands.items()


func _find_pickables(node: Node) -> Array[PickableItem]:
	var result: Array[PickableItem] = []
	if node is PickableItem:
		result.append(node as PickableItem)
		return result
	for child in node.get_children():
		result.append_array(_find_pickables(child))
	return result


func _case_heal() -> void:
	await _spawn(false)
	if player == null:
		return
	player.health_component.current_health = 50.0
	var descriptor: ConsumableItemDescriptor = ConsumableItemDescriptor.new()
	descriptor.item_name = "probe_heal"
	descriptor.effect_amount = 30.0
	descriptor.effect_duration = 0.3
	descriptor.consume_type = ConsumableItemDescriptor.ConsumeType.HEAL
	var item: ItemInstance = ItemInstance.new(descriptor)
	player.use_item(item)
	await _wait(0.7)
	print("HEAL health=", player.health_component.current_health, " arms=", _fsm_state("ArmsFSM"))


func _case_prone() -> void:
	await _spawn(false)
	if player == null:
		return
	Input.action_press("sprint")
	Input.action_press("forward")
	await _wait(0.4)
	Input.action_press("prone")
	await _wait(0.3)
	print("PRONE running fsm=", _fsm_state("StateMachine"))
	Input.action_release("prone")
	Input.action_release("sprint")
	Input.action_release("forward")
	await _wait(0.3)
	print("PRONE after_release fsm=", _fsm_state("StateMachine"))
