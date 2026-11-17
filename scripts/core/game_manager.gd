extends Node

const BLOOD = preload("res://scenes/effects/blood_burst.tscn")
const BLOOD_DECALS = preload("res://scenes/components/blood_splatter.tscn")

var pause_menu_scene: PackedScene = preload("res://scenes/ui/pause_menu.tscn")
var _pause_menu: CanvasLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()

func toggle_pause() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var current_scene := tree.current_scene
	if current_scene == null:
		return
	var player : Player = null
	for node in get_tree().get_nodes_in_group("player"):
		if node is Player:
			player = node
			break
	# No pausar mientras el jugador está muerto o con una UI bloqueada.
	if player != null and (player.is_dead or player.is_input_locked()):
		return
	if tree.paused:
		resume()
		return
	tree.paused = true
	if _pause_menu == null or not is_instance_valid(_pause_menu):
		_pause_menu = pause_menu_scene.instantiate()
		add_child(_pause_menu)
	_pause_menu.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func resume() -> void:
	if get_tree().paused:
		get_tree().paused = false
	if is_instance_valid(_pause_menu):
		_pause_menu.hide()
	if not player_is_dead():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func player_is_dead() -> bool:
	for node in get_tree().get_nodes_in_group("player"):
		if node is Player and node.is_dead:
			return true
	return false

func blood_splatter(hit_pos: Vector3, direction: Vector3 = Vector3.UP, strength: float = 1.0, follow: Node3D = null) -> void:
	# `follow` se conserva por compatibilidad pero ya no se usa: el chorro es
	# de mundo y vive 0.9 s; seguir al cuerpo no aporta nada. Queda ignorado.
	var burst: BloodBurst = BLOOD.instantiate()
	get_tree().current_scene.add_child(burst)
	burst.spray(hit_pos, direction, strength)
	var fx: BloodSplatter = BLOOD_DECALS.instantiate()
	get_tree().current_scene.add_child(fx)
	fx.splash(hit_pos, -direction, direction, strength)


# _follow eliminado: el chorro actual es de mundo (ver blood_splatter).
