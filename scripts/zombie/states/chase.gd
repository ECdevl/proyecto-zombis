extends ZombieState

var target : Node3D

@export var forget_time : float = 3.0
@export var grab_range : float = 1.5

@export var grab_time : float = 2.0
@export var claw_rate : float = .5
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
	
	zombie.playback.travel("walk")
	if target is Node3D:
		zombie.nav.target_position = target.global_position
	else:
		finished.emit("idle")
		return
	var target_rot : float = atan2(-zombie.direction.x,-zombie.direction.z)
	zombie.rotation.y = rotate_toward(zombie.rotation.y, target_rot, deg_to_rad(720) * _delta)
	var distance_to_target = zombie.global_position.distance_squared_to(target.global_position)


		

	if distance_to_target < zombie.nav.target_desired_distance:
		stop = false
		zombie.playback.travel("idle1")
		return
	zombie.nav.get_next_path_position()
	zombie.direction = zombie.global_position.direction_to(zombie.nav.get_next_path_position())

	if zombie.direction != Vector3.ZERO:
		zombie.velocity.x = zombie.direction.x * zombie.speed
		zombie.velocity.z = zombie.direction.z * zombie.speed


	zombie.move_and_slide()

func update(_delta: float) -> void:


	var distance_to_target = zombie.global_position.distance_squared_to(target.global_position)
	if distance_to_target <= grab_range * grab_range:
		print_debug(distance_to_target)
		attack()

func exit(next_state_path:String) -> void:
	zombie.at["parameters/grab/request"] = 2
	zombie.at["parameters/attack/request"] = 2
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
	

func attack() -> void:
	
	var distance =zombie.global_position.distance_squared_to(target.global_position)
	if not claw_timer.is_stopped(): 
		return
	
	var claw_or_grab : int
	claw_or_grab = randi_range(0,1)
	
	if distance >= grab_range:
		claw_or_grab = 0
	
	
	if claw_or_grab == 0:
		claw_timer.start(claw_rate)
		if zombie.zombie_ap.current_animation.contains("attack"):
			await zombie.at.animation_finished
		var random_attack : Vector2i = Vector2i(randi_range(-1,1),randi_range(-1,1))
		zombie.at["parameters/attack_var/blend_position"] = random_attack
		zombie.at["parameters/attack/request"] = 1
		await zombie.at.animation_started
		await get_tree().create_timer(0.46).timeout
		hurt_target()
		return
	else:
		claw_timer.start(claw_rate)
		if zombie.zombie_ap.current_animation.contains("attack"):
			await zombie.at.animation_finished
		var d2 := zombie.global_position.distance_squared_to(target.global_position)
		if d2 <= grab_range * grab_range:
			zombie.at["parameters/grab/request"] = 1
			await get_tree().create_timer(0.4).timeout
			hurt_target(true)
			
			return
	
@onready var hit_box: Area3D = %HitBox

func hurt_target(grab:bool = false) -> void:
	
	if target:
		var d2 := zombie.global_position.distance_squared_to(target.global_position)
		if target is Player:
			if grab:
				if d2 <= grab_range * grab_range:
					zombie.at["parameters/grab/request"] = 3
					finished.emit("grab")
					return
			else:
				if hit_box.get_overlapping_bodies().is_empty():
					return
				if hit_box.get_overlapping_bodies()[0] is CharacterBody3D:
					hit_box.get_overlapping_bodies()[0].health_component.hurt(zombie.claw_damage)

func _on_nav_target_reached() -> void:
	if target is Marker3D:
		target.queue_free()
		finished.emit("idle")
	else:
		stop = true
		claw_timer.start(claw_rate)
		
