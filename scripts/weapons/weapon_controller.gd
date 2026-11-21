extends Node
class_name WeaponController

signal gun_fired(ammo:Weapon.AMMO_TYPE)
signal ammo_consumed(item:AmmoItemDescriptor)

var player: Player
const VIEWMODEL_ANIMATOR_SCRIPT = preload("res://scripts/core/viewmodel_animator.gd")
var current_weapon: EquippableDescriptor
var reloading: bool = false
var swing_index: int = 0

@onready var fire_rate: Timer = %FireRate

@export var ads_visual_kick_multiplier: float = 0.01
var ads_visual_offset: Vector3 = Vector3.ZERO
var recoil_current: Vector2 = Vector2.ZERO

var weapon_visual_offset: Vector3 = Vector3.ZERO
var weapon_base_position: Vector3 = Vector3.ZERO

var bullets_available: Array[ItemDescriptor]

@export var view_punch: ViewPunch
var ammo_source: PlayerCarriedInventories
var push_enabled: bool = true

var weapon_ap: AnimationPlayer
var weapon_node: Node3D
var weapon_muzzle: Node3D
const MUZZLE_FLASH = preload("uid://ctoelcfhcmm8g")

var _active_operation: AttackOperation

func get_reserve_ammo() -> int:
	var gun: Weapon = current_weapon as Weapon
	if not gun or not ammo_source:
		return 0
	return ammo_source.count_ammo(gun.ammo_type)
@onready var gun_audio: AudioStreamPlayer = %AudioStreamPlayer3D

func _ready() -> void:
	player = owner
	player.weapon_changed.connect(_on_weapon_changed)
	ammo_source = player.inventory

func _abort_operation() -> void:
	if _active_operation != null and is_instance_valid(_active_operation):
		_active_operation.cancel()
	_active_operation = null
	reloading = false

func is_active_operation(operation: AttackOperation) -> bool:
	return operation != null and is_instance_valid(operation) and _active_operation == operation and not operation.cancelled

func _free_weapon() -> void:
	_abort_operation()
	for child in player.weapon_pivot.get_children():
		if child.name.begins_with("gun") or child == player.current_viewmodel:
			child.name = "gun_old"
			child.queue_free()
	if is_instance_valid(player.viewmodel_animator):
		player.viewmodel_animator.queue_free()
	player.viewmodel_animator = null
	player.current_viewmodel = null
	player.viewmodel_ap = null
	player.viewmodel_animation_tree = null
	player.viewmodel_playback = null
	if is_instance_valid(player.armsy):
		player.armsy.show()

func _on_weapon_changed(gun: EquippableDescriptor) -> void:
	_abort_operation()
	current_weapon = gun
	player.ads_controller.aiming = false
	if not gun:
		_free_weapon()
		if is_instance_valid(player.armsy):
			player.armsy.show()
		if player.arms_animator != null:
			player.arms_animator.play_base(&"idle")
			
		return
	if gun.viewmodel_model == null:
		push_error("%s: falta viewmodel_model" % gun.item_name)
		return

	_free_weapon()
	weapon_node = gun.viewmodel_model.instantiate()
	weapon_node.name = "gun"
	player.weapon_pivot.add_child(weapon_node)
	weapon_node.global_transform = player.weapon_pivot.global_transform
	if is_instance_valid(player.armsy):
		player.armsy.hide()
	player.current_viewmodel = weapon_node
	weapon_ap = weapon_node.get_node_or_null("AnimationPlayer")
	player.viewmodel_ap = weapon_ap
	var animator: Variant = VIEWMODEL_ANIMATOR_SCRIPT.new()
	weapon_node.add_child(animator)
	animator.setup(weapon_node)
	player.viewmodel_animator = animator
	if animator.ap != null:
		weapon_ap = animator.ap
		player.viewmodel_ap = animator.ap
	if animator.tree != null:
		player.viewmodel_animation_tree = animator.tree
	else:
		var vm_tree: Variant = weapon_node.get_node_or_null("AnimationTree")
		if vm_tree is AnimationTree:
			player.viewmodel_animation_tree = vm_tree
	player.viewmodel_playback = null

	var muzzle_point: Variant = weapon_node.find_child("Muzzle", true)
	if muzzle_point:
		var muzzle_particle: Node = MUZZLE_FLASH.instantiate()
		muzzle_point.add_child(muzzle_particle)

	if is_instance_valid(player.viewmodel_animator):
		player.viewmodel_animator.fire_shot(&"draw")
	var firearm: Weapon = gun as Weapon
	if firearm:
		firearm.ammo_requested.emit()
	await get_tree().process_frame
	_register_sight(weapon_node, weapon_ap)
	if "handling_sounds" in current_weapon:
		play_audio(current_weapon.handling_sounds)
func _register_sight(model: Node3D, ap: AnimationPlayer) -> void:
	if is_instance_valid(ap) and ap.is_playing():
		await ap.animation_finished
	if not is_instance_valid(model) or not is_instance_valid(ap):
		return
	var aim_point: Node3D = model.find_child("aim_point", true, false) as Node3D
	if aim_point:
		player.ads_controller.set_sight(aim_point)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("punch"):
		if not player.can_act():
			return
		if push_time.time_left > 0:
			return
		var tree: Variant = player.viewmodel_animation_tree if player.viewmodel_animation_tree else player.animation_tree
		if not current_weapon:
			if tree:
				tree["parameters/punch/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
		else:
			if is_instance_valid(player.viewmodel_animator):
				player.viewmodel_animator.fire_shot(&"punch")
			else:
				player.arms_animator.fire_shot(&"punch")
		push()
		push_time.start()

func _physics_process(delta: float) -> void:
	var gun: Weapon = current_weapon as Weapon
	if recoil_current != Vector2.ZERO and gun:
		var previous_recoil: Vector2 = recoil_current
		recoil_current = recoil_current.lerp(Vector2.ZERO, delta * gun.recoil_recovery_speed)
		var recoil_delta: Vector2 = recoil_current - previous_recoil
		player.pitch.rotation.x -= deg_to_rad(recoil_delta.x)
		player.yaw.rotation.y -= deg_to_rad(recoil_delta.y)
	if ads_visual_offset != Vector3.ZERO and gun:
		ads_visual_offset = ads_visual_offset.lerp(Vector3.ZERO, delta * gun.recoil_recovery_speed)

func _can_continue(token: AttackOperation) -> bool:
	if token == null or not is_instance_valid(token):
		return false
	if token.cancelled:
		return false
	if not is_instance_valid(player) or not player.can_act():
		return false
	if current_weapon != token.descriptor:
		return false
	if not is_instance_valid(weapon_node):
		return false
	return true

func _start_operation(operation: AttackOperation) -> void:
	_abort_operation()
	_active_operation = operation

func _finish_operation(operation: AttackOperation) -> void:
	if _active_operation == operation:
		_active_operation = null

func attack() -> void:
	if current_weapon == null or current_weapon.behaviour == null:
		return
	if not player.can_act():
		return
	if reloading:
		return
	var operation: AttackOperation = current_weapon.behaviour.create_operation(self, current_weapon)
	if operation == null:
		return
	_start_operation(operation)

	await operation.run()
	_finish_operation(operation)

func shoot() -> void:
	await attack()

func swing() -> void:
	await attack()

func load_projectile(gun: Weapon) -> void:

	weapon_muzzle = null
	var projectile: Projectile = gun.create_projectile(weapon_node)
	if projectile == null:
		return
	if weapon_node:
		var muzzle: Node = weapon_node.find_child("Muzzle", true, false)
		if muzzle:
			weapon_muzzle = muzzle as Node3D
	if weapon_node and weapon_muzzle:
		projectile.global_position = weapon_muzzle.global_position
	play_audio(current_weapon.shoot_sound)

func update_inventory_ammo(item: Variant) -> void:
	await get_tree().process_frame
	if current_weapon == null or not is_instance_valid(player):
		return
	var descriptor: ItemDescriptor
	if item is EquippableDescriptor:
		descriptor = item as ItemDescriptor
	elif item is PickableItem:
		descriptor = (item as PickableItem).item_descriptor as ItemDescriptor
	else:
		return
	if descriptor == current_weapon:
		player.weapon_changed.emit(null)
		return
	var firearm: Weapon = current_weapon as Weapon
	if firearm:
		firearm.ammo_requested.emit()

func apply_recoil(gun: Weapon) -> void:
	if view_punch == null or gun == null:
		return
	var kick: Vector2 = gun.recoil_kick
	view_punch.punch(Vector2(kick.x, randf_range(-kick.y, kick.y)))

func play_reload_animation(operation: AttackOperation) -> void:
	if not is_active_operation(operation):
		return
	if is_instance_valid(player.viewmodel_animator):
		player.viewmodel_animator.play_base(&"reload")
		play_audio(current_weapon.reload_sound)

func play_reload_idle(operation: AttackOperation) -> void:
	if not is_active_operation(operation):
		return
	if is_instance_valid(player.viewmodel_animator):
		player.viewmodel_animator.play_base(&"idle")

@onready var push_hitbox: Area3D = %PushHitbox
@onready var push_time: Timer = %pushTime
@onready var push_sound: AudioStreamPlayer = %push

func push() -> void:
	push_sound.play()
	if current_weapon:
		await get_tree().create_timer(current_weapon.push_time).timeout
		
	if not push_enabled:
		return
	

	for c in push_hitbox.get_overlapping_bodies():
		if c is Zombie:
			c.push(c.global_position - player.global_position)

func play_audio(stream:AudioStream = null,wait:bool = false) -> void:
	if stream:
		if wait:
			await gun_audio.finished
		gun_audio.stop()
		gun_audio.stream = stream
		gun_audio.play()

func reload() -> void:
	if current_weapon == null:
		return
	var operation: ReloadOperation = ReloadOperation.new()
	operation.start(self, current_weapon)
	if not operation.can_start():
		return
	_start_operation(operation)
	await operation.run()
	_finish_operation(operation)

func play_grab_animation() -> void:
	var tree: Variant = player.animation_tree
	if tree:
		tree["parameters/grab/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
