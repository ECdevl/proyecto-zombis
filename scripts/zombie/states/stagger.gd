extends ZombieState
## Push: the zombie recoils in the direction of the push and then recovers.
## Input: data = {"direction": Vector3} (does not need to be normalized)
##
## Mathematics (summary):
##   Speed decreases linearly from v0 to 0 in T seconds.
##   Distance traveled = area of triangle = v0 * T / 2
##   => v0 = 2 * d / T        (initial speed)
##   => a  = v0 / T           (deceleration per second)
##
## State to return to when finished. If there is no target, "chase" sends
## it to "idle".
@export var next_state: StringName = &"chase"
## Nodes of the AnimationTree (state machine "zombie_sm").
## Pushed from behind: falls forward. Pushed from front: falls backward.
@export var anim_from_behind: StringName = &"stumble_forward"
@export var anim_from_front: StringName = &"stumble_back"
## How far it recoils (meters).
@export var knockback_distance: float = 1.0


## How fast it turns to align with the push (degrees per second).
@export var turn_speed_deg: float = 720.0
@export var max_stagger : int = 3

var _decel: float
var _time_left: float
var _target_yaw: float

var stagger_count : int

func _ready() -> void:
	super()  # ZombieState._ready assigns `zombie`
	if not zombie.pushed.is_connected(_on_zombie_pushed):
		zombie.pushed.connect(_on_zombie_pushed)


func enter(_previous_state_path: String, data := {}) -> void:
	stagger_count += 1
	

	var dir: Vector3 = data.get("direction", zombie.global_basis.z)
	if stagger_count >= max_stagger:
		# After 3 consecutive stagger hits, start ragdoll immediately
		# rather than playing another animation.
		zombie.ragdoll_component.start(false,dir,50)
		stagger_count = 0
		return
	# Producto punto: +1 = misma dirección, -1 = opuesta, 0 = perpendicular.
	# El zombi mira hacia -Z. Si el empujón va hacia donde mira, lo empujaron por la espalda.
	var facing := -zombie.global_basis.z
	var from_behind := dir.dot(facing) >= 0.0
	
	dir.y = 0.0
	if dir.is_zero_approx():
		dir = zombie.global_basis.z  # sin dirección: cae hacia atrás
	dir = dir.normalized()
	var stun_time : float
	stun_time = zombie.at.get_animation(anim_from_behind if from_behind else anim_from_front).length
	var speed := 2.0 * knockback_distance / stun_time
	_decel = speed / stun_time
	_time_left = stun_time

	zombie.velocity.x = dir.x * speed
	zombie.velocity.z = dir.z * speed

	zombie.playback.start(anim_from_behind if from_behind else anim_from_front)

	# Hacia dónde debe mirar al caer:
	#   por la espalda -> mira en la dirección del empujón (de espaldas al jugador)
	#   de frente      -> mira al revés del empujón (de cara al jugador)
	# Yaw que hace que el frente (-Z) apunte a un vector v: atan2(-v.x, -v.z)
	var look_dir := dir if from_behind else -dir
	_target_yaw = atan2(-look_dir.x, -look_dir.z)


func physics_update(delta: float) -> void:
	zombie.handle_gravity(delta)

	# Frena en línea recta hasta 0, manteniendo la dirección.
	var horizontal := Vector2(zombie.velocity.x, zombie.velocity.z)
	horizontal = horizontal.move_toward(Vector2.ZERO, _decel * delta)
	zombie.velocity.x = horizontal.x
	zombie.velocity.z = horizontal.y
	zombie.move_and_slide()

	# Gira por el camino más corto, sin pasarse del ángulo objetivo.
	zombie.rotation.y = rotate_toward(zombie.rotation.y, _target_yaw, deg_to_rad(turn_speed_deg) * delta)






func _on_zombie_pushed(direction: Vector3) -> void:
	# If already stunned, can_transition = false ignores it (does not stack stun).
	finished.emit(name, {"direction": direction})


func _on_at_animation_finished(anim_name: StringName) -> void:
	if anim_name.contains("stumble"):
		finished.emit(next_state)