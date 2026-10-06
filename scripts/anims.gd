@tool
extends EditorScenePostImport

func _post_import(scene: Node) -> Object:
	print("Post import corriendo en: ", scene.name)
	var player_scene = load("res://scenes/player.tscn").instantiate()
	var player_anim = player_scene.get_node("Yaw").get_node("Pitch").get_node("armsy").get_node("AnimationPlayer")
	var weapon_anim = scene.get_node("AnimationPlayer")
	
	# Crear librería nueva con animaciones del player
	var weapon_lib = AnimationLibrary.new()
	for anim_name in player_anim.get_animation_list():
		var anim = player_anim.get_animation(anim_name)
		weapon_lib.add_animation(anim_name, anim)
	
	weapon_anim.add_animation_library("player_anims", weapon_lib)
	
	# AnimationTree
	var anim_tree = AnimationTree.new()
	
	#anim_tree.name = "AnimationTree"
	#anim_tree.anim_player = NodePath("AnimationPlayer")
	scene.add_child(anim_tree)
	
	var player_tree = player_scene.get_node("AnimationTree")
	if player_tree.tree_root:
		anim_tree.tree_root = player_tree.tree_root.duplicate()
		
	player_scene.queue_free()
	print("AnimationTree agregado: ", scene.has_node("AnimationTree"))
	print("✓ Synced: ", scene.name)
	print("Árbol completo:")
	_print_tree(scene, 0)
	
	return scene

func _print_tree(node: Node, depth: int) -> void:
	print("  ".repeat(depth), node.name, " (", node.get_class(), ")")
	for child in node.get_children():
		_print_tree(child, depth + 1)
