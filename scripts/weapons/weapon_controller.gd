extends Node
class_name WeaponController
## Centraliza TODA la lógica de gameplay del arma equipada: disparo (raycast),
## munición, recarga, recoil y las animaciones que le corresponden al arma.
## Los States (idle, aim) NUNCA calculan esto por su cuenta — solo llaman
## a las funciones públicas de acá (shoot(), reload(), swing()).

signal gun_fired(ammo:Weapon.AMMO_TYPE)
signal ammo_consumed(item:AmmoItemDescriptor)

var player: Player
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
			weapon_ap.play_backwards("draw")
			await weapon_ap.animation_finished
		_free_weapon()
		if is_instance_valid(player.armsy):
			player.armsy.show()
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
	var vm_tree := weapon_node.get_node_or_null("AnimationTree")
	if vm_tree is AnimationTree:
		player.viewmodel_animation_tree = vm_tree
	player.viewmodel_playback = null

	var muzzle_point = weapon_node.find_child("Muzzle",true)
	if muzzle_point:
		var muzzle_particle = MUZZLE_FLASH.instantiate()
		muzzle_point.add_child(muzzle_particle)
	

	var firearm := gun as Weapon
	if firearm and weapon_ap:
		weapon_ap.play("draw")


	var melee := gun as Melee
	if melee and weapon_ap:
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
	if event.is_action_pressed("punch"):
		if push_time.time_left > 0:
			return
		var tree := player.viewmodel_animation_tree if player.viewmodel_animation_tree else player.animation_tree
		if not current_weapon:
			if tree:
				tree["parameters/punch/request"]  = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
		else:
			weapon_ap.play("punch")

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
	var gun := current_weapon as Weapon
	if reloading:
		return false
	if not gun:
		return false
	if fire_rate.time_left != 0.0:
		return false
	if gun.curr_bullets <= 0:
		return false

	await get_tree().process_frame
	gun.curr_bullets -= 1
	fire_rate.start(gun.fire_rate)
	if weapon_ap and weapon_ap.has_animation("shoot"):
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
func swing() -> bool:

	var melee := current_weapon as Melee
	if not melee or melee.swings.is_empty():
		return false
	if fire_rate.time_left != 0.0:
		return false
	weapon_ap.speed_scale = 1.5

	var swing_data: SwingData = melee.swings.pick_random()

	if weapon_ap and weapon_ap.has_animation(swing_data.animation):
		weapon_ap.stop()
		weapon_ap.play(swing_data.animation,.1)
	fire_rate.start(melee.fire_rate)
	
	await get_tree().create_timer(swing_data.hit_time).timeout
	view_punch.punch(Vector2(swing_data.recoil_kick.x, swing_data.recoil_kick.y))
	if weapon_ap and weapon_ap.has_animation("idle"):
		weapon_ap.playback_default_blend_time = .5
		weapon_ap.queue("idle")

	if current_weapon != melee:
		return false  # se cambió de arma durante el swing

	# Paso 2: acá se crea el golpe (MeleeProjectile) usando melee y swing_data.
	var hit := MeleeProjectile.new()
	player.add_child(hit)
	hit.setup(melee, swing_data,player)
	
	# --- EJECUCIONES (comentado hasta tener animaciones) ---
	# # Intentar ejecución sigilosa si está por detrás
	# var cam := get_viewport().get_camera_3d()
	# if cam:
	# 	var space_state := cam.get_world_3d().direct_space_state
	# 	var origin := cam.global_position
	# 	var forward := -cam.global_basis.z
	# 	var query := PhysicsRayQueryParameters3D.create(origin, origin + forward * melee.weapon_range)
	# 	query.collide_with_areas = true
	# 	query.collision_mask = 512
	# 	var res := space_state.intersect_ray(query)
	# 	if not res.is_empty():
	# 		var hitbox := res.collider as Node3D
	# 		if hitbox and hitbox.owner is Zombie:
	# 			var zombie := hitbox.owner as Zombie
	# 			var dot := zombie.global_basis.z.dot(forward)
	# 			if dot > 0.5: # por detrás
	# 				# # Ejecutar
	# 				# player.playback.start("execution")
	# 				# zombie.die(hitbox, melee.damage * 10.0, player, (-zombie.global_basis.z).normalized(), 1000.0)
	# 				pass
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
	var gun := current_weapon as Weapon
	if not gun or gun.weapon_type == Weapon.WEAPON_TYPE.MELEE:
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
	if weapon_ap and weapon_ap.has_animation("idle"):
		weapon_ap.play("idle")

## Animación de "agarrar objeto" del player.
func play_grab_animation() -> void:
	var tree := player.viewmodel_animation_tree if player.viewmodel_animation_tree else player.animation_tree
	if tree:
		tree["parameters/grab/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
