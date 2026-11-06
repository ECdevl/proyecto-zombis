extends ZombieState
## Turn: the zombie hears a noise and slowly rotates its body toward the
## source, instead of snapping. Built for the future hearing system; usable
## right now from any state:
##
##   state_machine.state.finished.emit("turn", {"direction": dir_to_source})
##   state_machine.state.finished.emit("turn", {"yaw": yaw_in_radians})
##
## `direction` is a world-space Vector3; only its XZ projection is used. If
## neither `direction` (non-zero) nor `yaw` is present, the state does nothing
## and goes straight back to `next_state`.
##
## The body is rotated by code at `zombie.turn_speed_deg` (90 deg/s by
## default) — the same export `chase` uses — so the turn is never instant and
## it respects the "no turning in place outside a turn animation" rule.
## The turn animation (when it is authored) must be an in-place turn WITHOUT
## root yaw rotation, like the hurt/stagger anims: this script owns the yaw.
##
## Animation hook-up: fill `anim_left`/`anim_right` with the state names of
## the `zombie_sm` AnimationTree (or leave `&""` for none, the current state).
## Sign convention: delta_yaw > 0 (turning the front toward -X) plays
## `anim_left`, otherwise `anim_right`; swap the exports if your anims are
## authored the opposite way.
##
## Finishes when the body faces the source (within `yaw_epsilon_deg`) or when
## `max_turn_time` expires (safety net in case the target moves or no
## animation exists), then emits `next_state`.

@export var next_state: StringName = &"idle"
## States of `zombie_sm` to play during the turn. `&""` = no animation yet.
@export var anim_left: StringName = &""
@export var anim_right: StringName = &""
@export var yaw_epsilon_deg: float = 2.0
@export var max_turn_time: float = 8.0

var _target_yaw: float = 0.0
var _time_left: float = 0.0


func enter(previous_state_path: String, data := {}) -> void:
	zombie.velocity = Vector3.ZERO

	var yaw: Variant = data.get("yaw")
	if yaw is float or yaw is int:
		_target_yaw = float(yaw)
	else:
		var raw: Variant = data.get("direction")
		if not (raw is Vector3):
			finished.emit(next_state)
			return
		var dir: Vector3 = raw as Vector3
		dir.y = 0.0
		if dir.length_squared() < 0.0001:
			finished.emit(next_state)
			return
		_target_yaw = atan2(-dir.x, -dir.z)

	_time_left = max_turn_time
	var delta_yaw: float = wrapf(_target_yaw - zombie.rotation.y, -PI, PI)
	var anim: StringName = anim_left if delta_yaw >= 0.0 else anim_right
	if anim != &"":
		zombie.playback.travel(String(anim))


func physics_update(delta: float) -> void:
	zombie.velocity.x = 0
	zombie.velocity.z = 0
	zombie.handle_gravity(delta)
	zombie.move_and_slide()

	zombie.rotation.y = rotate_toward(zombie.rotation.y, _target_yaw,
		deg_to_rad(zombie.turn_speed_deg) * delta)

	_time_left -= delta
	var remaining: float = absf(wrapf(_target_yaw - zombie.rotation.y, -PI, PI))
	if remaining <= deg_to_rad(yaw_epsilon_deg) or _time_left <= 0.0:
		finished.emit(next_state)


func exit(next_state_path: String) -> void:
	zombie.velocity = Vector3.ZERO
