extends CharacterBody3D
class_name Zombie
## Zombie base: everything shared by any zombie.
##
## How to make a special zombie without touching this file:
##   1. Scene: start from `scenes/zombies/zombie.tscn` and change the mesh,
##      exported values (`speed`, `claw_damage`, `health_component`)
##      and the StateMachine nodes. Each state is a child node with its
##      own script, so they can be added or removed from the editor.
##   2. Behavior: subclass with `extends Zombie` overriding the
##      `_on_hurted()` and `_on_died()` hooks. If you also change `hurted()`
##      or `die()`, make sure to call `super` to avoid losing the common code.
##
## Unique node names: contract with the scene. Every zombie scene must have
## these, because this script looks them up with `%`:
##   %Nav, %Vision, %AT, %StateMachine, %LookHead, %RagdollComponent
## Additionally, `zombie_ap` and `zombie_mesh` are expected to be exported
## in the scene.

# --- References (unique name; see note above) ---
@onready var nav: NavigationAgent3D = %Nav
@onready var vision: ZombieVision = %Vision
@onready var at: AnimationTree = %AT
@onready var look_head: LookAtModifier3D = %LookHead
@onready var state_machine: StateMachine = %StateMachine
@onready var ragdoll_component: ZombieRagdoll = %RagdollComponent

# --- Data (each scene sets these in the inspector) ---
@export var health_component: HealthComponent
@export var zombie_ap: AnimationPlayer
@export var zombie_mesh: MeshInstance3D
@export var speed: float = 2.5
@export var claw_damage: float = 10.0
## Yaw speed used when the zombie rotates toward something (deg/s). Shared by
## `chase` (steering while walking) and `turn` (turning to a heard noise).
@export var turn_speed_deg: float = 90.0

# --- Debugging ///
## Prints state changes (read by StateMachine).
@export var can_debug: bool = false
## Enables permanent ragdoll with M1, for testing.
@export var ragdoll_text: bool = false

var playback: AnimationNodeStateMachinePlayback

signal pushed(direction: Vector3)

const BLOOD_SPLATTER = preload("res://scenes/components/blood_splatter.tscn")


func _ready() -> void:
	playback = at.get("parameters/zombie_sm/playback")
	# The RVO of `Nav` uses `max_speed` as the cap of its simulation. Without
	# synchronizing it with `speed`, avoidance calculates with 10 m/s (the
	# engine default) even if the zombie walks at 1.5 (see D-015).
	nav.max_speed = speed

	if health_component:
		health_component = health_component.duplicate()
		health_component.death.connect(die)
		health_component.hurted.connect(hurted)


func _input(event: InputEvent) -> void:
	if ragdoll_text and event.is_action_pressed("M1"):
		ragdoll_component.start(true)


## Pushes the zombie: listened by `stagger` and `stun` states.
func push(direction: Vector3) -> void:
	pushed.emit(direction)


# ---------------------------------------------------------------------------
# Damage
# ---------------------------------------------------------------------------

## Receives damage (connected to `health_component.hurted`). The flinch, blood
## and leg check are common to all zombies; what is specific to a special
## zombie is added in `_on_hurted()`.
func hurted(damage: float, info: Dictionary) -> void:
	_play_flinch()

	if info.is_empty():
		return

	var who := info.get("who") as Node3D
	var attacker := info.get("attacker") as Node3D
	var hit_pos := _resolve_hit_pos(info, who)

	# No attacker means no blood splash direction, but the hit still counts.
	if attacker != null:
		var towards_attacker := hit_pos.direction_to(attacker.global_position)
		# GameManager.blood_splatter(hit_pos, towards_attacker, who)
		_spawn_decals(hit_pos, towards_attacker)

	if who != null:
		if who.is_in_group("zombie_legs_left"):
			# Leg hit: emit stun state finished.
			print_debug("OH MY LEG")
			state_machine.state.finished.emit("stun", {"direction": 1})
		elif who.is_in_group("zombie_legs_right"):
			print_debug("OH MY LEG")
			state_machine.state.finished.emit("stun", {"direction": 0})
		else:
			# Other hits: stagger only. The death/ragdoll path goes through
			# health <= 0 -> die() -> permanent ragdoll; there is no
			# ragdoll-after-stagger timer here.
			# A melee swing whose X is exactly 0 (vertical chop, thrust) does
			# not push the zombie: no stagger is emitted at all.
			var sx : Variant = info.get("swing")
			if (sx is float or sx is int) and is_zero_approx(float(sx)) or sx == null:
				pass  # no lo empuja
			else:
				state_machine.state.finished.emit("hurt", {"blend":sx})

	_on_hurted(damage, info)


## Hook: special zombie reaction to damage. Subclasses override this and,
## if they want to keep the common code, call `super._on_hurted(damage, info)`.
func _on_hurted(_damage: float, _info: Dictionary) -> void:
	pass


## Dies (connected to `health_component.death`): transitions to the `death`
## state, which starts the permanent ragdoll with the impact impulse.
func die(damage: float, info: Dictionary) -> void:
	state_machine.state.finished.emit("death")
	
	var impulse := _vec3(info, "impulse")
	var force := _num(info, "force")
	# Without built-in impulse (a bullet does not bring it), the direction is
	# stored in a meta while the impact is resolved.
	if impulse.length_squared() < 0.0001 and has_meta("melee_hit_dir"):
		impulse = get_meta("melee_hit_dir") as Vector3
		if force <= 0.0:
			force = 800.0

	ragdoll_component.start(true, impulse, force, _find_hit_bone(info))

	if has_meta("melee_hit_dir"):
		remove_meta("melee_hit_dir")

	_on_died(damage, info)


## Hook: custom code at death (drop an object, explode, etc.).
func _on_died(_damage: float, _info: Dictionary) -> void:
	pass


func _play_flinch() -> void:
	at["parameters/flinch_var/blend_position"] = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	at["parameters/flinch/request"] = 1


## Impact point. If it did not come or is not finite (NaN/inf), the position
## of the hitbox is used, and if there is no hitbox, the zombie's own position.
func _resolve_hit_pos(info: Dictionary, who: Node3D) -> Vector3:
	var hit_pos: Variant = info.get("hit_pos")
	if hit_pos is Vector3 and (hit_pos as Vector3).is_finite():
		return hit_pos as Vector3
	if who != null:
		return who.global_position
	return global_position


## The zombie's hitboxes are named the same as `PhysicalBone3D` (e.g.
## "Physical Bone spine"), so the hit bone is found by name.
## If there is no hitbox or it does not match, it returns null and the
## impulse goes to the pelvis (see `ZombieRagdoll.start()`).
func _find_hit_bone(info: Dictionary) -> PhysicalBone3D:
	var hitbox := info.get("who") as Node
	if hitbox == null or ragdoll_component.simulator == null:
		return null
	return ragdoll_component.simulator.find_child(hitbox.name) as PhysicalBone3D


## `info[key]` as Vector3; anything that is not a Vector3 is Vector3.ZERO.
func _vec3(info: Dictionary, key: String) -> Vector3:
	var v: Variant = info.get(key)
	return v if v is Vector3 else Vector3.ZERO


## `info[key]` as float; anything that is not a number is 0.0.
func _num(info: Dictionary, key: String) -> float:
	var v: Variant = info.get(key)
	return float(v) if (v is float or v is int) else 0.0


func _spawn_decals(pos: Vector3, to_attacker: Vector3) -> void:
	var fx: BloodSplatter = BLOOD_SPLATTER.instantiate()
	get_tree().current_scene.add_child(fx)
	fx.splash(pos, to_attacker, -to_attacker)  # (point, normal, bullet direction)


# ---------------------------------------------------------------------------
# Utilities shared by states
# ---------------------------------------------------------------------------

func handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += get_gravity().y * delta


func _on_ragdoll_component_ragdoll_started() -> void:
	print_debug("RAGDOLL")
	vision.can_see = false
	state_machine.state.finished.emit("stun", {"ragdoll": true})
