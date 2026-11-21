class_name ShotgunBehaviour extends FirearmBehaviour

func create_projectile(host: Node3D, descriptor: EquippableDescriptor) -> Projectile:
	var gun: Weapon = descriptor as Weapon
	if gun == null:
		return null
	var projectile: ShotgunProjectile = ShotgunProjectile.new()
	_attach(host, projectile)
	projectile.setup(gun.pellets_per_shot, gun.pellet_spread_deg, gun.damage, gun.weapon_range, gun.knockback)
	return projectile
