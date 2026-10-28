extends PlayerState
@onready var viewmodel_sway: Node = %ViewmodelSway

@export var stamina_cost : float = 1.5
func enter(previous_state_path: String, data := {}) -> void:
	viewmodel_sway.bob_speed = 10.0
	player.body_at_playback.travel("walk_dir")
	var tree := player.viewmodel_animation_tree if player.viewmodel_animation_tree else player.animation_tree
	if not player.get_current_weapon():
		if tree:
			tree["parameters/run/blend_amount"] = 1.0
	else:
		player.weapon_controller.weapon_ap.play("run")
	player.speed = player.sprint_speed

func update(_delta: float) -> void:
	player._camera_movement()
	player.player_needs.current_stamina -= 5.0 * _delta
	if player.player_needs.current_stamina <= 0:
		finished.emit("walk")
		return

func physics_update(_delta: float) -> void:
	if player.velocity.x == 0 and player.velocity.z == 0:
		finished.emit("idle")
	if Input.is_action_just_released(player.sprint):
		finished.emit("walk")
	if Input.is_action_just_pressed(player.jump):
		finished.emit("jump")

func exit(next_state_path:String) -> void:
	viewmodel_sway.bob_speed = 5.0
	var tree := player.viewmodel_animation_tree if player.viewmodel_animation_tree else player.animation_tree
	if not player.get_current_weapon():
		if tree:
			tree["parameters/run/blend_amount"] = 0.0
	else:
		player.weapon_controller.weapon_ap.play("idle")
	if not player.get_current_weapon():
		if player.playback:
			player.playback.travel("idle")
