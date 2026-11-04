extends CharacterBody3D
class_name Zombie
## Zombi base: todo lo compartido por cualquier zombi.
##
## Cómo se arma un zombi especial SIN tocar este archivo:
##   1. Escena: partir de `scenes/zombies/zombie.tscn` y cambiar la malla,
##      los valores exportados (`speed`, `claw_damage`, `health_component`)
##      y los nodos del `StateMachine`. Cada estado es un nodo hijo con su
##      propio script, así que se agregan o quitan desde el editor.
##   2. Comportamiento: subclase con `extends Zombie` sobreescribiendo los
##      hooks `_on_hurted()` y `_on_died()`. Si además se cambia `hurted()`
##      o `die()`, hay que llamar a `super` para no perder lo común.
##
## Nodos de nombre único: son contrato con la escena. Toda escena de zombi
## debe tenerlos, porque este script los busca con `%`:
##   %Nav, %Vision, %AT, %StateMachine, %LookHead, %RagdollComponent
## Además se esperan exportados en la escena: `zombie_ap`, `zombie_mesh`.

# --- Referencias (nombre único; ver nota arriba) ---
@onready var nav: NavigationAgent3D = %Nav
@onready var vision: ZombieVision = %Vision
@onready var at: AnimationTree = %AT
@onready var look_head: LookAtModifier3D = %LookHead
@onready var state_machine: StateMachine = %StateMachine
@onready var ragdoll_component: ZombieRagdoll = %RagdollComponent

# --- Datos (cada escena los pone en el inspector) ---
@export var health_component: HealthComponent
@export var zombie_ap: AnimationPlayer
@export var zombie_mesh: MeshInstance3D
@export var speed: float = 2.5
@export var claw_damage: float = 10.0

# --- Depuración ---
## Imprime los cambios de estado (lo lee `StateMachine`).
@export var can_debug: bool = false
## Permite arrancar el ragdoll permanente con M1, para probarlo.
@export var ragdoll_text: bool = false

var playback: AnimationNodeStateMachinePlayback

signal pushed(direction: Vector3)

const BLOOD_SPLATTER = preload("res://scenes/components/blood_splatter.tscn")


func _ready() -> void:
	playback = at.get("parameters/zombie_sm/playback")
	# El RVO de `Nav` usa `max_speed` como tope de su simulación. Sin
	# sincronizarlo con `speed` el avoidance calcula con 10 m/s (default del
	# motor) aunque el zombi vaya a 1.5 (ver D-015).
	nav.max_speed = speed

	if health_component:
		health_component = health_component.duplicate()
		health_component.death.connect(die)
		health_component.hurted.connect(hurted)


func _input(event: InputEvent) -> void:
	if ragdoll_text and event.is_action_pressed("M1"):
		ragdoll_component.start(true)


## Empuja al zombi: lo escuchan los estados `stagger` y `stun`.
func push(direction: Vector3) -> void:
	pushed.emit(direction)


# ---------------------------------------------------------------------------
# Daño
# ---------------------------------------------------------------------------

## Recibe el daño (conectado a `health_component.hurted`). El flinch, la
## sangre y el chequeo de piernas son comunes a todos los zombis; lo propio
## de un zombi especial se agrega en `_on_hurted()`.
func hurted(damage: float, info: Dictionary) -> void:
	_play_flinch()

	if info.is_empty():
		return

	var who := info.get("who") as Node3D
	var attacker := info.get("attacker") as Node3D
	var hit_pos := _resolve_hit_pos(info, who)

	# Sin atacante no hay hacia dónde salpicar, pero el golpe sigue contando.
	if attacker != null:
		var hacia_atacante := hit_pos.direction_to(attacker.global_position)
		GameManager.blood_splatter(hit_pos, hacia_atacante, who)
		_spawn_decals(hit_pos, hacia_atacante)

	if who != null:
		if who.is_in_group("zombie_legs_left"):
			print_debug("OH MY LEG")
			state_machine.state.finished.emit("stun", {"direction": 1})
		elif who.is_in_group("zombie_legs_right"):
			print_debug("OH MY LEG")
			state_machine.state.finished.emit("stun", {"direction": 0})

	_on_hurted(damage, info)


## Muere (conectado a `health_component.death`): cambia al estado `death`,
## arranca el ragdoll permanente con el impulso del golpe y avisa por el
## hook `_on_died()`.
func die(damage: float, info: Dictionary) -> void:
	state_machine.state.finished.emit("death")

	var impulse := _vec3(info, "impulse")
	var force := _num(info, "force")

	# Sin impulso propio (una bala no lo trae), el golpe cuerpo a cuerpo
	# guarda la dirección en una meta mientras se resuelve el impacto.
	if impulse.length_squared() < 0.0001 and has_meta("melee_hit_dir"):
		impulse = get_meta("melee_hit_dir") as Vector3
		if force <= 0.0:
			force = 800.0

	ragdoll_component.start(true, impulse, force, _find_hit_bone(info))

	if has_meta("melee_hit_dir"):
		remove_meta("melee_hit_dir")

	_on_died(damage, info)


## Hook: reacción propia de un zombi especial al recibir daño. Las
## subclases lo sobreescriben y, si quieren conservar lo común, llaman a
## `super._on_hurted(damage, info)`.
func _on_hurted(_damage: float, _info: Dictionary) -> void:
	pass


## Hook: código propio al morir (soltar un objeto, explotar, etc.).
func _on_died(_damage: float, _info: Dictionary) -> void:
	pass


func _play_flinch() -> void:
	at["parameters/flinch_var/blend_position"] = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	at["parameters/flinch/request"] = 1


## Punto de impacto. Si no vino o no es finito (NaN/inf) se usa la posición
## del hitbox golpeado, y si tampoco hay hitbox, la del propio zombi.
func _resolve_hit_pos(info: Dictionary, who: Node3D) -> Vector3:
	var hit_pos: Variant = info.get("hit_pos")
	if hit_pos is Vector3 and (hit_pos as Vector3).is_finite():
		return hit_pos as Vector3
	if who != null:
		return who.global_position
	return global_position


## Los hitboxes del zombi se llaman igual que los `PhysicalBone3D` (p. ej.
## "Physical Bone spine"), así que el hueso golpeado se busca por nombre.
## Si no hay hitbox o no coincide, devuelve null y el impulso va a la
## pelvis (ver `ZombieRagdoll.start()`).
func _find_hit_bone(info: Dictionary) -> PhysicalBone3D:
	var hitbox := info.get("who") as Node
	if hitbox == null or ragdoll_component.simulator == null:
		return null
	return ragdoll_component.simulator.find_child(hitbox.name) as PhysicalBone3D


## `info[key]` como Vector3; lo que no sea Vector3 vale Vector3.ZERO.
func _vec3(info: Dictionary, key: String) -> Vector3:
	var v: Variant = info.get(key)
	return v if v is Vector3 else Vector3.ZERO


## `info[key]` como float; lo que no sea número vale 0.0.
func _num(info: Dictionary, key: String) -> float:
	var v: Variant = info.get(key)
	return float(v) if (v is float or v is int) else 0.0


func _spawn_decals(pos: Vector3, to_attacker: Vector3) -> void:
	var fx: BloodSplatter = BLOOD_SPLATTER.instantiate()
	get_tree().current_scene.add_child(fx)
	fx.splash(pos, to_attacker, -to_attacker)  # (punto, normal, dirección de la bala)


# ---------------------------------------------------------------------------
# Utilidades compartidas por los estados
# ---------------------------------------------------------------------------

func stagger(attacker: Node3D) -> void:
	if not attacker:
		return

	var forward = global_basis.z
	state_machine.state.finished.emit("stagger", {
		"dot": forward.dot(attacker.global_position.direction_to(global_position)),
		"attacker": attacker,
	})


func handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += get_gravity().y * delta


func _on_ragdoll_component_ragdoll_started() -> void:
	print_debug("RAGDOLL")
	vision.can_see = false
	state_machine.state.finished.emit("stun", {"ragdoll": true})
