extends Node
class_name ViewmodelAnimator

## Envuelve el AnimationTree de `scenes/weapons/viewmodel_tree.tscn` para un viewmodel.
## El state machine interno maneja las animaciones del arma (draw/idle/run/shoot/etc.)
## y la capa `context` (Blend2) mezcla animaciones contextuales (ctx_*.tres) sobre el
## brazo izquierdo sin tocar el state machine.

var root: Node3D
var ap: AnimationPlayer
var tree: AnimationTree
var playback: AnimationNodeStateMachinePlayback

const TREE_SCENE_PATH: String = "res://scenes/weapons/viewmodel_tree.tscn"

func setup(p_root: Node3D) -> void:
	root = p_root
	ap = p_root.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap == null:
		ap = p_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null:
		return

	# Cargar todas las animaciones contextuales disponibles en la librería por defecto.
	var lib: AnimationLibrary = ap.get_animation_library(&"")
	if lib == null:
		lib = AnimationLibrary.new()
		ap.add_animation_library(&"", lib)
	var dir: DirAccess = DirAccess.open("res://resources/viewmodels")
	if dir != null:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and (file_name.ends_with(".tres") or file_name.ends_with(".res")) and file_name.begins_with("ctx_"):
				var loaded: Resource = load("res://resources/viewmodels/" + file_name)
				if loaded is Animation:
					var anim_name: StringName = StringName(file_name.get_basename())
					if not lib.has_animation(anim_name):
						lib.add_animation(anim_name, loaded as Animation)
			file_name = dir.get_next()
		dir.list_dir_end()

	var tree_scene: PackedScene = load(TREE_SCENE_PATH) as PackedScene
	if tree_scene == null:
		return
	tree = tree_scene.instantiate() as AnimationTree
	if tree == null:
		return
	tree.name = "ViewmodelAnimationTree"
	tree.anim_player = ap.get_path()
	root.add_child(tree)
	# El filtrado se resuelve en runtime: el esqueleto real del viewmodel no
	# existe en el editor, por lo que los paths de huesos se arman acá.
	var blend_tree : AnimationNodeBlendTree = tree.tree_root
	var blend_node : AnimationNodeBlend2 = blend_tree.get_node("context")
	var skeleton: Skeleton3D = root.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton != null:
		var upper_idx: int = SkeletonUtils.find_upper_arm_left_index(skeleton)
		if upper_idx >= 0:
			var bone_names: PackedStringArray = PackedStringArray()
			var stack: Array[int] = [upper_idx]
			while not stack.is_empty():
				var idx: int = stack.pop_back()
				bone_names.append(skeleton.get_bone_name(idx))
				for i in skeleton.get_bone_count():
					if skeleton.get_bone_parent(i) == idx:
						stack.append(i)
			var skel_path: String = root.get_path_to(skeleton)
			for bname in bone_names:
				blend_node.set_filter_path(NodePath("%s:%s" % [skel_path, bname]), true)
	blend_node.filter_enabled = true
	tree.active = true
	playback = tree.get("parameters/main_sfm/playback") as AnimationNodeStateMachinePlayback
	if playback != null:
		playback.travel("idle")

func _ensure_playback() -> AnimationNodeStateMachinePlayback:
	if playback == null and tree != null:
		playback = tree.get("parameters/main_sfm/playback") as AnimationNodeStateMachinePlayback
		if playback != null:
			playback.travel("idle")
	return playback

func play_base(anim_name: StringName) -> void:
	var pb: AnimationNodeStateMachinePlayback = _ensure_playback()
	if pb == null:
		return
		
	pb.travel(anim_name)
func fire_shot(anim_name: StringName) -> void:
	var pb: AnimationNodeStateMachinePlayback = _ensure_playback()
	if pb == null:
		return
	pb.start(anim_name)

func set_context(anim_name: StringName, weight: float) -> void:
	if tree != null and anim_name != &"":
		# La animación debe existir en la librería (ctx_*.tres) para que el
		# nodo `context_anim` del árbol pueda referenciarla por nombre.
		if ap != null and ap.has_animation(anim_name):
			var blend_tree: AnimationNodeBlendTree = tree.tree_root as AnimationNodeBlendTree
			if blend_tree != null:
				var ctx_anim: AnimationNodeAnimation = blend_tree.get_node("context_anim") as AnimationNodeAnimation
				if ctx_anim != null:
					ctx_anim.animation = anim_name
					
	set_context_weight(weight)

func set_context_weight(weight: float) -> void:
	if tree != null:
		var tween = create_tween()
		tween.tween_property(tree,"parameters/context/blend_amount",clamp(weight, 0.0, 1.0),.25)


func is_anim_active(anim_name: StringName) -> bool:
	var pb: AnimationNodeStateMachinePlayback = _ensure_playback()
	if pb == null:
		return false
	return pb.get_current_node() == anim_name


func is_swing_active() -> bool:
	return is_anim_active(&"swing1") or is_anim_active(&"swing2")


func is_shot_active() -> bool:
	var pb: AnimationNodeStateMachinePlayback = _ensure_playback()
	if pb == null:
		return false
	var current: StringName = pb.get_current_node()
	return current != &"idle" and current != &"run"
