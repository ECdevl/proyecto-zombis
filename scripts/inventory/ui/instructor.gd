extends Node
## Autoload global del "game instructor".
## Permite mostrar pistas de tutorial/ayuda desde cualquier lugar:
## - ancladas a un objeto 3D (objeto a recoger, enemigo, etc.),
## - o fijas en pantalla (teclas/controles), sin señalar un objetivo.
## Delega la presentación en la UI activa (contenedor de instructor).

const INSTRUCTOR_ICON_WARN: String = "res://assets/sprites/instructor_warn.png"
const KEY_DARK_DIR: String = "res://assets/sprites/keys/Dark/"
const KEY_LIGHT_DIR: String = "res://assets/sprites/keys/Light/"
const INSTRUCT_DOOR : String = "res://assets/sprites/instructor/INSTRUCT_DOOR.png"
const INSTRUCT_GRAB : String = "res://assets/sprites/instructor/INSTRUCT_GRAB.png"
const INSTRUCT_GUARD : String = "res://assets/sprites/instructor/INSTRUCT_GUARD.png"
const INSTRUCT_HINT : String = "res://assets/sprites/instructor/INSTRUCT_HINT.png"
const INSTRUCT_INFO : String = "res://assets/sprites/instructor/INSTRUCT_INFO.png"
const INSTRUCT_USE : String = "res://assets/sprites/instructor/INSTRUCT_USE.png"



func _get_ui() -> UI:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	# La UI vive como parte del jugador; se localiza por tipo.
	for node: Node in tree.get_nodes_in_group(&"player"):
		var ui_node: UI = _find_ui(node)
		if ui_node != null:
			return ui_node
	# Respaldo: búsqueda en la raíz.
	return _find_ui(tree.root)


func _find_ui(node: Node) -> UI:
	if node == null:
		return null
	if node is UI:
		return node as UI
	for child: Node in node.get_children():
		var found: UI = _find_ui(child)
		if found != null:
			return found
	return null


# --- Teclas (sprites Dark = sin pulsar, Light = pulsada) -----------------

## Devuelve el sprite de una tecla si existe en assets/sprites/keys/.
func get_key_icon_path(file_name: String, pressed: bool = false) -> String:
	var base_dir: String = KEY_LIGHT_DIR if pressed else KEY_DARK_DIR
	var path: String = base_dir + file_name
	if ResourceLoader.exists(path):
		return path
	return ""


## Devuelve el nombre de archivo de sprite para un evento de entrada, o "" si no hay sprite.
func get_key_sprite_name(event: InputEvent) -> String:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		var code: Key = key_event.physical_keycode
		if code == KEY_NONE:
			code = key_event.keycode
		if code >= KEY_A and code <= KEY_Z:
			return char(code) + "-Key.png"
		if code >= KEY_0 and code <= KEY_9:
			return char(code) + "-Key.png"
		match code:
			KEY_SPACE:
				return "Space-Key.png"
			KEY_SHIFT:
				return "Shift-Key.png"
			KEY_TAB:
				return "Tab-Key.png"
			KEY_ENTER, KEY_KP_ENTER:
				return "Enter-Key.png"
			KEY_CAPSLOCK:
				return "Caps-Key.png"
			KEY_MINUS, KEY_KP_SUBTRACT:
				return "Minus-Key.png"
			KEY_EQUAL, KEY_KP_ADD, KEY_PLUS:
				return "Plus-Key.png"
		return ""
	return ""


## BBCode de la tecla asociada a una acción (sprite si existe; si no, texto).
func get_action_key_bbcode(action: StringName, pressed: bool = false, img_size: int = 40) -> String:
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	if events.is_empty():
		return "[b]?[/b]"
	var event: InputEvent = events[0]
	var sprite_name: String = get_key_sprite_name(event)
	if not sprite_name.is_empty():
		var icon: String = get_key_icon_path(sprite_name, pressed)
		if not icon.is_empty():
			return "[img=%d]%s[/img]" % [img_size, icon]
	return "[b][%s][/b]" % event.as_text()


# --- Pistas ---------------------------------------------------------------

## Pista anclada a un objetivo 3D (objeto a recoger, enemigo, etc.).
func show_world_hint(id: StringName, target: Node3D, label: String, icon_path: String = INSTRUCTOR_ICON_WARN) -> RichTextLabel:
	var ui: UI = _get_ui()
	if ui == null:
		return null
	return ui.show_world_hint(id, target, label, icon_path)


## Pista fija en pantalla (sin señalar un objeto), ideal para indicar teclas.
func show_screen_hint(id: StringName, label: String, icon_path: String = "", anchor_preset: int = Control.PRESET_CENTER_BOTTOM, anchor_offset: Vector2 = Vector2(0, -120)) -> RichTextLabel:
	var ui: UI = _get_ui()
	if ui == null:
		return null
	return ui.show_screen_hint(id, label, icon_path, anchor_preset, anchor_offset)


## Cierra una pista por id.
func hide_hint(id: StringName) -> void:
	var ui: UI = _get_ui()
	if ui == null:
		return
	ui.hide_hint(id)


## Cierra todas las pistas cuyo objetivo 3D sea 'body'.
func hide_hints_for_target(body: Node3D) -> void:
	var ui: UI = _get_ui()
	if ui == null:
		return
	ui.hide_hints_for_target(body)
