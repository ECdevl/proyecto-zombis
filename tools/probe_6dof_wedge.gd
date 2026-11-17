extends Node3D
## Sonda "cuña": ¿pierden los límites angulares de un joint 6DOF contra
## contactos profundos persistentes en este build (Godot 4.7.2 + Jolt)?
##
## Caso 5 (cuña): A = esfera estática (r=0.1). B = cápsula r=0.05, largo 0.3,
##   inclinada 60° sobre X, con su punta enterrada 5 cm dentro de A. El contacto
##   empuja la punta fuera; el joint bloquea la traslación; la única salida es
##   ROTAR más allá del límite de 25°. Si B reposa > 45°, los contactos vencen
##   al límite.
## Caso 6 (control): igual pero SIN interpenetración (la gravedad la baja hasta
##   el límite; debe reposar ≈ 25-35°).
##
## Uso: godot --headless --path . res://tools/probe_6dof_wedge.tscn

const FRAMES: int = 240


func _ready() -> void:
	await _caso(5, true)
	await _caso(6, false)
	get_tree().quit()


func _caso(id: int, wedged: bool) -> void:
	var space: RID = get_viewport().world_3d.get_space()

	var a: RID = PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(a, PhysicsServer3D.BODY_MODE_STATIC)
	PhysicsServer3D.body_set_space(a, space)
	_add_shape(a, _esfera(), Transform3D(Basis(), Vector3.ZERO))
	PhysicsServer3D.body_set_state(a, PhysicsServer3D.BODY_STATE_TRANSFORM,
		Transform3D(Basis(), Vector3.ZERO))

	var b: RID = PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(b, PhysicsServer3D.BODY_MODE_RIGID)
	PhysicsServer3D.body_set_space(b, space)
	_add_shape(b, _capsula(), Transform3D(Basis(), Vector3.ZERO))
	var tilt: float = deg_to_rad(60.0)
	var b_pos: Vector3 = Vector3(0, 0.25, 0) if wedged else Vector3(0, 0.55, 0)
	PhysicsServer3D.body_set_state(b, PhysicsServer3D.BODY_STATE_TRANSFORM,
		Transform3D(Basis(Vector3(1, 0, 0), tilt), b_pos))

	var j: RID = PhysicsServer3D.joint_create()
	PhysicsServer3D.joint_make_generic_6dof(j, a, Transform3D(), b, Transform3D())
	for axis_i in range(3):
		var axis: Vector3.Axis = axis_i as Vector3.Axis
		PhysicsServer3D.generic_6dof_joint_set_flag(j, axis, PhysicsServer3D.G6DOF_JOINT_FLAG_ENABLE_LINEAR_LIMIT, true)
		PhysicsServer3D.generic_6dof_joint_set_param(j, axis, PhysicsServer3D.G6DOF_JOINT_LINEAR_UPPER_LIMIT, 0.0)
		PhysicsServer3D.generic_6dof_joint_set_param(j, axis, PhysicsServer3D.G6DOF_JOINT_LINEAR_LOWER_LIMIT, 0.0)
		PhysicsServer3D.generic_6dof_joint_set_flag(j, axis, PhysicsServer3D.G6DOF_JOINT_FLAG_ENABLE_ANGULAR_LIMIT, true)
		var lim: float = deg_to_rad(25.0) if axis_i == 0 else 0.0
		PhysicsServer3D.generic_6dof_joint_set_param(j, axis, PhysicsServer3D.G6DOF_JOINT_ANGULAR_UPPER_LIMIT, lim)
		PhysicsServer3D.generic_6dof_joint_set_param(j, axis, PhysicsServer3D.G6DOF_JOINT_ANGULAR_LOWER_LIMIT, -lim)

	var max_deg: float = 0.0
	var final_deg: float = 0.0
	for i in range(FRAMES):
		await get_tree().physics_frame
		var tb: Transform3D = PhysicsServer3D.body_get_state(b, PhysicsServer3D.BODY_STATE_TRANSFORM)
		var ta: Transform3D = PhysicsServer3D.body_get_state(a, PhysicsServer3D.BODY_STATE_TRANSFORM)
		var rel: Basis = ta.basis.inverse() * tb.basis
		var eul: Vector3 = rel.get_euler()
		var ang: float = absf(rad_to_deg(eul.x))
		max_deg = maxf(max_deg, ang)
		if i >= FRAMES - 30:
			final_deg += ang / 30.0

	var verdicto: String = "OK  (límite ganó)" if final_deg <= 40.0 else "FALLA (contacto venció al límite)"
	print("CASO %d: final=%.1f° max=%.1f° → %s" % [id, final_deg, max_deg, verdicto])

	PhysicsServer3D.free_rid(j)
	PhysicsServer3D.free_rid(b)
	PhysicsServer3D.free_rid(a)
	await get_tree().physics_frame


func _esfera() -> RID:
	var shape: RID = PhysicsServer3D.shape_create(PhysicsServer3D.SHAPE_SPHERE)
	PhysicsServer3D.shape_set_data(shape, 0.1)
	return shape


func _capsula() -> RID:
	var shape: RID = PhysicsServer3D.shape_create(PhysicsServer3D.SHAPE_CAPSULE)
	PhysicsServer3D.shape_set_data(shape, Vector2(0.05, 0.15))
	return shape


func _add_shape(body: RID, shape: RID, xform: Transform3D) -> void:
	PhysicsServer3D.body_add_shape(body, shape, xform)
