extends PlayerState
## Brazos agarrados: arma oculta, forcejeo y barra de escape.

signal progress_changed(value: float)  # 0 a 1, por si la UI la quiere mostrar
signal progress_show

@export var struggle_action: StringName = &"struggle"
@export var gain_per_press := 0.12
@export var decay_per_second := 0.25
@onready var weapon_controller: WeaponController = %WeaponController
@onready var view_punch: ViewPunch = %ViewPunch
@onready var camera_shake: PlayerComponent = %CameraShake

var progress := 0.0
var _weapon: Node3D

func enter(_previous_state_path: String, _data := {}) -> void:

	weapon_controller.push_enabled = false
	progress = 0.0
	_weapon = player.weapon_controller.weapon_node
	if is_instance_valid(_weapon):
		_weapon.hide()
	progress_show.emit()

func handle_input(event: InputEvent) -> void:
	if not event.is_action_pressed(struggle_action):
		return
	progress = minf(progress + gain_per_press, 1.0)
	progress_changed.emit(progress)
	#if player.animation_tree:
		#player.animation_tree["parameters/struggle/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
	if progress >= 1.0:
		player.grab_escaped.emit()
var view_punch_camera2 : Node3D
func update(delta: float) -> void:
	view_punch_camera2 = view_punch.camera2
	view_punch.camera = null
	view_punch.punch(Vector2(randf_range(-1,1),randf_range(-1,1)))
	if progress > 0.0:
		progress = maxf(progress - decay_per_second * delta, 0.0)
		progress_changed.emit(progress)

func exit(_next_state_path: String) -> void:
	view_punch.camera = view_punch_camera2
	player.playback.start("grabbed_end")
	weapon_controller.push_enabled = true
	if is_instance_valid(_weapon):
		_weapon.show()
	# Por ahora solo pistola; después se elige según el tipo de arma.
	player.playback.travel("pistol_idle" if player.get_current_weapon() else "idle")
