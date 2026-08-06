extends State

@export var two_hand_aniumation_names : Dictionary[StringName,Vector3] = {"two_hand_swing_1":Vector3.DOWN,"two_hand_swing_2":Vector3.RIGHT,"two_hand_swing_3":Vector3.RIGHT}
var weapon_swing_direction : Vector3 = Vector3.LEFT
@onready var check_ledge_l: RayCast3D = %CheckLedgeL
@onready var check_ledge_r: RayCast3D = %CheckLedgeR
@onready var check_ledge_2: RayCast3D = %CheckLedge2
@onready var fire_rate: Timer = %FireRate

var recoil_current: Vector2 = Vector2.ZERO  # x = vertical (pitch), y = horizontal (yaw)
@export var recoil_kick: Vector2 = Vector2(2.0, 0.5)   # grados por disparo
@export var recoil_recovery_speed: float = 8.0


func enter(previous_state_path: String, data := {}) -> void:

	check_current_weapon()

func check_current_weapon() -> void:
	if player.weapon_controller.current_weapon:
		if player.weapon_controller.current_weapon.weapon_type == player.weapon_controller.current_weapon.Type.MELEE:
			if player.weapon_controller.current_weapon.weapon_handle == player.weapon_controller.current_weapon.Handle.TWO:
				player.playback.start("two_hand_draw")
				return
			else:
				player.playback.start("one_hand_idle")
				return
	else:
		player.playback.travel("Idle")

func update(_delta: float) -> void:
	can_transition = !player.weapon_controller.reloading

func handle_input(_event: InputEvent) -> void:
	if _event.is_action_pressed("M1"):
		call_deferred("attack")

	if _event.is_action_pressed("M2"):

		if player.get_current_weapon():
			if player.get_current_weapon().weapon_type == player.get_current_weapon().Type.GUN:
				finished.emit("aim")
	if _event.is_action_pressed("reload"):
		player.weapon_controller.reload()
	if _event.is_action_pressed("drop"):
		if player.weapon_controller.current_weapon:
			player.ui.remove_item(player.weapon_controller.current_weapon,1,true)
			player.weapon_controller.current_weapon = null

func physics_update(delta: float) -> void:
	if !player.is_on_floor():
		if check_ledge_l.is_colliding() and check_ledge_r.is_colliding():
			if !check_ledge_2.is_colliding():
				if Input.is_action_pressed(player.jump):
					finished.emit("climb")
					return




var combo_index : int = 0
func attack() -> void:
	if player.weapon_controller.current_weapon:
		if player.weapon_controller.current_weapon.weapon_type == player.weapon_controller.current_weapon.Type.MELEE:
			player.weapon_controller.swing()
		else:
			player.weapon_controller.shoot()





func _on_player_weapon_changed(gun: Weapon) -> void:

	if gun:
		
			if !gun.weapon_viewmodel:
				push_error("GUN HAS NO VIEWMODEL: CRASHING")
				return
			if player.viewmodel:
				player.viewmodel.queue_free()
			player.armsy.hide()
			if player.pitch.get_node_or_null("viewmodel"):
				player.pitch.get_node_or_null("viewmodel").queue_free()
			var gun_viewmodel : Node3D = gun.weapon_viewmodel.instantiate()
			player.pitch.add_child(gun_viewmodel)
			gun_viewmodel.name = "viewmodel"
			player.viewmodel = gun_viewmodel
			
	else:
		player.armsy.show()
		if player.viewmodel:
			player.viewmodel_ap.play_backwards("draw")
			player.viewmodel.queue_free()
		player.weapon_scene = null
		player.weapon_AP = null
		

	player.weapon_controller.current_weapon = gun
	check_current_weapon()






func _on_ui_item_used(item: Item) -> void:
	await get_tree().process_frame
	finished.emit("consuming",{"objet_to_consume":item})
