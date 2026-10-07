extends Node
class_name WeaponController
## Centraliza TODA la lógica de gameplay del arma equipada: disparo (raycast),
## munición, recarga, recoil y las animaciones que le corresponden al arma.
## Los States (idle, aim) NUNCA calculan esto por su cuenta — solo llaman
## a las funciones públicas de acá (shoot(), reload()).

signal gun_fired(ammo:Weapon.AMMO_TYPE)
signal ammo_consumed(item:AmmoDescriptor)

var player: Player
var current_weapon: ItemDescriptor
var reloading : bool = false

var melee_swings : PackedStringArray

@onready var fire_rate: Timer = %FireRate


@export var ads_visual_kick_multiplier: float = 0.01 
var ads_visual_offset: Vector3 = Vector3.ZERO
var recoil_current: Vector2 = Vector2.ZERO

var weapon_visual_offset: Vector3 = Vector3.ZERO
var weapon_base_position: Vector3 = Vector3.ZERO

var bullets_available : Array[ItemDescriptor]

func _ready() -> void:
	player = owner
	player.weapon_changed.connect(_on_weapon_changed)

var playback : AnimationNodeStateMachinePlayback

var weapon_ap : AnimationPlayer

var weapon_node: Node3D  # nuevo: guarda el modelo instanciado

func _free_weapon() -> void:
	var old := player.weapon_pivot.get_node_or_null("gun")
	if old:
		old.name = "gun_old"  # libera el nombre "gun" antes del queue_free (ver nota)
		old.queue_free()

func _on_weapon_changed(gun: ItemDescriptor) -> void:
	current_weapon = gun
	player.ads_controller.aiming = false
	if not gun:
		_free_weapon()
		player.playback.start("Idle")
		return
	if gun is Weapon:
		_free_weapon()
		weapon_node = gun.viewmodel_model.instantiate()
		weapon_node.name = "gun"
		weapon_ap = weapon_node.get_node("AnimationPlayer")
		player.armsy.add_sibling(weapon_node)
		weapon_node.global_rotation = player.armsy.global_rotation
	if player.animation_tree:
		playback = player.animation_tree["parameters/player_sm/playback"]
		match current_weapon.weapon_type:
			Weapon.WEAPON_TYPE.PISTOL:
				playback.start("pistol_draw")
				weapon_ap.play("draw")
	_register_sight(weapon_node, weapon_ap)  # nuevo
	melee_swings.clear()
	if current_weapon is Weapon:
		current_weapon.ammo_requested.emit()


## Espera a que termine el "draw" y recién ahí registra la mira.
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
		if player.animation_tree and current_weapon != null:
			player.animation_tree["parameters/punch/request"]  = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
		else:
			player.playback.travel("punch")
			
		push()
		push_time.start()
func _physics_process(delta: float) -> void:
	# recoil de cámara (pitch/yaw)
	if recoil_current != Vector2.ZERO and current_weapon:
		var previous_recoil := recoil_current
		recoil_current = recoil_current.lerp(Vector2.ZERO, delta * current_weapon.recoil_recovery_speed)
		var recoil_delta := recoil_current - previous_recoil
		player.pitch.rotation.x -= deg_to_rad(recoil_delta.x)
		player.yaw.rotation.y -= deg_to_rad(recoil_delta.y)
 
	# kick visual de la mira (ads_reference), se recupera solo
	if ads_visual_offset != Vector3.ZERO and current_weapon:
		ads_visual_offset = ads_visual_offset.lerp(Vector3.ZERO, delta * current_weapon.recoil_recovery_speed)



## Único punto de entrada para disparar. idle.gd y aim.gd llaman a esto,
## nunca duplican esta lógica.
func shoot() -> bool:
	if reloading:
		return false
	if not current_weapon:
		return false
	if fire_rate.time_left != 0.0:
		return false
	if current_weapon.curr_bullets <= 0:
		return false

	await get_tree().process_frame
	current_weapon.curr_bullets -= 1
	fire_rate.start(current_weapon.fire_rate)
	#player.viewmodel.get_node("muzzle_flash_bone").get_child(0).start_effect()
	if player.animation_tree:
		match Weapon.WEAPON_TYPE.PISTOL:
			Weapon.WEAPON_TYPE.PISTOL:
				playback.travel("pistol_shoot")
				weapon_ap.play("shoot")

	
	gun_fired.emit(current_weapon.ammo_type)
	_apply_recoil()
	_raycast_damage()
	return true

func update_inventory_ammo(item:Variant) -> void:
	await get_tree().process_frame
	if current_weapon:
		if item is Weapon:
			if item == current_weapon:
				player.weapon_changed.emit(null)
				return
		elif item is PickableItem:
			if item.item_descriptor == current_weapon:
				player.weapon_changed.emit(null)
				return
		if current_weapon is Weapon:
			current_weapon.ammo_requested.emit()
	
func _apply_recoil() -> void:
	recoil_current.x += current_weapon.recoil_kick.x
	recoil_current.y += randf_range(-current_weapon.recoil_kick.y, current_weapon.recoil_kick.y)
	# el salto visual escala con lo fuerte que sea el recoil de ESTA arma

var melee_combo : int
func swing() -> bool: 
	if not current_weapon or fire_rate.time_left != 0.0:
		return false
	if melee_swings.size() <= 0:
		return false
	if melee_combo >= melee_swings.size():
		melee_combo = 0
	
	playback.start(melee_swings[melee_combo])
	melee_combo += 1
	fire_rate.start(current_weapon.fire_rate)
	await get_tree().create_timer(current_weapon.delay).timeout
	_raycast_damage()  # igual que shoot()
	return true

@onready var push_hitbox: Area3D = %PushHitbox
@onready var push_time: Timer = %pushTime

func push() -> void:
	for c in push_hitbox.get_overlapping_bodies():
		if c.owner is Zombie:
			c.owner.health_component.hurt(0, c)
			

func _raycast_damage() -> void:
	await get_tree().physics_frame
	var space_state = get_viewport().get_camera_3d().get_world_3d().direct_space_state
	var origin: Vector3 = player.camera.global_transform.origin
	var end: Vector3 = origin + (-player.camera.global_transform.basis.z * current_weapon.weapon_range)

	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collide_with_areas = true
	query.exclude = [player]
	query.collision_mask = (1 << 0) | (1 << 6)  # capa 1 (mundo) + capa 7 (partes de cuerpo)

	var result = space_state.intersect_ray(query)
	
	if not result:
		return

	var hit: Object = result.collider
	if hit.owner is Zombie:
		if hit.name == "head":
			hit.owner.health_component.hurt(current_weapon.damage * current_weapon.headshot_multiplier,hit)
			
		else:
			hit.owner.health_component.hurt(current_weapon.damage,hit.get_parent())

func reload() -> void:
	if not current_weapon:
		return
	if current_weapon.curr_bullets >= current_weapon.mag_size:
		return
	if current_weapon.ammo_reserve.size() <= 0:
		return
		
	reloading = true
	if player.animation_tree:
		match current_weapon.weapon_type:
			Weapon.WEAPON_TYPE.PISTOL:
				playback.travel("pistol_reload")
				weapon_ap.play("reload")
	current_weapon.curr_bullets = 0
	if player.animation_tree:
		await player.animation_tree.animation_finished

	reloading = false
	var wasted_ammo = current_weapon.mag_size - current_weapon.curr_bullets
	var boolets : int = 0
	var ammo_to_consume : AmmoDescriptor
	for ammo in current_weapon.ammo_reserve:
		if ammo is AmmoDescriptor:
			if ammo.amount > 0:
				boolets = ammo.amount
				ammo_to_consume = ammo
				break
	ammo_to_consume.amount -= current_weapon.mag_size
	if ammo_to_consume.amount < 0:
		ammo_consumed.emit(ammo_to_consume)
		current_weapon.ammo_reserve.erase(ammo_to_consume)
	
	var final_bullets = boolets - wasted_ammo

	if final_bullets < 0:
		current_weapon.curr_bullets = current_weapon.mag_size + final_bullets
	else:
		current_weapon.curr_bullets = current_weapon.mag_size
	


func _on_player_grabbed_object(world_obj: PickableItem) -> void:
	if player.animation_tree:
		player.animation_tree["parameters/grab/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
