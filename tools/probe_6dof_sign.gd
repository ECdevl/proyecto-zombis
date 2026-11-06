extends Node3D
## Sonda del signo de los límites angulares de un joint 6DOF en Jolt.
##
## Monta dos cuerpos rígidos unidos por un `generic_6dof` creado directamente
## en el `PhysicsServer3D`, con el eje X alineado con el mundo. Bloquea los
## ejes lineales y deja libre solo el angular X, con un rango conocido.
## Lanza el cuerpo hijo con velocidad angular ±X y mide en qué ángulo se
## detiene. Así se sabe si el rango [lower, upper] se aplica en convención
## dextrógira (Godot) o invertida.
##
## Uso: godot --headless --path . res://tools/probe_6dof_sign.tscn

var _body_a: StaticBody3D
var _body_b: RigidBody3D
var _joint: RID


func _ready() -> void:
	await _run_case(-90.0, 0.0, 4.0)
	await _run_case(-90.0, 0.0, -4.0)
	await _run_case(0.0, 90.0, 4.0)
	await _run_case(0.0, 90.0, -4.0)
	get_tree().quit(0)


func _run_case(lower_deg: float, upper_deg: float, angular_x: float) -> void:
	_build_bodies()
	await get_tree().physics_frame
	_make_joint(lower_deg, upper_deg)
	await get_tree().physics_frame
	_body_b.angular_velocity = Vector3(angular_x, 0.0, 0.0)
	for i in range(120):
		await get_tree().physics_frame
	var angle: float = rad_to_deg(_body_b.global_basis.get_euler().x)
	print("limite=[%+.0f, %+.0f]  vel_x=%+.0f  ->  angulo_x=%+.1f" % [
		lower_deg, upper_deg, angular_x, angle])
	_teardown()
	await get_tree().process_frame


func _build_bodies() -> void:
	_body_a = StaticBody3D.new()
	_body_a.name = "A"
	var shape_a: CollisionShape3D = CollisionShape3D.new()
	var box_a: BoxShape3D = BoxShape3D.new()
	box_a.size = Vector3(0.2, 0.2, 0.2)
	shape_a.shape = box_a
	_body_a.add_child(shape_a)
	_body_a.position = Vector3(0.0, 0.0, 0.0)
	add_child(_body_a)

	_body_b = RigidBody3D.new()
	_body_b.name = "B"
	var shape_b: CollisionShape3D = CollisionShape3D.new()
	var box_b: BoxShape3D = BoxShape3D.new()
	box_b.size = Vector3(0.2, 1.0, 0.2)
	shape_b.shape = box_b
	_body_b.add_child(shape_b)
	_body_b.position = Vector3(0.0, -1.0, 0.0)
	_body_b.gravity_scale = 0.0
	_body_b.can_sleep = false
	add_child(_body_b)


func _make_joint(lower_deg: float, upper_deg: float) -> void:
	_joint = PhysicsServer3D.joint_create()
	var local_a: Transform3D = Transform3D.IDENTITY
	var local_b: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0.0, 1.0, 0.0))
	PhysicsServer3D.joint_make_generic_6dof(
		_joint, _body_a.get_rid(), local_a, _body_b.get_rid(), local_b)

	# Bloquea la traslación en los tres ejes.
	for axis in [Vector3.AXIS_X, Vector3.AXIS_Y, Vector3.AXIS_Z]:
		PhysicsServer3D.generic_6dof_joint_set_flag(
			_joint, axis, PhysicsServer3D.G6DOF_JOINT_FLAG_ENABLE_LINEAR_LIMIT, true)
		PhysicsServer3D.generic_6dof_joint_set_param(
			_joint, axis, PhysicsServer3D.G6DOF_JOINT_LINEAR_LOWER_LIMIT, 0.0)
		PhysicsServer3D.generic_6dof_joint_set_param(
			_joint, axis, PhysicsServer3D.G6DOF_JOINT_LINEAR_UPPER_LIMIT, 0.0)

	# Solo el angular X tiene límite; Y/Z bloqueados.
	PhysicsServer3D.generic_6dof_joint_set_flag(
		_joint, Vector3.AXIS_X, PhysicsServer3D.G6DOF_JOINT_FLAG_ENABLE_ANGULAR_LIMIT, true)
	PhysicsServer3D.generic_6dof_joint_set_param(
		_joint, Vector3.AXIS_X, PhysicsServer3D.G6DOF_JOINT_ANGULAR_LOWER_LIMIT,
		deg_to_rad(lower_deg))
	PhysicsServer3D.generic_6dof_joint_set_param(
		_joint, Vector3.AXIS_X, PhysicsServer3D.G6DOF_JOINT_ANGULAR_UPPER_LIMIT,
		deg_to_rad(upper_deg))
	for axis in [Vector3.AXIS_Y, Vector3.AXIS_Z]:
		PhysicsServer3D.generic_6dof_joint_set_flag(
			_joint, axis, PhysicsServer3D.G6DOF_JOINT_FLAG_ENABLE_ANGULAR_LIMIT, true)
		PhysicsServer3D.generic_6dof_joint_set_param(
			_joint, axis, PhysicsServer3D.G6DOF_JOINT_ANGULAR_LOWER_LIMIT, 0.0)
		PhysicsServer3D.generic_6dof_joint_set_param(
			_joint, axis, PhysicsServer3D.G6DOF_JOINT_ANGULAR_UPPER_LIMIT, 0.0)

func _teardown() -> void:
	PhysicsServer3D.free_rid(_joint)
	_body_a.queue_free()
	_body_b.queue_free()
