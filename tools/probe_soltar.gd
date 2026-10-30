extends SceneTree
## Sonda de runtime: verifica el flujo de SOLTAR objetos.
## Cubre los tres caminos de Player.drop_item():
##   1) UI (clic derecho > "soltar") vía InventoryUIController.item_dropped.
##   2) Tecla G del estado 'normal' (drop_item directo tras sacar de las manos).
##   3) Descriptor sin escena agarrable: el item se devuelve al inventario (no se pierde).
## Uso: godot --headless --path . --script res://tools/probe_soltar.gd

var fallos := 0


func ok(cond: bool, msg: String) -> void:
	if cond:
		print("  OK   ", msg)
	else:
		fallos += 1
		print("  FALLA ", msg)


func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/debug/test.tscn")
	if packed == null:
		print("  FALLA no se pudo cargar test.tscn")
		quit(1)
		return
	var root := packed.instantiate()
	get_root().add_child(root)
	set_current_scene(root)
	await process_frame
	await process_frame

	var player: Player = _find_player(root)
	ok(player != null, "se encontró el Player")
	if player == null:
		quit(1)
		return
	var ui: UI = player.get_node_or_null("CanvasLayer/UI")
	ok(ui != null, "la UI existe")
	if ui == null:
		quit(1)
		return

	print("=== 1) La UI quedó conectada al Player (D-004) ===")
	ok(ui.inventory_ui.item_dropped.is_connected(player.drop_item),
			"InventoryUIController.item_dropped -> Player.drop_item")
	ok(ui.inventory_ui.item_used.is_connected(player.use_item),
			"InventoryUIController.item_used -> Player.use_item")

	print("=== 2) Flujo de la UI: clic derecho > 'soltar' ===")
	var descriptor := MiscItemDescriptor.new()
	descriptor.item_name = "objeto soltable"
	descriptor.dimensions = Vector2i(1, 1)
	descriptor.item_mesh = _escena_agarrable(descriptor)
	var item := ItemInstance.new(descriptor)
	ok(player.inventory.add_anywhere(item), "el objeto entró al inventario")
	var world_antes := _conteo_pickables(root)
	# Equivale a elegir "soltar" en el menú de acciones: saca del inventario y emite.
	ui.inventory_ui._on_action_selected(item, "soltar")
	# Posición y velocidad se miden YA: la sonda todavía no esperó ningún frame
	# y la gravedad todavía no alteró la velocidad.
	var soltado := _ultimo_pickable(root, world_antes)
	ok(soltado != null, "apareció un PickableItem en el mundo")
	if soltado:
		ok(soltado.item == item, "el objeto soltado conserva su ItemInstance (mismo contenido)")
		ok(not _esta_en_inventario(player, item), "salió del inventario")
		var dist: float = soltado.global_position.distance_to(player.camera.global_position)
		ok(absf(dist - Player.DROP_DISTANCE) < 0.05,
				"aparece a %.2f m de la cámara (esperado %.2f)" % [dist, Player.DROP_DISTANCE])
		var cuerpo: RigidBody3D = soltado.get_rigid_body()
		ok(cuerpo != null, "get_rigid_body() encontró el RigidBody3D")
		if cuerpo:
			ok(absf(cuerpo.linear_velocity.length() - Player.THROW_SPEED) < 0.01,
					"velocidad de lanzamiento %.2f m/s (esperado %.2f)" % [cuerpo.linear_velocity.length(), Player.THROW_SPEED])
	await process_frame
	await process_frame

	print("=== 3) Flujo de la tecla G: drop_item tras sacar de las manos ===")
	var item2 := ItemInstance.new(descriptor)
	ok(player.inventory.add_anywhere(item2), "un segundo objeto entró al inventario")
	var world_antes2 := _conteo_pickables(root)
	# 'normal.gd' hace: remove(held) y después drop_item(held); acá se llama directo.
	player.inventory.remove(item2)
	player.drop_item(item2)
	await process_frame
	await process_frame
	var soltado2 := _ultimo_pickable(root, world_antes2)
	ok(soltado2 != null, "el segundo objeto apareció en el mundo")
	ok(soltado2 != null and soltado2.item == item2, "conserva su ItemInstance")

	print("=== 4) Escena NO agarrable: el item no se pierde ===")
	var plano := MiscItemDescriptor.new()
	plano.item_name = "objeto plano"
	plano.dimensions = Vector2i(1, 1)
	plano.item_mesh = _escena_plana()
	var item3 := ItemInstance.new(plano)
	ok(player.inventory.add_anywhere(item3), "el objeto plano entró al inventario")
	var world_antes3 := _conteo_pickables(root)
	# Como en el flujo real: el caller lo saca del inventario y después suelta.
	player.inventory.remove(item3)
	player.drop_item(item3)
	await process_frame
	await process_frame
	ok(_conteo_pickables(root) == world_antes3, "no apareció ningún objeto en el mundo")
	ok(_esta_en_inventario(player, item3), "el item volvió al inventario (no se pierde)")

	print("=== 5) El PickableItem reutiliza el área que ya trae la escena ===")
	var con_area := _escena_con_area_propia(descriptor)
	var n: PickableItem = con_area.instantiate()
	root.add_child(n)
	await process_frame
	var areas_en_capa_2 := 0
	for c in _todos(n):
		if c is Area3D and c.get_collision_layer_value(2):
			areas_en_capa_2 += 1
	ok(areas_en_capa_2 == 1, "queda un solo área en la capa 2 (no duplica la de la escena)")
	ok(n.get_rigid_body() != null, "encontró el RigidBody3D")
	ok(n.get_rigid_body().collision_layer == 2, "aplicó body_layer = 2 al cuerpo")
	n.queue_free()

	print("")
	if fallos == 0:
		print("RESULTADO: TODO OK")
	else:
		print("RESULTADO: %d FALLO(S)" % fallos)
	quit(1 if fallos > 0 else 0)


## Escena agarrable de mentira: RigidBody3D con el script PickableItem en la raíz
## (igual que un modelo importado de Blender con -rigid y el script colgado).
func _escena_agarrable(descriptor: ItemDescriptor) -> PackedScene:
	var body := RigidBody3D.new()
	body.set_script(load("res://scripts/components/pickable_object.gd"))
	body.item_descriptor = descriptor
	var packed := PackedScene.new()
	var err := packed.pack(body)
	assert(err == OK, "no se pudo empaquetar la escena de prueba")
	body.free()
	return packed


## Igual que la anterior, pero con un área en la capa 2 ya incluida (como el
## modelo arrastrado a la escena con su PickupArea): el script debe reutilizarla.
func _escena_con_area_propia(descriptor: ItemDescriptor) -> PackedScene:
	var body := RigidBody3D.new()
	body.set_script(load("res://scripts/components/pickable_object.gd"))
	body.item_descriptor = descriptor
	var area := Area3D.new()
	area.set_collision_layer_value(2, true)
	body.add_child(area)
	area.owner = body
	var packed := PackedScene.new()
	var err := packed.pack(body)
	assert(err == OK, "no se pudo empaquetar la escena de prueba con área")
	body.free()
	return packed


## Escena simple SIN el script (como los item_mesh legacy: solo malla).
func _escena_plana() -> PackedScene:
	var n := Node3D.new()
	var packed := PackedScene.new()
	packed.pack(n)
	n.free()
	return packed


func _conteo_pickables(root: Node) -> int:
	var total := 0
	for n in _todos(root):
		if n is PickableItem:
			total += 1
	return total


func _ultimo_pickable(root: Node, desde: int) -> PickableItem:
	var encontrados: Array[Node] = []
	for n in _todos(root):
		if n is PickableItem:
			encontrados.append(n)
	if encontrados.size() > desde:
		return encontrados[encontrados.size() - 1] as PickableItem
	return null


func _esta_en_inventario(player: Player, item: ItemInstance) -> bool:
	for model in player.inventory.models:
		if item in model.items():
			return true
	if item in player.inventory.hands.items():
		return true
	if item in player.inventory.equipment.items():
		return true
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
