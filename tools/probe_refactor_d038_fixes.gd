extends Node3D
## Sonda de las correcciones del refactor D-038:
##   1) `MeleeAttack.run()` ejecuta de punta a punta y `swing_index` existe y avanza.
##   2) Una recarga cancelada no clobbera el flag `reloading` ni la animación de la
##      recarga nueva (carrera tras `await`).
##   3) Una recarga normal sigue terminando y limpiando el estado.
##
## Uso: godot --headless --path . res://tools/probe_refactor_d038_fixes.tscn

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
	var host: Node3D = Node3D.new()
	player.weapon_pivot.add_child(host)
	wc.weapon_node = host
	wc.weapon_ap = null
	var animator: ViewmodelAnimator = ViewmodelAnimator.new()
	animator.setup(host)
	player.viewmodel_animator = animator
	wc.fire_rate.stop()

	print("=== 1) MeleeAttack y swing_index ===")
	var melee: Melee = MELEE_RES.duplicate() as Melee
	wc.current_weapon = melee
	wc.swing_index = 0
	var melee_op: MeleeAttack = MeleeAttack.new()
	melee_op.start(wc, melee)
	wc._start_operation(melee_op)
	await melee_op.run()
	await get_tree().process_frame
	ok(wc.swing_index == 1, "swing_index existe y avanzó a 1 (%d)" % wc.swing_index)
	ok(not melee_op.cancelled, "la operación melee no se canceló")
	wc._finish_operation(melee_op)

	print("=== 2) Carrera de recarga ===")
	var gun: Weapon = Weapon.new()
	gun.ammo_type = Weapon.AMMO_TYPE.LOW_CALIBER
	gun.mag_size = 4
	gun.curr_bullets = 0
	gun.bullet_per_reload = 1
	gun.reload_time = 0.2
	gun.damage = 10.0
	gun.weapon_range = 10.0
	_add_ammo(player, gun.ammo_type, 40)
	wc.current_weapon = gun

	var op_a: ReloadOperation = ReloadOperation.new()
	op_a.start(wc, gun)
	ok(op_a.can_start(), "la recarga A puede empezar")
	wc._start_operation(op_a)
	op_a.run()
	await get_tree().create_timer(0.05).timeout

	var op_b: ReloadOperation = ReloadOperation.new()
	op_b.start(wc, gun)
	wc._start_operation(op_b)
	ok(op_a.cancelled, "empezar B canceló A")
	op_b.run()
	await get_tree().create_timer(0.22).timeout
	ok(wc.is_active_operation(op_b), "B sigue siendo la operación activa")
	ok(wc.reloading, "A despertó y NO clobberó `reloading` de B")
	wc._abort_operation()

	print("=== 3) Recarga normal ===")
	var gun2: Weapon = Weapon.new()
	gun2.ammo_type = Weapon.AMMO_TYPE.LOW_CALIBER
	gun2.mag_size = 2
	gun2.curr_bullets = 0
	gun2.bullet_per_reload = 2
	gun2.reload_time = 0.05
	gun2.damage = 10.0
	gun2.weapon_range = 10.0
	_add_ammo(player, gun2.ammo_type, 20)
	wc.current_weapon = gun2

	var op_c: ReloadOperation = ReloadOperation.new()
	op_c.start(wc, gun2)
	ok(op_c.can_start(), "la recarga C puede empezar")
	wc._start_operation(op_c)
	await op_c.run()
	wc._finish_operation(op_c)
	ok(gun2.curr_bullets == 2, "el cargador se llenó (%d)" % gun2.curr_bullets)
	ok(not wc.reloading, "`reloading` quedó en false al terminar")

	if fallos == 0:
		print("RESULTADO: TODO OK")
	else:
		print("RESULTADO: %d FALLO(S)" % fallos)
	get_tree().quit(1 if fallos > 0 else 0)


func _add_ammo(player: Player, type: Weapon.AMMO_TYPE, rounds: int) -> void:
	var ammo: AmmoItemDescriptor = AmmoItemDescriptor.new()
	ammo.item_name = "munición de prueba"
	ammo.dimensions = Vector2i(1, 1)
	ammo.ammo_type = type
	ammo.rounds = rounds
	player.inventory.add_anywhere(ItemInstance.new(ammo))


func _find_player(root: Node) -> Player:
	for node in root.find_children("*", "Player", true, false):
		return node as Player
	return null
