class_name ArmsAnimator extends RefCounted
## Envuelve el AnimationTree que ya existe en `player.tscn` para armsy.
## Expone la misma interfaz que usa FlashlightController sobre el viewmodel,
## para que la capa ctx_flashlight siga sonando cuando no hay arma equipada.
## No reproduce animaciones con AnimationPlayer.play: todo pasa por el tree.

var tree: AnimationTree
var ap: AnimationPlayer
var playback: AnimationNodeStateMachinePlayback


func setup(p_tree: AnimationTree, p_ap: AnimationPlayer) -> void:
	tree = p_tree
	ap = p_ap
	if tree == null:
		return
	tree.active = true
	playback = tree.get("parameters/player_sm/playback") as AnimationNodeStateMachinePlayback
	if playback != null:
		playback.start("idle")


func play_base(anim_name: StringName) -> void:
	if playback == null:
		return
	if playback.get_current_node() != anim_name:
		playback.travel(anim_name)


func fire_shot(anim_name: StringName) -> void:
	if tree == null:
		return
	# El tree de armsy solo tiene one-shots para grab y punch.
	if anim_name == &"punch":
		tree["parameters/punch/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
	elif anim_name == &"grab":
		tree["parameters/grab/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE


func set_context(anim_name: StringName, weight: float) -> void:
	if tree != null and anim_name != &"" and ap != null and ap.has_animation(anim_name):
		var blend_tree: AnimationNodeBlendTree = tree.tree_root as AnimationNodeBlendTree
		if blend_tree != null:
			var ctx_anim: AnimationNodeAnimation = blend_tree.get_node("context_anim") as AnimationNodeAnimation
			if ctx_anim != null:
				ctx_anim.animation = anim_name
	set_context_weight(weight)


func set_context_weight(weight: float) -> void:
	if tree == null:
		return
	var tween: Tween = tree.create_tween()
	tween.tween_property(tree, "parameters/context/blend_amount", clampf(weight, 0.0, 1.0), .25)
