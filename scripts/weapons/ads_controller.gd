class_name ADSController
extends Node

@export var weapon_pivot: Node3D  ## Padre común del viewmodel y del arma
@export var camera: Camera3D
@export var eye_distance: float = 0.15
@export var ads_speed: float = 6.0
@export var ads_zoom: float = 1.2

var aiming: bool = false

var _hip_transform: Transform3D
var _ads_transform: Transform3D
var _hip_fov: float
var _blend: float = 0.0


func _ready() -> void:
	_hip_transform = weapon_pivot.transform
	_hip_fov = camera.fov


## Llamar al equipar el arma o cambiar la mira, con el arma en reposo.
func set_sight(aim_point: Node3D) -> void:
	var s: Transform3D = weapon_pivot.global_transform.affine_inverse() * aim_point.global_transform
	var t_cam := Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -eye_distance))
	var cam_to_parent: Transform3D = weapon_pivot.get_parent_node_3d().global_transform.affine_inverse() * camera.global_transform
	_ads_transform = cam_to_parent * t_cam * s.affine_inverse()


func _process(delta: float) -> void:
	if not aiming and _blend == 0.0:
		return  # En cadera: no pisamos el pivote ni el FOV

	_blend = move_toward(_blend, 1.0 if aiming else 0.0, ads_speed * delta)
	var t: float = smoothstep(0.0, 1.0, _blend)

	var q_hip: Quaternion = _hip_transform.basis.get_rotation_quaternion()
	var q_ads: Quaternion = _ads_transform.basis.get_rotation_quaternion()
	weapon_pivot.transform = Transform3D(
		Basis(q_hip.slerp(q_ads, t)),
		_hip_transform.origin.lerp(_ads_transform.origin, t)
	)

	var zoom: float = lerpf(1.0, ads_zoom, t)
	camera.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(_hip_fov) * 0.5) / zoom))
