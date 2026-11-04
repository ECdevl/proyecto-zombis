extends Node3D
## Sonda de robustez de `Zombie` (rework de modularidad, D-014).
##
## Comprueba que `hurted()` y `die()` no abortan con `info` incompleta y que
## los hooks de personalización para zombis especiales existen.
##
## IMPORTANTE: en Godot un error de script NO detiene la ejecución de la
## escena, solo aborta la función que lo puso. Por eso los casos 1, 3 y 4
## se validan por un efecto observable que ocurre DESPUÉS de la línea que
## podía truenar; los casos 2 y 5 (sin efecto observable) se validan
## mirando que la salida no contenga ninguna línea `SCRIPT ERROR`, algo que
## comprueba el comando que corre esta sonda.
##
##   1) `die()` con la info real de una bala (trae who/attacker/hit_pos pero
##      NO impulse/force) → debe llegar hasta arrancar el ragdoll.
##   2) `hurted()` sin info (arañazo) → aplica el flinch y no truena.
##   3) `hurted()` con un hitbox de pierna pero SIN atacante ni hit_pos →
##      debe llegar hasta el chequeo de pierna (state = stun).
##   4) `hurted()` con `hit_pos` no finito → usa el respaldo
##      `who.global_position` y llega hasta la pierna (state = stun).
##   5) `hurted()` solo con atacante (sin `who`) → no truena.
##   6) los hooks `_on_hurted()` / `_on_died()` existen para sobreescribir.
##
## Uso: godot --headless --path . res://tools/probe_zombie.tscn

const ZOMBIE_SCENE := preload("res://scenes/zombies/zombie.tscn")

var fallos := 0


func ok(cond: bool, msg: String) -> void:
	if cond:
		print("  OK   ", msg)
	else:
		fallos += 1
		print("  FALLA ", msg)


func _ready() -> void:
	_build_floor()

	print("=== 1) die() con info de bala (sin impulse/force) ===")
	var z1 := _spawn()
	z1.die(9999.0, _bullet_info(z1))
	await get_tree().physics_frame
	ok(z1.ragdoll_component.is_ragdoll,
		"die() llegó hasta arrancar el ragdoll (no truenó con info incompleta)")
	z1.queue_free()

	print("=== 2) hurted() con info vacía ===")
	var z2 := _spawn()
	var antes := int(z2.at["parameters/flinch/request"])
	z2.hurted(10.0, {})
	ok(int(z2.at["parameters/flinch/request"]) != antes,
		"aplica el flinch con info vacía (%d → %d)" % [antes, int(z2.at["parameters/flinch/request"])])
	z2.queue_free()

	print("=== 3) hurted() con pierna y sin atacante ===")
	var z3 := _spawn()
	z3.hurted(10.0, {"who": _leg(z3)})
	await get_tree().physics_frame
	ok(z3.state_machine.state.name == &"stun",
		"llega al chequeo de pierna (state = %s)" % z3.state_machine.state.name)
	z3.queue_free()

	print("=== 4) hurted() con hit_pos no finito ===")
	var z4 := _spawn()
	z4.hurted(10.0, {"who": _leg(z4), "attacker": self, "hit_pos": Vector3(NAN, NAN, NAN)})
	await get_tree().physics_frame
	ok(z4.state_machine.state.name == &"stun",
		"usa el respaldo who.global_position (state = %s)" % z4.state_machine.state.name)
	z4.queue_free()

	print("=== 5) hurted() solo con atacante (sin who) ===")
	var z5 := _spawn()
	z5.hurted(10.0, {"attacker": self, "hit_pos": z5.global_position})
	await get_tree().physics_frame
	ok(z5.state_machine.state.name == &"idle",
		"no cambia de estado sin hitbox (state = %s)" % z5.state_machine.state.name)
	z5.queue_free()

	print("=== 6) hooks de personalización ===")
	var z6 := _spawn()
	ok(z6.has_method("_on_hurted"), "existe el hook _on_hurted() para subclases")
	ok(z6.has_method("_on_died"), "existe el hook _on_died() para subclases")
	z6.queue_free()

	if fallos == 0:
		print("RESULTADO: TODO OK")
	else:
		print("RESULTADO: %d FALLO(S)" % fallos)
	get_tree().quit(1 if fallos > 0 else 0)


func _spawn() -> Zombie:
	var z: Zombie = ZOMBIE_SCENE.instantiate()
	z.can_debug = false
	add_child(z)
	z.global_position = Vector3(0, 0, 0)
	return z


## La info que manda `Projectile._apply_hit()` al matar con una bala:
## trae who/attacker/hit_pos pero NO impulse ni force.
func _bullet_info(z: Zombie) -> Dictionary:
	return {"who": _leg(z), "attacker": self, "hit_pos": z.global_position + Vector3.UP}


## Hitbox de pierna (grupo `zombie_legs_left`): si `hurted()` llega hasta el
## final, el zombi entra en `stun`, que es lo que esta sonda mide.
func _leg(z: Zombie) -> Area3D:
	return z.find_child("thight_left", true, false) as Area3D


func _build_floor() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	cs.shape = box
	cs.position = Vector3(0, -0.5, 0)
	body.add_child(cs)
	add_child(body)
