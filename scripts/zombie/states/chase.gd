extends ZombieState

var target : Node3D = null

@export var forget_time : float = 3.0
@export var grab_range : float = 3
@export var can_grab : bool = false

@export var claw_rate : float = .5

## Half-angle (degrees) of the cone in which the zombie can hit. Outside it,
## the zombie keeps walking (and therefore turning) instead of clawing over
## its shoulder. 70 deg matches the 120 deg sight cone loosely.
@export var attack_angle_deg : float = 70.0

# Tiempo entre el arranque de la animacion de ataque y el momento del impacto.
const ATTACK_IMPACT_DELAY : float = 0.46
const GRAB_IMPACT_DELAY : float = 0.4

var stop : bool = false
@onready var claw_timer: Timer = %claw_timer
## Yaw that points the zombie's front (-Z) at the next path position.
var _steer_yaw : float = 0.0
## Below this horizontal speed (m/s) the zombie is considered standing, so it
## must not rotate: no turning in place.
const STILL_SPEED : float = 0.05

func enter(previous_state_path: String, data := {}) -> void:
	zombie.vision.can_see = true
	zombie.playback.travel("walk")
	target = zombie.vision.target
	_steer_yaw = zombie.rotation.y
	stop = false
	# Body-locked head: no `LookAtModifier3D` snap toward the player. The
	# zombie has to turn its whole body while walking to face him (D-018).
	zombie.look_head.target_node = NodePath()
	zombie.look_head.influence = 0.0


func physics_update(delta: float) -> void:
	zombie.handle_gravity(delta)


	if not is_instance_valid(target):
		zombie.nav.target_position = zombie.global_position
		finished.emit("idle")
		return
	zombie.nav.target_position = target.global_position

	# `get_next_path_position()` hay que llamarla en CADA frame de física
	# para que el agente avance su lógica de camino, aunque esté parado.
	var siguiente : Vector3 = zombie.nav.get_next_path_position()
	var steer : Vector3 = siguiente - zombie.global_position
	steer.y = 0.0
	if steer.length_squared() > 0.0001:
		_steer_yaw = atan2(-steer.x, -steer.z)

	# El zombi solo camina HACIA ADELANTE (su frente, -Z). No strafea ni se
	# mueve hacia atrás: para apuntar a otra dirección tiene que girar el
	# cuerpo mientras camina (ver el giro limitado más abajo).
	var forward : Vector3 = -zombie.global_basis.z
	forward.y = 0.0
	if forward.length_squared() > 0.0001:
		forward = forward.normalized()

	# Velocidad deseada para el RVO. `set_velocity` recibe la velocidad
	# REAL en m/s: el resultado que devuelve `velocity_computed` ya está en
	# m/s y NO se vuelve a multiplicar por `speed` (ver D-015: eso duplicaba
	# la velocidad, speed² en vez de speed).
	var deseada : Vector3 = Vector3.ZERO
	if not stop:
		deseada = forward * zombie.speed
	zombie.nav.set_velocity(deseada)

	zombie.move_and_slide()

	# Giro hacia el rumbo de la ruta a velocidad limitada. Solo mientras camina:
	# parado no gira (no pivotar en el sitio, no snap).
	var horizontal : Vector2 = Vector2(zombie.velocity.x, zombie.velocity.z)
	if horizontal.length() > STILL_SPEED:
		zombie.rotation.y = rotate_toward(zombie.rotation.y, _steer_yaw,
			deg_to_rad(zombie.turn_speed_deg) * delta)


func update(_delta: float) -> void:

	if not is_instance_valid(target):
		finished.emit("idle")
		return

	# El marcador de "objetivo perdido" no es un enemigo: se camina hasta él,
	# se libera y se vuelve a idle. Nunca se ataca.
	if target is Marker3D:
		if _distance_to_target() <= grab_range:
			stop = true
			zombie.playback.travel("idle1")
			(target as Marker3D).queue_free()
			finished.emit("idle")
		else:
			stop = false
			zombie.playback.travel("walk")
		return

	if _distance_to_target() <= grab_range and is_facing_target():
		# Solo ataca si ya quedó de frente. Si no, sigue caminando: el giro
		# limitado del cuerpo es el que lo pone de cara al jugador.
		# If the player moved away, the zombie should stop attacking.
		attack()
		stop = true
		zombie.playback.travel("idle1")
	else:
		stop = false
		zombie.playback.travel("walk")
	

func exit(next_state_path:String) -> void:
	zombie.at["parameters/grab/request"] = 2
	zombie.at["parameters/attack/request"] = 2
	zombie.velocity = Vector3.ZERO
	claw_timer.stop()
	zombie.look_head.influence = 0.0
	

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
	
	# Si el objetivo dejó de ser válido o se alejó, no atacar.
	if target is Marker3D:
		return
	var distance : float = _distance_to_target()
	if distance > grab_range:
		return

	if not claw_timer.is_stopped():
		print_debug(claw_timer.time_left)
		return
	print_debug("KILL")
	var want_grab : bool = can_grab and target is Player and randf() < 0.5

	if want_grab:
		claw_timer.start(claw_rate)
		zombie.at["parameters/grab/request"] = 1
		await get_tree().create_timer(GRAB_IMPACT_DELAY).timeout
		hurt_target(true)
		return

	claw_timer.start(claw_rate)
	var random_attack : Vector2i = Vector2i(randi_range(-1,1),randi_range(-1,1))
	zombie.at["parameters/attack_var/blend_position"] = random_attack
	zombie.at["parameters/attack/request"] = 1
	await get_tree().create_timer(ATTACK_IMPACT_DELAY).timeout
	hurt_target(false)
	
func hurt_target(grab:bool = false) -> void:

	if not is_instance_valid(target):
		return
	if not target is Player:
		return
	var distance : float = _distance_to_target()
	if distance > grab_range:
		return
	var player : Player = target as Player
	if grab:
		if zombie.state_machine.state == self:
			
			zombie.at["parameters/grab/request"] = 3
			finished.emit("grab")
	else:
		if zombie.state_machine.state == self:
			
			player.health_component.hurt(zombie.claw_damage, {"attacker": zombie, "hit_pos": zombie.global_position})


## Distancia en metros al objetivo; INF si no hay objetivo válido.
func _distance_to_target() -> float:
	if not is_instance_valid(target):
		return INF
	return zombie.global_position.distance_to(target.global_position)


## True when the body's front (-Z) is within `attack_angle_deg` of the target.
## It does not consider height: a zombie on a ramp still faces you.
func is_facing_target() -> bool:
	if not is_instance_valid(target):
		return false
	var to_target : Vector3 = target.global_position - zombie.global_position
	to_target.y = 0.0
	if to_target.length_squared() < 0.0001:
		return true
	var forward : Vector3 = -zombie.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return false
	return forward.normalized().dot(to_target.normalized()) >= cos(deg_to_rad(attack_angle_deg))


## Callback del RVO: `Nav` devuelve la velocidad ya desviada para no chocar
## con los demás agentes. Es la única fuente de movimiento del zombi mientras
## persigue, así que esta función es la que aplica la velocidad a la escena.
## El giro del cuerpo se hace en `physics_update` (a `turn_speed_deg`).
func _on_nav_velocity_computed(safe_velocity: Vector3) -> void:
	# La señal está cableada en la escena, así que sigue llegando aunque el
	# zombi haya salido de `chase` (stun, death, stagger...). Si no somos el
	# estado activo no pisamos la velocidad que esté usando el otro estado.
	if zombie.state_machine.state != self:
		return

	# `safe_velocity` ya viene en m/s: no se multiplica por `speed` otra vez.
	zombie.velocity.x = safe_velocity.x
	zombie.velocity.z = safe_velocity.z


## `Nav.target_reached` → la escena la tiene cableada. Es el único sitio que
## libera el `Marker3D` que deja `_on_vision_target_lost()` cuando el jugador
## se pierde de vista: sin él el zombi perseguiría el marcador para siempre.
func _on_nav_target_reached() -> void:
	if target is Marker3D:
		target.queue_free()
		finished.emit("idle")
