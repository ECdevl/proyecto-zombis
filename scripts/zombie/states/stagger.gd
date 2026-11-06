extends ZombieState
## Push: the zombie recoils in the direction of the push and then recovers.
## Input: data = {"direction": Vector3, "swing_x": float} (direction does not need to be normalized)
##
## Mathematics (summary):
##   Speed decreases linearly from v0 to 0 in T seconds.
##   Distance traveled = area of triangle = v0 * T / 2
##   => v0 = 2 * d / T        (initial speed)
##   => a  = v0 / T           (deceleration per second)
##
## Animation selection:
##   - Melee hits pass `swing_x` (the X of the SwingData direction in camera space):
##     positive = swing to the right, negative = swing to the left. X == 0 never
##     reaches this state (Zombie.hurted() does not emit it).
##   - Pushes decompose the push direction in the zombie's local frame:
##     f = dir · facing, s = dir · right. If |s| > |f| it is a lateral push and
##     s decides left or right; otherwise the push is frontal/back.
##
## State to return to when finished. If there is no target, "chase" sends
## it to "idle".
@export var next_state: StringName = &"chase"
## Nodes of the AnimationTree (state machine "zombie_sm").
## Pushed from behind: falls forward. Pushed from front: falls backward.
@export var anim_from_behind: StringName = &"stumble_forward"
@export var anim_from_front: StringName = &"stumble_back"
## Lateral pushes (y == 0 plane).
@export var anim_left: StringName = &"stumble_left"
@export var anim_right: StringName = &"stumble_right"
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

var push_distance : float
func enter(_previous_state_path: String, data := {}) -> void:
	stagger_count += 1
	# Empujado demasiadas veces seguidas: este empujón arranca el ragdoll a
	# MITAD de la animación de stagger (ver `_start_ragdoll_mid_stagger`).
	var wants_ragdoll : bool = stagger_count >= max_stagger
	if wants_ragdoll:
		stagger_count = 0

	# Dirección del empujón. El dato puede venir vacío o con un tipo inválido
	# (por ejemplo un int desde `Zombie.hurted`): si no es Vector3, cae al frente.
	var dir : Vector3 = zombie.global_basis.z
	var raw : Variant = data.get("direction", dir)
	if raw is Vector3:
		dir = raw
	dir.y = 0.0
	if dir.is_zero_approx():
		dir = zombie.global_basis.z  # sin dirección: cae hacia atrás
	dir = dir.normalized()

	# --- Selección de animación ---
	# Un golpe melee pasa `swing_x` (X de la dirección del swing en espacio
	# local de la cámara). El arma manda: positivo = tajo a la derecha,
	# negativo = tajo a la izquierda. El caso X == 0 no llega aquí: lo filtra
	# `Zombie.hurted()` (el zombi no es empujado).
	# Un empujón descompone la dirección en el marco local del zombi:
	#   f = dir · facing  (+ = empujado por la espalda)
	#   s = dir · right   (+ = empujado hacia su derecha)
	# Si el componente lateral gana (|s| > |f|), es un empujón de lado.
	var facing : Vector3 = -zombie.global_basis.z
	var frame_right : Vector3 = zombie.global_basis.x
	var anim_name : StringName
	var from_behind : bool = false
	var lateral : bool = false
	var swing_x : Variant = data.get("swing_x")
	push_distance = knockback_distance
	if swing_x is float or swing_x is int:
		stagger_count -= 1
		push_distance = 1.5
		swing_x *= -1
		var sx : float = float(swing_x)
		lateral = sx != 0.0
		anim_name = anim_right if sx > 0.0 else anim_left
	else:
		var f : float = dir.dot(facing)
		var s : float = dir.dot(frame_right)
		lateral = absf(s) > absf(f)
		if lateral:
			anim_name = anim_right if s > 0.0 else anim_left
			push_distance = 1.0
		else:
			from_behind = f >= 0.0
			anim_name = anim_from_behind if from_behind else anim_from_front
	var stun_time : float = zombie.at.get_animation(anim_name).length
	var speed : float = 2.0 * push_distance / stun_time
	_decel = speed / stun_time
	_time_left = stun_time

	zombie.velocity.x = dir.x * speed
	zombie.velocity.z = dir.z * speed

	zombie.playback.start(anim_name)

	if wants_ragdoll:
		_start_ragdoll_mid_stagger(dir, stun_time)

	# Hacia dónde debe mirar al caer:
	#   por la espalda -> mira en la dirección del empujón (de espaldas al jugador)
	#   de frente      -> mira al revés del empujón (de cara al jugador)
	#   de lado        -> mantiene el yaw actual (no gira 90° al ser empujado)
	# Yaw que hace que el frente (-Z) apunte a un vector v: atan2(-v.x, -v.z)
	if lateral:
		_target_yaw = zombie.rotation.y
	else:
		var look_dir : Vector3 = dir if from_behind else -dir
		_target_yaw = atan2(-look_dir.x, -look_dir.z)


func physics_update(delta: float) -> void:
	zombie.handle_gravity(delta)

	# Frena en línea recta hasta 0, manteniendo la dirección.
	var horizontal : Vector2 = Vector2(zombie.velocity.x, zombie.velocity.z)
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

## Requisito del usuario (T-013): cuando el zombi acumula `max_stagger`
## empujones, el ragdoll arranca a media animación de stagger (~50%), no de
## inmediato. La animación de stumble se reproduce normal; la física sigue
## frenando al zombi hasta que el ragdoll toma el control.
func _start_ragdoll_mid_stagger(dir: Vector3, stun_time: float) -> void:
	await get_tree().create_timer(stun_time * 0.25).timeout
	if zombie.state_machine.state != self:
		# Murió, se recuperó o fue empujado de nuevo: no forzar ragdoll.
		return
	zombie.ragdoll_component.start(false, dir, 50)
