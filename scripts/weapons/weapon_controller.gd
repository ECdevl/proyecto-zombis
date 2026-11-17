extends Node
class_name WeaponController
## Centraliza TODA la lógica de gameplay del arma equipada: disparo (raycast),
## munición, recarga, recoil y las animaciones que le corresponden al arma.
## Los States (idle, aim) NUNCA calculan esto por su cuenta — solo llaman
## a las funciones públicas de acá (shoot(), reload(), swing()).

signal gun_fired(ammo:Weapon.AMMO_TYPE)
signal ammo_consumed(item:AmmoItemDescriptor)

var player: Player
const VIEWMODEL_ANIMATOR_SCRIPT = preload("res://scripts/core/viewmodel_animator.gd")
## Lo que se tiene en mano: Weapon (fuego) o Melee. Para lo propio de cada uno, castear.
var current_weapon: EquippableDescriptor
var reloading : bool = false

@onready var fire_rate: Timer = %FireRate


@export var ads_visual_kick_multiplier: float = 0.01
var ads_visual_offset: Vector3 = Vector3.ZERO
var recoil_current: Vector2 = Vector2.ZERO

var weapon_visual_offset: Vector3 = Vector3.ZERO
var weapon_base_position: Vector3 = Vector3.ZERO

var bullets_available : Array[ItemDescriptor]

@export var view_punch: ViewPunch
## De dónde salen las balas: el inventario que lleva el Player.
var ammo_source: PlayerCarriedInventories
var push_enabled : bool = true

var _flashlight_attachment: BoneAttachment3D
var _flashlight_instance: Node3D
var _flashlight_light: SpotLight3D
var _flashlight_on: bool = false
var _flashlight_rig_skeleton: Skeleton3D
var _flashlight_custom_nodes: Array[Node] = []
func get_reserve_ammo() -> int:
	var gun := current_weapon as Weapon
	if not gun or not ammo_source:
		return 0

	return ammo_source.count_ammo(gun.ammo_type)

func _ready() -> void:
	player = owner
	player.weapon_changed.connect(_on_weapon_changed)
	ammo_source = player.inventory
	reload_timer = Timer.new()
	reload_timer.one_shot = true
	add_child(reload_timer)
	reload_timer.timeout.connect(_on_reload_timeout)

	if player.inventory != null and player.inventory.hands != null and not player.inventory.hands.changed.is_connected(_on_hands_changed_flashlight):
		player.inventory.hands.changed.connect(_on_hands_changed_flashlight)
	refresh_flashlight_rig()




var weapon_ap : AnimationPlayer

var weapon_node: Node3D  # nuevo: guarda el modelo instanciado
var weapon_muzzle : Node3D
const MUZZLE_FLASH = preload("uid://ctoelcfhcmm8g")

var reload_timer: Timer
var _pending_reload: bool = false
var _reload_gun_ref: Weapon = null

func _free_weapon() -> void:
	if reload_timer:
		reload_timer.stop()
	_pending_reload = false
	_reload_gun_ref = null
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
	current_weapon = gun
	player.ads_controller.aiming = false
	if reload_timer:
		reload_timer.stop()
	_pending_reload = false
	_reload_gun_ref = null

	if not gun:
		if weapon_ap and weapon_ap.has_animation("draw"):
			if is_instance_valid(player.viewmodel_animation_tree):
				player.viewmodel_animation_tree.active = false
			weapon_ap.play_backwards("draw")
			await weapon_ap.animation_finished
		_free_weapon()
		if is_instance_valid(player.armsy):
			player.armsy.show()
		refresh_flashlight_rig()
		if player.playback:
			player.playback.start("idle")
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
		var vm_tree := weapon_node.get_node_or_null("AnimationTree")
		if vm_tree is AnimationTree:
			player.viewmodel_animation_tree = vm_tree
	player.viewmodel_playback = null
	refresh_flashlight_rig()

	var muzzle_point = weapon_node.find_child("Muzzle",true)
	if muzzle_point:
		var muzzle_particle = MUZZLE_FLASH.instantiate()
		muzzle_point.add_child(muzzle_particle)
	

	var firearm := gun as Weapon
	if firearm and weapon_ap:
		if is_instance_valid(player.viewmodel_animator):
			player.viewmodel_animator.fire_shot(&"draw")
		else:
			weapon_ap.play("draw")


	var melee := gun as Melee
	if melee and weapon_ap:
		if is_instance_valid(player.viewmodel_animator):
			player.viewmodel_animator.fire_shot(&"draw")
		else:
			weapon_ap.play("draw")

	if firearm:
		firearm.ammo_requested.emit()
	await get_tree().process_frame
	_register_sight(weapon_node, weapon_ap)

func _register_sight(model: Node3D, ap: AnimationPlayer) -> void:
	if ap and ap.is_playing():
		await ap.animation_finished
	if not is_instance_valid(model):
		return  # El arma se cambió mientras esperábamos
	var aim_point := model.find_child("aim_point", true, false) as Node3D
	if aim_point:
		player.ads_controller.set_sight(aim_point)

func _input(event: InputEvent) -> void:
	if event.is_action("toggle_flashlight"):
		toggle_flashlight()
	if event.is_action_pressed("punch"):
		if player.is_dead or player.is_input_locked():
			return
		if push_time.time_left > 0:
			return
		var tree := player.viewmodel_animation_tree if player.viewmodel_animation_tree else player.animation_tree
		if not current_weapon:
			if tree:
				tree["parameters/punch/request"]  = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
		else:
			if is_instance_valid(player.viewmodel_animator):
				player.viewmodel_animator.fire_shot(&"punch")
			else:
				weapon_ap.stop()
				weapon_ap.play("punch", -1)
				weapon_ap.queue("idle")

		push()
		push_time.start()
func _physics_process(delta: float) -> void:
	var gun := current_weapon as Weapon
	# recoil de cámara (pitch/yaw)
	if recoil_current != Vector2.ZERO and gun:
		var previous_recoil := recoil_current
		recoil_current = recoil_current.lerp(Vector2.ZERO, delta * gun.recoil_recovery_speed)
		var recoil_delta := recoil_current - previous_recoil
		player.pitch.rotation.x -= deg_to_rad(recoil_delta.x)
		player.yaw.rotation.y -= deg_to_rad(recoil_delta.y)

	# kick visual de la mira (ads_reference), se recupera solo
	if ads_visual_offset != Vector3.ZERO and gun:
		ads_visual_offset = ads_visual_offset.lerp(Vector3.ZERO, delta * gun.recoil_recovery_speed)




## Único punto de entrada para disparar. idle.gd y aim.gd llaman a esto,
## nunca duplican esta lógica.
func shoot() -> bool:
	var gun : Weapon = current_weapon as Weapon
	if reloading:
		return false
	if not gun:
		return false
	if fire_rate.time_left != 0.0:
		return false
	if gun.curr_bullets <= 0:
		return false
	if player.is_dead or player.is_input_locked():
		return false
	if current_weapon != gun:
		return false

	await get_tree().process_frame
	if reloading or not gun or not is_instance_valid(weapon_node):
		return false
	if player.is_dead or player.is_input_locked():
		return false
	if current_weapon != gun:
		return false
	gun.curr_bullets -= 1
	fire_rate.start(gun.fire_rate)
	if weapon_ap and weapon_ap.has_animation("shoot"):
		if is_instance_valid(player.viewmodel_animator):
			player.viewmodel_animator.fire_shot(&"shoot")
		else:
			weapon_ap.stop()
			weapon_ap.play("shoot")


	gun_fired.emit(gun.ammo_type)
	_apply_recoil()
	load_projectile(gun.damage,gun.weapon_range)
	if get_tree().get_first_node_in_group("muzzle"):
		get_tree().get_first_node_in_group("muzzle").start_effect()
	return true
const PROJECTILE = preload("uid://bct0h10f6qq3m")

func load_projectile(damage:float,range:float) -> void:
	var projectile : Projectile = PROJECTILE.instantiate()

	if weapon_node:
		if weapon_node.find_child("Muzzle"):
			weapon_muzzle = weapon_node.find_child("Muzzle",true)
			weapon_muzzle.add_child(projectile)
		else:
			weapon_muzzle = null
			weapon_node.add_child(projectile)
	projectile.set_projectile(damage,range)
	if weapon_node:
		if weapon_muzzle:
			projectile.global_position = weapon_node.find_child("Muzzle",true).global_position


func update_inventory_ammo(item:Variant) -> void:
	await get_tree().process_frame
	if current_weapon:
		if item is EquippableDescriptor:
			if item == current_weapon:
				player.weapon_changed.emit(null)
				return
		elif item is PickableItem:
			if item.item_descriptor == current_weapon:
				player.weapon_changed.emit(null)
				return
		var firearm := current_weapon as Weapon
		if firearm:
			firearm.ammo_requested.emit()


func _apply_recoil() -> void:
	var gun := current_weapon as Weapon
	if view_punch == null or gun == null:
		return
	var kick := gun.recoil_kick
	view_punch.punch(Vector2(kick.x, randf_range(-kick.y, kick.y)))


## Golpe cuerpo a cuerpo: elige un swing al azar, lo anima y espera el momento del golpe.
var swing_index : int = 0
func swing() -> bool:

	var melee := current_weapon as Melee
	if not melee or melee.swings.is_empty():
		return false
	if player.is_dead or player.is_input_locked():
		return false
	if reloading:
		return false
	if %ArmsFSM and %ArmsFSM.state and %ArmsFSM.state.name == "grabbed":
		return false
	if fire_rate.time_left != 0.0:
		return false
	if weapon_ap == null:
		return false
	if weapon_ap.current_animation.contains("swing"):
		return false
	weapon_ap.speed_scale = 1.5
	
	if swing_index >= melee.swings.size():
		swing_index = 0
	var swing_data: SwingData = melee.swings[swing_index]
	swing_index+=1
	if weapon_ap and weapon_ap.has_animation(swing_data.animation):
		if is_instance_valid(player.viewmodel_animator):
			player.viewmodel_animator.play_base(swing_data.animation)
		else:
			weapon_ap.stop()
			weapon_ap.play(swing_data.animation, .1)
	fire_rate.start(melee.fire_rate)
	
	await get_tree().create_timer(swing_data.hit_time).timeout
	if player == null or not is_instance_valid(player):
		return false
	if player.is_dead or player.is_input_locked():
		return false
	if reloading:
		return false
	if %ArmsFSM and %ArmsFSM.state and %ArmsFSM.state.name == "grabbed":
		return false
	if current_weapon != melee:
		return false  # se cambió de arma durante el swing
	if weapon_ap == null or not is_instance_valid(weapon_ap):
		return false
	if view_punch:
		view_punch.punch(Vector2(swing_data.recoil_kick.x, swing_data.recoil_kick.y))
	if weapon_ap.has_animation("idle"):
		if is_instance_valid(player.viewmodel_animator):
			player.viewmodel_animator.play_base(&"idle")
		else:
			weapon_ap.playback_default_blend_time = .5
			weapon_ap.queue("idle")

	# Paso 2: acá se crea el golpe (MeleeProjectile) usando melee y swing_data.
	var hit := MeleeProjectile.new()
	player.add_child(hit)
	hit.setup(melee, swing_data,player)
	return true

@onready var push_hitbox: Area3D = %PushHitbox
@onready var push_time: Timer = %pushTime

func push() -> void:
	if not push_enabled:
		return
	for c in push_hitbox.get_overlapping_bodies():
		if c is Zombie:
			c.push(c.global_position - player.global_position)

func reload() -> void:
	var gun : Weapon = current_weapon as Weapon
	if not gun or gun.weapon_type == Weapon.WEAPON_TYPE.MELEE:
		return
	if player.is_dead or player.is_input_locked():
		return
	if reloading or _pending_reload:
		return
	var missing: int = gun.mag_size - gun.curr_bullets
	if missing <= 0 or get_reserve_ammo() <= 0:
		return
	# No recargar si estamos agarrados o en estados que no permiten
	if %ArmsFSM and %ArmsFSM.state and %ArmsFSM.state.name == "grabbed":
		return
	if player and not player.can_move and not is_instance_valid(player.current_viewmodel):
		pass
	reloading = true
	_pending_reload = true
	_reload_gun_ref = gun

	if weapon_ap and weapon_ap.has_animation("reload"):
		if is_instance_valid(player.viewmodel_animator):
			player.viewmodel_animator.fire_shot(&"reload")
		else:
			weapon_ap.play("reload")

	var t := gun.reload_time
	if t <= 0.0:
		t = weapon_ap.get_animation("reload").length if weapon_ap and weapon_ap.has_animation("reload") else 1.0
	if reload_timer:
		reload_timer.wait_time = t
		reload_timer.start()
	else:
		await get_tree().create_timer(t).timeout
		_on_reload_timeout()

func _on_reload_timeout() -> void:
	if not _pending_reload or not _reload_gun_ref:
		reloading = false
		_pending_reload = false
		_reload_gun_ref = null
		return
	var gun := _reload_gun_ref
	if player == null or not is_instance_valid(player) or player.is_dead or player.is_input_locked():
		reloading = false
		_pending_reload = false
		_reload_gun_ref = null
		return
	# Validar que sigue equipada y visible
	if current_weapon != gun or not is_instance_valid(weapon_node) or not weapon_node.is_visible_in_tree():
		reloading = false
		_pending_reload = false
		_reload_gun_ref = null
		return
	# Validar estado
	if %ArmsFSM and %ArmsFSM.state and %ArmsFSM.state.name == "grabbed":
		reloading = false
		_pending_reload = false
		_reload_gun_ref = null
		return
	if not ammo_source or not is_instance_valid(ammo_source):
		reloading = false
		_pending_reload = false
		_reload_gun_ref = null
		return
	var missing: int = gun.mag_size - gun.curr_bullets
	if missing <= 0 or get_reserve_ammo() <= 0:
		reloading = false
		_pending_reload = false
		_reload_gun_ref = null
		return
	gun.curr_bullets += ammo_source.take_ammo(gun.ammo_type, missing)
	reloading = false
	_pending_reload = false
	_reload_gun_ref = null
	if weapon_ap and is_instance_valid(weapon_ap) and weapon_ap.has_animation("idle"):
		if is_instance_valid(player.viewmodel_animator):
			player.viewmodel_animator.play_base(&"idle")
		else:
			weapon_ap.play("idle")

## Animación de "agarrar objeto" del player.
func play_grab_animation() -> void:
	var tree := player.animation_tree
	if tree:
		tree["parameters/grab/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE


# --- Linterna (mano izquierda): solo bone attachment, pose por animacion ------

func _is_flashlight(item: ItemInstance) -> bool:
	return item != null and item.descriptor is FlashlightDescriptor


func toggle_flashlight() -> void:
	if player == null or player.inventory == null or player.inventory.hands == null:
		return
	if not _is_flashlight(player.inventory.hands.get_held(HandsModel.Hand.LEFT)):
		return
	_flashlight_on = not _flashlight_on
	if _flashlight_light:
		_flashlight_light.visible = _flashlight_on


func _on_hands_changed_flashlight() -> void:
	_refresh_flashlight()

func refresh_flashlight_rig() -> void:
	_refresh_flashlight()

func _get_flashlight_skeleton() -> Skeleton3D:
	if is_instance_valid(player.current_viewmodel):
		var sk: Skeleton3D = _find_arm_skeleton(player.current_viewmodel)
		if sk != null:
			return sk
	if is_instance_valid(player.armsy):
		return player.armsy.get_node_or_null("rig/Skeleton3D") as Skeleton3D
	return null

func _find_arm_skeleton(root: Node) -> Skeleton3D:
	if root == null:
		return null
	var skeletons: Array = root.find_children("*", "Skeleton3D", true, false)
	for s in skeletons:
		var sk: Skeleton3D = s as Skeleton3D
		if sk == null:
			continue
		var bones: Dictionary = _find_arm_bones(sk)
		if not bones.is_empty():
			return sk
	return null

func _normalize_bone_name(name: String) -> String:
	var n: String = name.to_lower()
	n = n.replace("_", "")
	n = n.replace(".", "")
	n = n.replace(" ", "")
	return n

func _find_arm_bones(skeleton: Skeleton3D) -> Dictionary:
	if skeleton == null:
		return {}
	var root_idx: int = -1
	var middle_idx: int = -1
	var end_idx: int = -1
	var root_name: String = ""
	var middle_name: String = ""
	var end_name: String = ""
	for i in skeleton.get_bone_count():
		var bname: String = skeleton.get_bone_name(i)
		var norm: String = _normalize_bone_name(bname)
		if root_idx < 0 and (norm == "upperarmleft" or norm == "upperarml"):
			root_idx = i
			root_name = bname
		elif middle_idx < 0 and (norm == "forearmleft" or norm == "forearml" or norm == "lowerarmleft" or norm == "lowerarml"):
			middle_idx = i
			middle_name = bname
		elif end_idx < 0 and (norm == "handleft" or norm == "handl"):
			end_idx = i
			end_name = bname
	if root_idx < 0 or middle_idx < 0 or end_idx < 0:
		return {}
	return {
		"root": root_idx,
		"middle": middle_idx,
		"end": end_idx,
		"root_name": root_name,
		"middle_name": middle_name,
		"end_name": end_name,
	}

func _refresh_flashlight() -> void:
	var left_item: ItemInstance = null
	if player != null and player.inventory != null and player.inventory.hands != null:
		left_item = player.inventory.hands.get_held(HandsModel.Hand.LEFT)
	var equipped: bool = _is_flashlight(left_item)
	if not equipped:
		_teardown_flashlight_rig()
		_flashlight_on = false
		if is_instance_valid(player.viewmodel_animator):
			player.viewmodel_animator.set_context(&"ctx_flashlight", 0.0)
		return
	var skeleton: Skeleton3D = _get_flashlight_skeleton()
	if skeleton == null:
		_teardown_flashlight_rig()
		return
	if skeleton != _flashlight_rig_skeleton:
		_build_flashlight_rig(skeleton)
	if _flashlight_attachment == null:
		return
	var desc: FlashlightDescriptor = left_item.descriptor as FlashlightDescriptor
	_ensure_flashlight_instance(desc)
	_flashlight_attachment.visible = true
	if is_instance_valid(player.viewmodel_animator):
		player.viewmodel_animator.set_context(&"ctx_flashlight", 1.0)
	
func _build_flashlight_rig(skeleton: Skeleton3D) -> void:
	_teardown_flashlight_rig()
	_flashlight_rig_skeleton = skeleton
	var bones: Dictionary = _find_arm_bones(skeleton)
	if bones.is_empty():
		return
	var end_name: String = bones["end_name"]
	var flash_pivot : Node3D = Node3D.new()
	_flashlight_attachment = BoneAttachment3D.new()
	_flashlight_attachment.name = "FlashlightAttachment"
	_flashlight_attachment.bone_name = end_name
	skeleton.add_child(_flashlight_attachment)
	_flashlight_attachment.add_child(flash_pivot)
	
	print_debug(flash_pivot.position)
	_flashlight_custom_nodes.append(_flashlight_attachment)

func _teardown_flashlight_rig() -> void:
	if is_instance_valid(_flashlight_instance):
		_flashlight_instance.queue_free()
	_flashlight_instance = null
	for n in _flashlight_custom_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_flashlight_custom_nodes.clear()
	_flashlight_attachment = null
	_flashlight_rig_skeleton = null

func _ensure_flashlight_instance(descriptor: FlashlightDescriptor) -> void:
	if descriptor == null or descriptor.held_scene == null:
		return
	if is_instance_valid(_flashlight_instance):
		return
	_flashlight_instance = descriptor.held_scene.instantiate() as Node3D
	if _flashlight_instance == null:
		return
	_flashlight_attachment.get_child(0).add_child(_flashlight_instance)
	_flashlight_attachment.get_child(0).position = descriptor.hand_offset
	_flashlight_attachment.get_child(0).rotation = descriptor.hand_rot
	if is_instance_valid(_flashlight_rig_skeleton):
		var sc: Vector3 = _flashlight_rig_skeleton.global_transform.basis.get_scale().abs()
		if sc.x > 0.0001 and sc.y > 0.0001 and sc.z > 0.0001:
			_flashlight_instance.scale = _flashlight_instance.scale / sc
	var light: SpotLight3D = _flashlight_instance.find_child("SpotLight3D", true, false) as SpotLight3D
	if light == null:
		light = SpotLight3D.new()
		light.name = "FlashlightLight"
		_flashlight_instance.add_child(light)
		
		light.position = Vector3(0, 0, 0)
		light.light_energy = 2.0
		light.spot_range = 12.0
		light.spot_angle = 30.0
		light.shadow_enabled = true
		light.shadow_caster_mask = 1
	_flashlight_light = light
	_flashlight_light.visible = _flashlight_on
