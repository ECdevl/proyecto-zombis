extends SceneTree
## Sonda de runtime: verifica el flujo de SOLTAR objetos (D-009).
## Cubre:
##   1) La UI quedó conectada al Player (D-004).
##   2) UI (clic derecho > "soltar") -> Player.drop_item: instancia SIEMPRE la
##      escena prefabricada pickable_object.tscn con el mesh del descriptor.
##   3) Tecla G del estado 'normal' (drop_item directo tras sacar de las manos).
##   4) Descriptor sin item_mesh: el item se devuelve al inventario (no se pierde).
##   5) La escena prefabricada puesta a mano en el mundo (como en test.tscn).
##   6) Asignar el descriptor (lo que hace el editor vía @tool): el mesh se
##      vuelca en "Malla" y la colisión convexa sigue a la malla decorada.
## Uso: godot --headless --path . --script res://tools/probe_soltar.gd

var fallos := 0

const PICKABLE_SCENE := "res://scenes/components/pickable_object.tscn"


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
	descriptor.item_mesh = BoxMesh.new()
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
		ok(soltado.scene_file_path == PICKABLE_SCENE,
				"instanció LA escena prefabricada (%s)" % soltado.scene_file_path)
		ok(soltado.item == item, "el objeto soltado conserva su ItemInstance (mismo contenido)")
		ok(not _esta_en_inventario(player, item), "salió del inventario")
		var dist: float = soltado.global_position.distance_to(player.camera.global_position)
		ok(absf(dist - Player.DROP_DISTANCE) < 0.05,
				"aparece a %.2f m de la cámara (esperado %.2f)" % [dist, Player.DROP_DISTANCE])
		ok(soltado is RigidBody3D, "la raíz ES el cuerpo físico (RigidBody3D)")
		ok(absf(soltado.linear_velocity.length() - Player.THROW_SPEED) < 0.01,
				"velocidad de lanzamiento %.2f m/s (esperado %.2f)" %
				[soltado.linear_velocity.length(), Player.THROW_SPEED])
		ok(soltado.name == descriptor.item_name, "el nodo toma el nombre del descriptor")
		ok(soltado.collision_layer == 2, "el cuerpo está en la capa 2")
		var malla := soltado.get_node_or_null("Malla") as MeshInstance3D
		ok(malla != null and malla.mesh == descriptor.item_mesh, "Malla lleva el mesh del descriptor")
		var colision := soltado.get_node_or_null("Colision") as CollisionShape3D
		ok(colision != null and colision.shape is ConvexPolygonShape3D,
				"la colisión es un casco convexo derivado de la malla")
		var areas_en_capa_2 := 0
		var area_owner_ok := false
		for c in _todos(soltado):
			if c is Area3D and c.get_collision_layer_value(2):
				areas_en_capa_2 += 1
				# El Player identifica el objeto vía area.owner (._try_interact).
				area_owner_ok = c.owner == soltado
		ok(areas_en_capa_2 == 1, "exactamente un área de interacción en la capa 2")
		ok(area_owner_ok, "area.owner es el propio PickableItem (lo agarra el rayo)")
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

	print("=== 4) Descriptor sin item_mesh: el item no se pierde ===")
	var plano := MiscItemDescriptor.new()
	plano.item_name = "objeto sin malla"
	plano.dimensions = Vector2i(1, 1)
	plano.item_mesh = null
	plano.icon = PlaceholderTexture2D.new()  # evita pedir un ícono sin malla
	var item3 := ItemInstance.new(plano)
	ok(player.inventory.add_anywhere(item3), "el objeto sin malla entró al inventario")
	var world_antes3 := _conteo_pickables(root)
	# Como en el flujo real: el caller lo saca del inventario y después suelta.
	player.inventory.remove(item3)
	player.drop_item(item3)
	await process_frame
	await process_frame
	ok(_conteo_pickables(root) == world_antes3, "no apareció ningún objeto en el mundo")
	ok(_esta_en_inventario(player, item3), "el item volvió al inventario (no se pierde)")

	print("=== 5) La escena prefabricada puesta a mano (decoración en el mundo) ===")
	var n: PickableItem = load(PICKABLE_SCENE).instantiate()
	n.item_descriptor = descriptor
	root.add_child(n)
	await process_frame
	var areas5 := 0
	for c in _todos(n):
		if c is Area3D and c.get_collision_layer_value(2):
			areas5 += 1
	ok(areas5 == 1, "queda un solo área en la capa 2 (la de la escena, sin duplicar)")
	ok(n.get_node_or_null("Colision").shape is ConvexPolygonShape3D,
			"la colisión convexa se generó desde el mesh del descriptor")
	ok(n.collision_layer == 2, "la raíz está en la capa 2")
	n.queue_free()

	print("=== 6) Asignar el descriptor (como el editor vía @tool) ===")
	# Como en el flujo real: el descriptor se asigna ANTES de entrar al árbol.
	var m: PickableItem = load(PICKABLE_SCENE).instantiate()
	var descriptor_rot := MiscItemDescriptor.new()
	descriptor_rot.item_name = "objeto decorado"
	descriptor_rot.dimensions = Vector2i(1, 1)
	descriptor_rot.item_mesh = SphereMesh.new()
	m.item_descriptor = descriptor_rot
	root.add_child(m)
	await process_frame
	ok(m.get_node("Malla").mesh == descriptor_rot.item_mesh, "el mesh del descriptor quedó en Malla")
	var colision6 := m.get_node("Colision") as CollisionShape3D
	ok(colision6.shape is ConvexPolygonShape3D, "generó la colisión convexa")
	# Cambiar el recurso con el nodo YA en el árbol (lo que hace el editor al
	# reasignar el descriptor en el inspector): la malla se actualiza sola.
	m.item_descriptor = descriptor
	ok(m.get_node("Malla").mesh == descriptor.item_mesh, "reasignar el descriptor actualiza la malla")
	# Decorar a mano: rotar la malla. En el editor _process hace esta misma
	# sincronización; acá se llama directo para simularlo.
	var forma_antes: Shape3D = colision6.shape
	var malla6 := m.get_node("Malla") as MeshInstance3D
	malla6.rotation.z = PI / 2.0
	m._sincronizar_colision()
	# Contrato tras E-012: Godot no soporta escalar cuerpos/formas de
	# colisión, así que la transformación de la malla se HORNEA en los
	# puntos del casco y "Colision" queda con transformación identidad.
	ok(colision6.transform == Transform3D.IDENTITY,
			"Colision queda en identidad (la transformación se hornea)")
	var pts6 := (colision6.shape as ConvexPolygonShape3D).points
	var bruto := malla6.mesh.create_convex_shape(false, false)
	var esperados: PackedVector3Array = []
	for p in (bruto as ConvexPolygonShape3D).points:
		esperados.append(malla6.transform * p)
	var sigue := pts6.size() == esperados.size()
	if sigue:
		for i in pts6.size():
			if pts6[i].distance_to(esperados[i]) > 0.000001:
				sigue = false
				break
	ok(sigue, "la colisión sigue a la malla rotada (puntos horneados)")
	ok(colision6.shape != forma_antes, "regeneró el casco convexo al cambiar la malla")
	m.queue_free()

	print("")
	if fallos == 0:
		print("RESULTADO: TODO OK")
	else:
		print("RESULTADO: %d FALLO(S)" % fallos)
	quit(1 if fallos > 0 else 0)


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
