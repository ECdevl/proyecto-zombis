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
@onready var ui: UI = %UI

@export var view_punch: ViewPunch
var ammo_source: PlayerCarriedInventories  # asignar en el inspector → PlayerContainers
var push_enabled : bool = true
func get_reserve_ammo() -> int:
	var gun := current_weapon as Weapon
	if not gun or not ammo_source:
		return 0

	return ammo_source.count_ammo(gun.ammo_type)

func _ready() -> void:
	player = owner
	player.weapon_changed.connect(_on_weapon_changed)
	await ui.ready
	ammo_source = get_tree().get_first_node_in_group("ammo_source")



var playback : AnimationNodeStateMachinePlayback

var weapon_ap : AnimationPlayer

var weapon_node: Node3D  # nuevo: guarda el modelo instanciado
const MUZZLE_FLASH = preload("uid://ctoelcfhcmm8g")

func _free_weapon() -> void:
	var old := player.weapon_pivot.get_node_or_null("gun")
	if old:
		old.name = "gun_old"  # libera el nombre "gun" antes del queue_free (ver nota)
		old.queue_free()

func _on_weapon_changed(gun: EquippableDescriptor) -> void:
	current_weapon = gun
	player.ads_controller.aiming = false
	if not gun:
		# Solo hay animación de guardado si el viewmodel tiene "draw" (las armas de fuego).
		if weapon_ap and weapon_ap.has_animation("draw"):
			weapon_ap.play_backwards("draw")
			player.playback.start("pistol_undraw")
			await weapon_ap.animation_finished
		_free_weapon()
		player.playback.start("idle")
		return
	if gun.viewmodel_model == null:
		push_error("%s: falta viewmodel_model" % gun.item_name)
		return

	_free_weapon()
	weapon_node = gun.viewmodel_model.instantiate()
	weapon_node.name = "gun"
	weapon_ap = weapon_node.get_node_or_null("AnimationPlayer")  # puede no existir (ej: cuchillo)
	player.armsy.add_sibling(weapon_node)
	weapon_node.global_transform = player.armsy.global_transform
	var muzzle_point = weapon_node.find_child("Muzzle",true)
	if muzzle_point:
		var muzzle_particle = MUZZLE_FLASH.instantiate()
		muzzle_point.add_child(muzzle_particle)
	

	var firearm := gun as Weapon
	if player.animation_tree:
		playback = player.animation_tree["parameters/player_sm/playback"]
		if firearm and weapon_ap:
			weapon_ap.play("draw")
			match firearm.weapon_type:
				Weapon.WEAPON_TYPE.PISTOL:
					playback.start("pistol_draw")
					
					


	var melee := gun as Melee
	if melee:
		if melee.swings.size() > Melee.MAX_SWINGS:
			push_warning("%s: tiene %d swings, el máximo es %d" % [melee.item_name, melee.swings.size(), Melee.MAX_SWINGS])
		weapon_ap.play("draw")
		if melee.weapon_handle == Weapon.Handle.ONE:
			playback.start("one_hand_draw")
		elif melee.weapon_handle == Weapon.Handle.TWO:
			playback.start("two_hand_draw")
	if firearm:
		firearm.ammo_requested.emit()
	await get_tree().process_frame
	_register_sight(weapon_node, weapon_ap)


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
		if player.animation_tree:
			player.animation_tree["parameters/punch/request"]  = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE


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
	#player.viewmodel.get_node("muzzle_flash_bone").get_child(0).start_effect()
	if player.animation_tree:
		match Weapon.WEAPON_TYPE.PISTOL:
			Weapon.WEAPON_TYPE.PISTOL:
				playback.start("pistol_shoot",true)
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
		weapon_node.find_child("Muzzle",true).add_child(projectile)
	projectile.set_projectile(damage,range)
	if weapon_node:
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
	if not melee or melee.swings.is_empty() or not playback:
		return false
	if fire_rate.time_left != 0.0:
		return false

	var swing_data: SwingData = melee.swings.pick_random()
	match melee.weapon_handle:
		melee.Handle.ONE:
			playback.start("one_hand_"+swing_data.animation)
		melee.Handle.TWO:
			playback.start("two_hand_"+swing_data.animation)
	weapon_ap.play(swing_data.animation,.1)
	fire_rate.start(melee.fire_rate)
	await get_tree().create_timer(swing_data.hit_time).timeout
	weapon_ap.play("idles",-1)
	match melee.weapon_handle:
		melee.Handle.ONE:
			playback.travel("one_hand_idle")
		melee.Handle.TWO:
			playback.travel("two_hand_idle")
	if current_weapon != melee:
		return false  # se cambió de arma durante el swing

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
	var gun := current_weapon as Weapon
	if not gun or gun.weapon_type == Weapon.WEAPON_TYPE.MELEE:
		return
	var missing: int = gun.mag_size - gun.curr_bullets
	if missing <= 0 or get_reserve_ammo() <= 0:
		return
	reloading = true


	playback.start("pistol_reload")
	weapon_ap.play("reload")

	await player.animation_tree.animation_finished
	reloading = false
	playback.travel("pistol_idle")
	weapon_ap.play("idle")
	gun.curr_bullets += ammo_source.take_ammo(gun.ammo_type, missing)

func _on_player_grabbed_object(world_obj: PickableItem) -> void:
	if player.animation_tree:
		player.animation_tree["parameters/grab/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
