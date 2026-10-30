extends ZombieState

var target : Node3D

@export var forget_time : float = 3.0
@export var grab_range : float = 1.5

@export var grab_time : float = 2.0
@export var claw_rate : float = .5
@export var claw_range : float = 2.0
var to_grab : bool = false

var stop : bool = false
@onready var claw_timer: Timer = %claw_timer

func enter(previous_state_path: String, data := {}) -> void:
	zombie.vision.can_see = true
	to_grab = false
	zombie.playback.travel("walk")
	target = zombie.vision.target
	var tween = create_tween().set_parallel(true)
	tween.tween_property(zombie.look_head,"influence",1.0,.5)


func physics_update(_delta: float) -> void:
	zombie.handle_gravity(_delta)
	
	if zombie.playback.get_current_node() in ["awake_up","awake_down"] or zombie.ragdoll_component.is_ragdoll:
		zombie.velocity = Vector3.ZERO
		return
	else:
		zombie.playback.travel("walk")
	if target is Node3D:
		zombie.nav.target_position = target.global_position
	else:
		finished.emit("idle")
		return
	var target_rot : float = atan2(-zombie.direction.x,-zombie.direction.z)
	zombie.rotation.y = rotate_toward(zombie.rotation.y, target_rot, deg_to_rad(720) * _delta)
	
	if zombie.global_position.distance_squared_to(target.global_position) <= claw_range:
		
		if claw_timer.is_stopped():
			claw_timer.start(claw_rate)
		
	else:
		if not claw_timer.is_stopped():
			claw_timer.stop()

		

	if zombie.global_position.distance_squared_to(target.global_position) < zombie.nav.target_desired_distance:
		stop = false
		zombie.playback.start("idle1")
		return
	zombie.nav.get_next_path_position()
	zombie.direction = zombie.global_position.direction_to(zombie.nav.get_next_path_position())

	if zombie.direction != Vector3.ZERO:
		zombie.velocity.x = zombie.direction.x * zombie.speed
		zombie.velocity.z = zombie.direction.z * zombie.speed


	zombie.move_and_slide()

func exit(next_state_path:String) -> void:
	
	zombie.velocity = Vector3.ZERO
	claw_timer.stop()
	var tween = create_tween().set_parallel(true)
	tween.tween_property(zombie.look_head,"influence",0.0,.5)

	
func _on_vision_target_lost(lost: Node3D) -> void:
	print_debug("target lost")
	await get_tree().create_timer(forget_time).timeout
	if zombie.state_machine.state == self:
		print_debug("finaly lost him")
		
		var player_pos : Marker3D = Marker3D.new()
		get_tree().current_scene.add_child(player_pos)
		player_pos.global_position = lost.global_position
		target = player_pos
	

func claw() -> void:
	var claw_or_grab : int = randi_range(0,8)
	claw_or_grab = claw_or_grab % 2
	if claw_or_grab == 0:
		if claw_timer.time_left <= 0.0 :

			var random_attack : Vector2i = Vector2i(randi_range(-1,1),randi_range(-1,1))
			zombie.at["parameters/attack_var/blend_position"] = random_attack
			zombie.at["parameters/attack/request"] = 1
			await zombie.at.animation_started
			await get_tree().create_timer(0.46).timeout
			hurt_target()
			return
	else:
		var d2 := zombie.global_position.distance_squared_to(target.global_position)
		if d2 <= grab_range * grab_range:
			zombie.at["parameters/grab/request"] = 1
			await get_tree().create_timer(0.5).timeout
			hurt_target(true)
			
			return

func hurt_target(grab:bool = false) -> void:
	if target:
		var d2 := zombie.global_position.distance_squared_to(target.global_position)
		if d2 <= grab_range * grab_range:
			if target is Player:
				if grab:
					zombie.at["parameters/grab/request"] = 3
					finished.emit("grab")
					return
				else:
					target.health_component.hurt(zombie.claw_damage)

func _on_nav_target_reached() -> void:
	if target is Marker3D:
		target.queue_free()
		finished.emit("idle")
	else:
		stop = true
		claw_timer.start(claw_rate)
		
