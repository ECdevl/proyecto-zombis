extends ZombieState

@export var grab_anchor: Marker3D
@export var damage_tick : float = 1.5
var player: Player

func enter(previous_state_path: String, _data := {}) -> void:
	_land_grab()

@onready var hurt_grab: Timer = %HurtGrab

# Call on the frame when the animation touches the player:
func _land_grab() -> void:
	var candidate : Node3D = zombie.vision.target
	if not candidate is Player:
		finished.emit("chase")
		return
	var target_player : Player = candidate as Player
	if not target_player.can_be_grabbed():
		# Otro zombi ya lo tiene: este vuelve a chase y ataca.
		finished.emit("chase")
		return
	if not target_player.get_grabbed(zombie, grab_anchor):
		finished.emit("chase")
		return
	player = target_player
	player.playback.start("grabbed_start", true)
	zombie.playback.start("grab_start", true)
	hurt_grab.start(damage_tick)
	player.grab_escaped.connect(_on_escaped, CONNECT_ONE_SHOT)
	zombie.grab_sound.play()
	if not player.player_death.is_connected(_on_player_died):
		player.player_death.connect(_on_player_died)


func update(_delta: float) -> void:
	if not is_instance_valid(player):
		finished.emit("idle")
		return
	if player.is_dead or player.grabber != zombie:
		finished.emit("idle")
		return


func physics_update(_delta: float) -> void:
	zombie.handle_gravity(_delta)
	if not is_instance_valid(player):
		finished.emit("idle")
		return
	if player.is_dead or player.grabber != zombie:
		finished.emit("idle")
		return


func _on_escaped() -> void:
	if zombie.state_machine.state != self:
		return
	if is_instance_valid(player):
		zombie.push(zombie.global_position - player.global_position)  # triggers stagger


func _on_player_died() -> void:
	if zombie.state_machine.state == self:
		finished.emit("idle")


func exit(_next_state_path: String) -> void:
	if player and is_instance_valid(player):
		if player.grab_escaped.is_connected(_on_escaped):
			player.grab_escaped.disconnect(_on_escaped)
		if player.player_death.is_connected(_on_player_died):
			player.player_death.disconnect(_on_player_died)
		if player.grabber == zombie:
			player.end_grab()  # the grabber releases
	player = null
	zombie.grab_sound.stop()
	zombie.hurt_sound.play()

func _on_hurt_timer_timeout() -> void:
	if player:
		player.health_component.hurt(zombie.claw_damage + 5)
