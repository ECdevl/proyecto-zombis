extends Node
class_name TutorialDirector
## Director del tutorial del prototipo jugable.
## Muestra pistas del "game instructor" (mundo y pantalla) para enseñar las mecánicas.
## Añádalo a la escena de juego o úselo de forma global; localizará al jugador.
## Las pistas se muestran mediante el autoload `Instructor`.

@export var player: Player
@export var auto_start: bool = true

var _step: int = -1
var _move_accum: Vector2 = Vector2.ZERO
var _step_time: float = 0.0
var _picked_target: Node3D = null
var _enemy_target: Node3D = null

const HINT_SCREEN: StringName = &"tutorial_screen"
const HINT_WORLD: StringName = &"tutorial_world"


func _ready() -> void:
	if player == null:
		player = get_tree().get_first_node_in_group(&"player") as Player
	if auto_start:
		call_deferred("start")


func _process(delta: float) -> void:
	if _step < 0 or player == null:
		return
	_step_time += delta
	_refresh_screen_hint()
	_update_step(delta)


func start() -> void:
	if player == null:
		return
	_step = 0
	_start_step()


func _next_step() -> void:
	Instructor.hide_hint(HINT_SCREEN)
	Instructor.hide_hint(HINT_WORLD)
	_picked_target = null
	_enemy_target = null
	_step += 1
	_step_time = 0.0
	_start_step()


func _start_step() -> void:
	_move_accum = Vector2.ZERO
	match _step:
		0:
			_show_keys("Usa %s %s %s %s para moverte", [&"forward", &"left", &"back", &"right"])
		1:
			_show_keys("Mantén %s para correr", [&"shift"])
		2:
			_show_keys("Pulsa %s para saltar", [&"space"])
		3:
			_show_keys("Mantén %s para agacharte", [&"ctrl"])
		4:
			_show_keys("Pulsa %s para tumbarte", [&"prone"])
		5:
			_show_keys("Usa %s %s para inclinarte", [&"lean_left", &"lean_right"])
		6:
			_start_pickup_step()
		7:
			_show_keys("Pulsa %s para abrir/cerrar el inventario", [&"toggle_inventory"])
		8:
			_show_keys("Pulsa %s para soltar el objeto equipado", [&"drop"])
		9:
			_show_keys("Pulsa %s para atacar o disparar", [&"M1"])
		10:
			_show_keys("Pulsa %s para dar un golpe", [&"punch"])
		11:
			_show_keys("Pulsa %s para recargar (armas de fuego)", [&"reload"])
		12:
			_show_keys("Usa %s %s %s %s para las ranuras rápidas", [&"slot1", &"slot2", &"slot3", &"slot4"])
		13:
			_start_enemy_step()
		_:
			_show_text("Tutorial completado. Buena suerte, Señor.")
			# La pista final se deja visible unos segundos y luego se retira.
			await get_tree().create_timer(6.0).timeout
			Instructor.hide_hint(HINT_SCREEN)


func _update_step(delta: float) -> void:
	match _step:
		0:
			var input_dir: Vector2 = Input.get_vector(&"left", &"right", &"forward", &"back")
			_move_accum += input_dir.abs() * delta
			if _move_accum.x + _move_accum.y > 0.8:
				_next_step()
		1:
			if Input.is_action_pressed(&"shift") and player.velocity.length() > 0.5:
				_next_step()
		2:
			if Input.is_action_just_pressed(&"space") and _step_time > 0.2:
				_next_step()
		3:
			if Input.is_action_pressed(&"ctrl"):
				_next_step()
		4:
			if Input.is_action_just_pressed(&"prone") and _step_time > 0.2:
				_next_step()
		5:
			if Input.is_action_pressed(&"lean_left") or Input.is_action_pressed(&"lean_right"):
				_next_step()
		6:
			_update_pickup_step()
		7:
			if Input.is_action_just_pressed(&"toggle_inventory") and _step_time > 0.2:
				_next_step()
		8:
			if Input.is_action_just_pressed(&"drop") and _step_time > 0.2:
				_next_step()
		9:
			if Input.is_action_just_pressed(&"M1") and _step_time > 0.2:
				_next_step()
		10:
			if Input.is_action_just_pressed(&"punch") and _step_time > 0.2:
				_next_step()
		11:
			if Input.is_action_just_pressed(&"reload") and _step_time > 0.2:
				_next_step()
		12:
			if Input.is_action_just_pressed(&"slot1") or Input.is_action_just_pressed(&"slot2") or Input.is_action_just_pressed(&"slot3") or Input.is_action_just_pressed(&"slot4"):
				_next_step()
		13:
			_update_enemy_step()


# --- Pasos con objetivo en el mundo ---------------------------------------

func _start_pickup_step() -> void:
	_picked_target = _find_nearest_pickable()
	if _picked_target == null:
		_show_keys("Pulsa %s para usar/recoger cuando mires un objeto", [&"use"])
		return
	var label: String = _pickup_label(_picked_target)
	var key_text: String = Instructor.get_action_key_bbcode(&"use", false)
	Instructor.show_world_hint(HINT_WORLD, _picked_target, "Recoger: %s  %s" % [label, key_text], Instructor.INSTRUCTOR_ICON_WARN)
	_show_keys("Acércate y pulsa %s para recoger", [&"use"])


func _update_pickup_step() -> void:
	if _picked_target == null:
		# Sin objetivo concreto: avanza al usar o tras un tiempo razonable.
		if Input.is_action_just_pressed(&"use") or _step_time > 8.0:
			_next_step()
		return
	if not is_instance_valid(_picked_target) or not _picked_target.is_inside_tree():
		_next_step()
		return
	# Si el objetivo cambió de validez o se recogió, la pista de mundo se auto-limpia.
	if Input.is_action_just_pressed(&"use") and _step_time > 0.2:
		# Damos un margen: si en el siguiente ciclo ya no existe, se completará.
		pass


func _start_enemy_step() -> void:
	_enemy_target = _find_nearest_enemy()
	if _enemy_target == null:
		_show_text("No hay enemigos cercanos en este momento.")
		await get_tree().create_timer(3.0).timeout
		if _step == 13:
			_next_step()
		return
	var key_text: String = Instructor.get_action_key_bbcode(&"M1", false)
	Instructor.show_world_hint(HINT_WORLD, _enemy_target, "Enemigo  %s" % key_text, Instructor.INSTRUCTOR_ICON_WARN)
	_show_text("Apunta al enemigo y elimínalo.")


func _update_enemy_step() -> void:
	if _enemy_target == null:
		return
	if not is_instance_valid(_enemy_target):
		_next_step()
		return
	if _enemy_target is Zombie:
		var zombie: Zombie = _enemy_target as Zombie
		if zombie.get("is_dead") == true:
			_next_step()


# --- Presentación de pistas -----------------------------------------------

func _show_keys(template: String, actions: Array) -> void:
	_current_template = template
	_current_actions = actions.duplicate()
	_refresh_screen_hint()


func _show_text(text_value: String) -> void:
	_current_template = text_value
	_current_actions = []
	Instructor.show_screen_hint(HINT_SCREEN, text_value, "")


var _current_template: String = ""
var _current_actions: Array = []


func _refresh_screen_hint() -> void:
	if _current_template.is_empty():
		return
	if _current_actions.is_empty():
		return
	var parts: Array = []
	for action_name: Variant in _current_actions:
		var action: StringName = StringName(str(action_name))
		parts.append(Instructor.get_action_key_bbcode(action, Input.is_action_pressed(action)))
	var label: String = _current_template % parts
	Instructor.show_screen_hint(HINT_SCREEN, label, "")


# --- Búsqueda de objetivos ------------------------------------------------

func _find_nearest_pickable() -> Node3D:
	var nearest: Node3D = null
	var best_dist: float = INF
	var pickables: Array = get_tree().get_nodes_in_group(&"pickable")
	if pickables.is_empty():
		pickables = _collect_nodes_of_class(get_tree().root, "PickableItem")
	for node: Variant in pickables:
		if node is Node3D:
			var n3: Node3D = node as Node3D
			var dist: float = player.global_position.distance_to(n3.global_position)
			if dist < best_dist:
				best_dist = dist
				nearest = n3
	return nearest


func _find_nearest_enemy() -> Node3D:
	var nearest: Node3D = null
	var best_dist: float = INF
	var enemies: Array = _collect_nodes_of_class(get_tree().root, "Zombie")
	for node: Variant in enemies:
		if node is Zombie:
			var z: Zombie = node as Zombie
			if z.get("is_dead") == true:
				continue
			var dist: float = player.global_position.distance_to(z.global_position)
			if dist < best_dist:
				best_dist = dist
				nearest = z
	return nearest


func _collect_nodes_of_class(root: Node, class_name_str: String) -> Array:
	var result: Array = []
	if root.is_class(class_name_str) or (root.get_script() != null and root.get_script().get_global_name() == class_name_str):
		result.append(root)
	for child: Node in root.get_children():
		result.append_array(_collect_nodes_of_class(child, class_name_str))
	return result


func _pickup_label(node: Node3D) -> String:
	if node is PickableItem:
		var pickable: PickableItem = node as PickableItem
		if pickable.item_descriptor != null:
			return str(pickable.item_descriptor.item_name)
	return node.name
