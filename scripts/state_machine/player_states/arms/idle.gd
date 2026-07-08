extends State

@export var two_hand_aniumation_names : Dictionary[StringName,Vector3] = {"two_hand_swing_1":Vector3.DOWN,"two_hand_swing_2":Vector3.RIGHT,"two_hand_swing_3":Vector3.RIGHT}
var weapon_swing_direction : Vector3 = Vector3.LEFT
@onready var melee_collision: Area3D = %melee_collision
var current_weapon : Weapon
@onready var check_ledge_l: RayCast3D = %CheckLedgeL
@onready var check_ledge_r: RayCast3D = %CheckLedgeR
@onready var check_ledge_2: RayCast3D = %CheckLedge2


func enter(previous_state_path: String, data := {}) -> void:
	check_current_weapon()

func check_current_weapon() -> void:
	if current_weapon:
		if current_weapon.weapon_handle == current_weapon.Handle.TWO:
			player.playback.start("two_hand_draw")
			return
		else:
			player.playback.start("one_hand_idle")
			return
	else:
		player.playback.travel("Idle")

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	if !player.is_on_floor():
		if check_ledge_l.is_colliding() and check_ledge_r.is_colliding():
			if !check_ledge_2.is_colliding():
				if Input.is_action_pressed(player.jump):
					finished.emit("climb")
					return
	if melee_collision.monitoring:
		for i in melee_collision.get_overlapping_bodies():
			if i is PhysicalBone3D:
				var direction = -melee_collision.global_transform.basis.y.normalized()
				GameManager.blood_splatter(i,direction)
				i.apply_central_impulse(direction*(current_weapon.weapon_damage/6))

func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("M1"):
		attack()
	if event.is_action_pressed("drop"):
		if current_weapon:
			player.ui.remove_item(current_weapon,1,true)
			current_weapon = null
var combo_index : int = 0
func attack() -> void:
	if current_weapon:
		if current_weapon.weapon_type == current_weapon.Type.MELEE:
			if current_weapon.weapon_handle == 2:
				if combo_index >= two_hand_aniumation_names.size():
					combo_index = 0
				player.playback.travel(two_hand_aniumation_names.keys()[combo_index])
				combo_index += 1

func swing() -> void:
	var current_vector : Vector3 = two_hand_aniumation_names.values()[combo_index-1]
	match current_vector:
		Vector3.DOWN:
			melee_collision.rotation_degrees = Vector3.ZERO
		Vector3.RIGHT:
			melee_collision.rotation_degrees = Vector3(0,0,90.0)
		Vector3.LEFT:
			melee_collision.rotation_degrees = Vector3(0,0,-90.0)
	melee_collision.monitoring = true



func _on_player_weapon_changed(gun: Weapon) -> void:
	if gun == current_weapon:
		return
	var mesh_instance : MeshInstance3D = player.weapon_grip.get_child(0)
	if gun:
		mesh_instance.mesh = gun.item_mesh
		mesh_instance.position = gun.weapon_pos_grip
		mesh_instance.rotation_degrees  = gun.weapon_rot_grip
	else:
		mesh_instance.mesh = null
		

	current_weapon = gun
	check_current_weapon()


func _on_melee_collision_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		if current_weapon:
			body.health_component.hurt(current_weapon.weapon_damage)



func _on_ui_item_used(item: ItemConsumable) -> void:
	finished.emit("consuming",{"objet_to_consume":item})




func _on_animation_tree_animation_finished(anim_name: StringName) -> void:
	if anim_name in two_hand_aniumation_names:
		melee_collision.monitoring = false
