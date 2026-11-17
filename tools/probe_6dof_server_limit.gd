extends Node3D
## Sonda mínima a nivel PhysicsServer3D: ¿cuándo respetan los límites
## angulares de un joint 6DOF en este build (Godot 4.7.2 + Jolt)?
##
## Casos (cuerpos sin shapes; Y/Z de rotación bloqueados a 0; límite X = ±25°;
## se fuerza giro sobre X con velocidad angular 2 rad/s cada frame):
##   1: ambos cuerpos RIGID desde el inicio, joint hecho después.
##   2: cuerpo B STATIC al hacer el joint, luego body_set_mode → RIGID (ciclo PhysicalBone3D).
##   3: como 2 + re-empujar límites tras el cambio de modo.
##   4: como 1 + joint_clear y re-make sobre el mismo RID (imita re-bake).
##
## Uso: godot --headless --path . res://tools/probe_6dof_server_limit.tscn

const FRAMES: int = 180
const SPIN: float = 2.0
const LIMIT_DEG: float = 25.0
const PASS_MAX_DEG: float = 35.0


func _ready() -> void:
	await _caso(1, false, false, false)
	await _caso(2, true, false, false)
	await _caso(3, true, true, false)
	await _caso(4, false, false, true)
	get_tree().quit()


func _caso(id: int, static_first: bool, repush: bool, remake: bool) -> void:
	var space: RID = get_viewport().world_3d.get_space()

	var a: RID = PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(a, PhysicsServer3D.BODY_MODE_STATIC)
	PhysicsServer3D.body_set_space(a, space)
	PhysicsServer3D.body_set_state(a, PhysicsServer3D.BODY_STATE_TRANSFORM,
		Transform3D(Basis(), Vector3.ZERO))

	var b: RID = PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(b, PhysicsServer3D.BODY_MODE_STATIC if static_first else PhysicsServer3D.BODY_MODE_RIGID)
	PhysicsServer3D.body_set_space(b, space)
	PhysicsServer3D.body_set_state(b, PhysicsServer3D.BODY_STATE_TRANSFORM,
		Transform3D(Basis(), Vector3.ZERO))

	var j: RID = PhysicsServer3D.joint_create()
	_make_joint(j, a, b)

	if static_first:
		PhysicsServer3D.body_set_mode(b, PhysicsServer3D.BODY_MODE_RIGID)
		if repush:
			_push_limits(j)

	if remake:
		PhysicsServer3D.joint_clear(j)
		_make_joint(j, a, b)

	var max_deg: float = 0.0
	for i in range(FRAMES):
		await get_tree().physics_frame
		PhysicsServer3D.body_set_state(b, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3(SPIN, 0, 0))
		var tb: Transform3D = PhysicsServer3D.body_get_state(b, PhysicsServer3D.BODY_STATE_TRANSFORM)
		var ta: Transform3D = PhysicsServer3D.body_get_state(a, PhysicsServer3D.BODY_STATE_TRANSFORM)
		var rel: Basis = ta.basis.inverse() * tb.basis
		var eul: Vector3 = rel.get_euler()
		max_deg = maxf(max_deg, absf(rad_to_deg(eul.x)))

	var verdicto: String = "OK  (límite respetado)" if max_deg <= PASS_MAX_DEG else "FALLA (límite IGNORADO)"
	print("CASO %d: max |ángulo X| = %.1f°  → %s" % [id, max_deg, verdicto])

	PhysicsServer3D.free_rid(j)
	PhysicsServer3D.free_rid(b)
	PhysicsServer3D.free_rid(a)
	await get_tree().physics_frame


func _make_joint(j: RID, a: RID, b: RID) -> void:
	PhysicsServer3D.joint_make_generic_6dof(j, a, Transform3D(), b, Transform3D())
	_push_limits(j)


func _push_limits(j: RID) -> void:
	for axis_i in range(3):
		var axis: Vector3.Axis = axis_i as Vector3.Axis
		PhysicsServer3D.generic_6dof_joint_set_flag(j, axis, PhysicsServer3D.G6DOF_JOINT_FLAG_ENABLE_LINEAR_LIMIT, true)
		PhysicsServer3D.generic_6dof_joint_set_param(j, axis, PhysicsServer3D.G6DOF_JOINT_LINEAR_UPPER_LIMIT, 0.0)
		PhysicsServer3D.generic_6dof_joint_set_param(j, axis, PhysicsServer3D.G6DOF_JOINT_LINEAR_LOWER_LIMIT, 0.0)
		PhysicsServer3D.generic_6dof_joint_set_flag(j, axis, PhysicsServer3D.G6DOF_JOINT_FLAG_ENABLE_ANGULAR_LIMIT, true)
		var lim: float = deg_to_rad(LIMIT_DEG) if axis_i == 0 else 0.0
		PhysicsServer3D.generic_6dof_joint_set_param(j, axis, PhysicsServer3D.G6DOF_JOINT_ANGULAR_UPPER_LIMIT, lim)
		PhysicsServer3D.generic_6dof_joint_set_param(j, axis, PhysicsServer3D.G6DOF_JOINT_ANGULAR_LOWER_LIMIT, -lim)
