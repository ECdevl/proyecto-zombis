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
@onready var melee_hitbox: ShapeCast3D = %melee_hitbox

@export var ads_visual_kick_multiplier: float = 0.01 
var ads_visual_offset: Vector3 = Vector3.ZERO
var recoil_current: Vector2 = Vector2.ZERO

var weapon_visual_offset: Vector3 = Vector3.ZERO
var weapon_base_position: Vector3 = Vector3.ZERO

var bullets_available : Array[ItemDescriptor]

func _ready() -> void:
	player = owner
	player.weapon_changed.connect(_on_weapon_changed)



func _on_weapon_changed(gun: ItemDescriptor) -> void:
	current_weapon = gun
	if not gun:
		return
	if player.viewmodel:
		player.viewmodel_ap.playback_default_blend_time = 0.05
		player.viewmodel_ap.play("draw")
		player.viewmodel_ap.queue("idle")
		if !current_weapon:
			return
		#if current_weapon.weapon_type == current_weapon.Type.MELEE:
			#melee_swings.clear()
			#for i in player.viewmodel_ap.get_animation_list():
				#if i.begins_with("swing"):
					#melee_swings.append(i)
		#else:
			#melee_swings.clear()
	if current_weapon is Weapon:
		current_weapon.ammo_requested.emit()
@onready var ads_reference: Marker3D = %ADS_Reference

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
	player.viewmodel_ap.stop()
	player.viewmodel.get_node("muzzle_flash_bone").get_child(0).start_effect()
	if %ArmsFSM.state.name == "aim":
		player.viewmodel_ap.play("aim_shoot")
	else:
		player.viewmodel_ap.play("shoot")
	
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
	if not current_weapon or not current_weapon: return false
	if fire_rate.time_left != 0.0: return false
	var cap := current_weapon
	if melee_combo >= cap.swing_count: melee_combo = 0
	var anim_name := "swing%d" % (melee_combo + 1)
	player.viewmodel_ap.play(anim_name)
	melee_combo += 1
	fire_rate.start(cap.fire_rate)

	var length := player.viewmodel_ap.current_animation_length
	get_tree().create_timer(length * cap.hit_start_pct).timeout.connect(
		func(): melee_hitbox.start_attack(cap.damage, cap.hitbox_radius, cap.range)
	)
	get_tree().create_timer(length * cap.hit_end_pct).timeout.connect(
		melee_hitbox.stop_attack
	)
	return true

func _on_hitbox_start() -> void:
	melee_hitbox.start_attack(current_weapon.damage,
		current_weapon.hitbox_radius,
		current_weapon.range)

func _on_hitbox_stop() -> void:
	melee_hitbox.stop_attack()
	ads_visual_offset.y += current_weapon.recoil_kick.x * ads_visual_kick_multiplier

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
	player.viewmodel_ap.play("reload")
	current_weapon.curr_bullets = 0
	await player.viewmodel_ap.animation_finished
	reloading = false
	player.viewmodel_ap.play("idle")
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
	
