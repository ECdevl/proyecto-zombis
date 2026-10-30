extends Node

const BLOOD = preload("uid://t3pfbgv7i028")

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
	# Solo pausar si hay un Player en la escena actual
	if current_scene.find_child("Player", true, false) == null and get_tree().get_first_node_in_group("player") == null:
		# Buscar por clase
		var players = get_tree().get_nodes_in_group("player")
		if players.is_empty():
			# Intentar encontrar nodos con clase Player
			var stack = [current_scene]
			while not stack.is_empty():
				var n = stack.pop_front()
				if n is Player:
					break
				else:
					return
				for c in n.get_children():
					stack.append(c)

	get_tree().paused = not get_tree().paused
	if get_tree().paused:
		if _pause_menu == null or not is_instance_valid(_pause_menu):
			_pause_menu = pause_menu_scene.instantiate()
			add_child(_pause_menu)
		_pause_menu.show()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		if is_instance_valid(_pause_menu):
			_pause_menu.hide()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func resume() -> void:
	if get_tree().paused:
		get_tree().paused = false
	if is_instance_valid(_pause_menu):
		_pause_menu.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func blood_splatter(hit_pos: Vector3, direction := Vector3.UP, follow: Node3D = null) -> void:
	var sangre = BLOOD.instantiate()
	sangre.particle_direction = direction
	get_tree().current_scene.add_child(sangre)
	sangre.global_position = hit_pos
	if follow:
		var local_offset := follow.global_transform.affine_inverse() * hit_pos
		_follow(sangre, follow, local_offset)


func _follow(fx: Node3D, target: Node3D, local_offset: Vector3) -> void:
	while is_instance_valid(fx) and is_instance_valid(target):
		fx.global_position = target.global_transform * local_offset
		await get_tree().process_frame
