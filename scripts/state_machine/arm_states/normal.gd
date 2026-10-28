extends PlayerState

@export var two_hand_aniumation_names : Dictionary[StringName,Vector3] = {"two_hand_swing_1":Vector3.DOWN,"two_hand_swing_2":Vector3.RIGHT,"two_hand_swing_3":Vector3.RIGHT}
var weapon_swing_direction : Vector3 = Vector3.LEFT
@onready var check_ledge_l: RayCast3D = %CheckLedgeL
@onready var check_ledge_r: RayCast3D = %CheckLedgeR
@onready var check_ledge_2: RayCast3D = %CheckLedge2
@onready var fire_rate: Timer = %FireRate



func enter(previous_state_path: String, data := {}) -> void:

	check_current_weapon()

func check_current_weapon() -> void:
	if player.weapon_controller.current_weapon is Weapon:
		pass
	else:
		if player.playback:
			player.playback.travel("idle")

func update(_delta: float) -> void:
	can_transition = !player.weapon_controller.reloading
	
func handle_input(_event: InputEvent) -> void:
	if _event.is_action_pressed("M1"):
		call_deferred("attack")


	if _event.is_action_pressed("M2"):

		if player.get_current_weapon():
			finished.emit("aim")
	if _event.is_action_pressed("reload"):

		player.weapon_controller.reload()

	if _event.is_action_pressed("drop"):
		if player.weapon_controller.current_weapon:
			var player_inventory : PlayerCarriedInventories = player.inventory
			if player_inventory.hands._held.is_empty():
				return
			var held_instance : ItemInstance = player_inventory.hands.get_held(HandsModel.Hand.RIGHT)
			if not held_instance:
				held_instance = player_inventory.hands.get_held(HandsModel.Hand.LEFT)
			player_inventory.remove(held_instance)
			player.drop_item(held_instance)

func physics_update(_delta: float) -> void:
	if !player.is_on_floor():
		if check_ledge_l.is_colliding() and check_ledge_r.is_colliding():
			if !check_ledge_2.is_colliding():
				if Input.is_action_pressed(player.jump):
					finished.emit("climb")
					return




var combo_index : int = 0
func attack() -> void:
	if player.weapon_controller.current_weapon is Weapon:
		player.weapon_controller.shoot()
	else:
		player.weapon_controller.swing()
