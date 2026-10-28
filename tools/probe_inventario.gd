extends SceneTree
## Sonda de runtime: monta la escena de prueba, verifica el refactor del
## inventario y comprueba que no quede ninguna conexión de señal rota.

var fallos := 0


func ok(cond: bool, msg: String) -> void:
	if cond:
		print("  OK   ", msg)
	else:
		fallos += 1
		print("  FALLA ", msg)


func _initialize() -> void:
	print("=== 1) Montar la escena de prueba ===")
	var packed: PackedScene = load("res://scenes/debug/test.tscn")
	if packed == null:
		print("  FALLA no se pudo cargar test.tscn")
		quit(1)
		return
	var root := packed.instantiate()
	get_root().add_child(root)
	await process_frame
	await process_frame
	ok(true, "escena montada")

	var player: Player = _find_player(root)
	ok(player != null, "se encontró el Player")
	if player == null:
		quit(1)
		return

	print("=== 2) El inventario lo tiene el Player ===")
	ok(player.inventory != null, "player.inventory no es null")
	ok(player.inventory.get_parent() == player, "PlayerContainers es hijo del Player")
	ok(player.inventory.pockets != null, "el modelo de bolsillos está asignado")
	ok(player.inventory.equipment != null, "el modelo de equipo está asignado")
	ok(player.inventory.models.size() >= 1, "setup() corrió: hay %d contenedor(es)" % player.inventory.models.size())

	var ui: UI = player.get_node_or_null("CanvasLayer/UI")
	ok(ui != null, "la UI existe")
	if ui:
		ok(ui.player == player, "la UI conoce al Player (export, no get_parent().owner)")
		ok(ui.inventory_ui.carried == player.inventory, "InventoryUIController recibió el inventario")
		ok(player.inventory.quick_slots == ui.quick_slots, "la fila de atajos quedó inyectada")

	print("=== 3) Las ranuras (ropa y manos) recibieron su modelo ===")
	var ranuras := 0
	var sin_modelo := 0
	for n in _todos(ui):
		if n is EquipSlotView:
			ranuras += 1
			if n.equipment_model != player.inventory.equipment:
				sin_modelo += 1
		elif n is HandSlotView:
			ranuras += 1
			if n.carried != player.inventory:
				sin_modelo += 1
	ok(ranuras > 0, "hay %d ranuras (ropa + manos)" % ranuras)
	ok(sin_modelo == 0, "todas las ranuras están enlazadas (%d sueltas)" % sin_modelo)

	print("=== 4) Conexiones de señal rotas ===")
	# Se revisan TODAS las conexiones del árbol, no solo las que salen de
	# nodos con script: el destino es lo que importa, y un nodo del motor
	# puede emitir a un método de proyecto que ya no existe.
	#
	# Solo se miran las conexiones "estándar" (las que guardan el nombre del
	# método, como hace un .tscn). Las "custom" son las que el motor conecta
	# con punteros a método de C++ (Control::_size_changed y compañía):
	# no son código del proyecto y no aparecen en ClassDB.
	var rotas: Array[String] = []
	for n in _todos(root):
		for sig in n.get_signal_list():
			for c in n.get_signal_connection_list(sig.name):
				var callable: Callable = c["callable"]
				if not callable.is_standard():
					continue  # conexión interna del motor
				var target = callable.get_object()
				var method: String = callable.get_method()
				if target == null:
					rotas.append("%s.%s -> objeto liberado" % [n.name, sig.name])
					continue
				var tsc := target.get_script()
				if tsc == null:
					continue  # nodo del motor: no hay script que verificar
				if not _metodo_del_proyecto(tsc, method):
					rotas.append("%s.%s -> %s.%s (el metodo no existe)" % [n.name, sig.name, target.name, method])
	ok(rotas.is_empty(), "ninguna conexión rota (%d)" % rotas.size())
	for r in rotas:
		print("      ROTA: ", r)

	print("=== 5) El WeaponController usa el inventario del Player ===")
	var wc: WeaponController = player.weapon_controller
	ok(wc.ammo_source == player.inventory, "ammo_source es player.inventory (sin búsqueda por grupo)")

	print("=== 6) Flujo de recoger un objeto ===")
	var descriptor := MiscItemDescriptor.new()
	descriptor.item_name = "objeto de prueba"
	descriptor.dimensions = Vector2i(1, 1)
	var pickable: PickableItem = _crear_pickable(descriptor)
	root.add_child(pickable)
	pickable.global_position = player.global_position
	var antes: int = player.inventory.pockets.items().size()
	player.grabbed_object.emit(pickable)
	await process_frame
	await process_frame
	var despues: int = player.inventory.pockets.items().size()
	ok(despues == antes + 1, "el objeto entró al inventario (%d -> %d)" % [antes, despues])

	print("=== 7) Flujo de 'usar' un objeto (UI -> Player -> FSM) ===")
	var fsm = player.get_node_or_null("ArmsFSM")
	ok(fsm != null, "ArmsFSM existe")
	if fsm:
		var estado_antes: String = fsm.state.name
		var consumible := ConsumableItemDescriptor.new()
		consumible.item_name = "comida de prueba"
		consumible.dimensions = Vector2i(1, 1)
		consumible.effect_duration = 1.0
		consumible.effect_amount = 1.0
		player.use_item(ItemInstance.new(consumible))
		await process_frame
		await process_frame
		await process_frame
		ok(fsm.state.name == "consuming", "el FSM pasó de '%s' a '%s'" % [estado_antes, fsm.state.name])

	print("=== 8) El inventario ya no se busca por grupo ===")
	# Solo se comprueban las busquedas que rompian el aislamiento del
	# inventario. Otras (el grupo "muzzle" del arma, el grupo "player" del
	# zombie) no tienen que ver con este dominio.
	var patrones := ["get_first_node_in_group(\"player_inventory\")",
			"get_first_node_in_group(\"ammo_source\")",
			"%PlayerContainers", "get_parent().owner"]
	var por_grupo: Array[String] = []
	for n in _todos(root):
		var sc := n.get_script()
		if sc == null:
			continue
		var src: String = sc.source_code
		for clave in patrones:
			if src.contains(clave):
				por_grupo.append("%s (%s) usa %s" % [n.name, sc.resource_path.get_file(), clave])
	ok(por_grupo.is_empty(), "nadie busca el inventario por grupo ni sube por get_parent().owner")
	for p in por_grupo:
		print("      ", p)

	print("")
	if fallos == 0:
		print("RESULTADO: TODO OK")
	else:
		print("RESULTADO: %d FALLO(S)" % fallos)
	quit(1 if fallos > 0 else 0)


## ¿La señal está declarada en el script del nodo o en alguna clase base del proyecto?
func _senal_del_proyecto(sc: Script, nombre: String) -> bool:
	var actual: Script = sc
	while actual != null:
		var src: String = actual.source_code
		if src.find("signal %s" % nombre) != -1 or src.find("signal %s(" % nombre) != -1:
			return true
		actual = actual.get_base_script()
	return false


## ¿El metodo esta definido en el script o en alguna de sus clases base del proyecto?
func _metodo_del_proyecto(sc: Script, method: String) -> bool:
	var actual: Script = sc
	while actual != null:
		if actual.source_code.find("func %s(" % method) != -1:
			return true
		actual = actual.get_base_script()
	return false


func _todos(n: Node) -> Array[Node]:
	var out: Array[Node] = [n]
	for c in n.get_children():
		out.append_array(_todos(c))
	return out


func _find_player(n: Node) -> Player:
	for c in n.get_children():
		if c is Player:
			return c
		var r := _find_player(c)
		if r:
			return r
	return null


func _crear_pickable(descriptor: ItemDescriptor) -> PickableItem:
	var packed: PackedScene = load("res://scenes/components/pickable_object.tscn")
	var n = packed.instantiate()
	n.item = ItemInstance.new(descriptor)
	return n
