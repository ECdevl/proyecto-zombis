class_name RagdollDebug
extends Node3D
## Joint-constraint visualizer and live tuner for the ragdoll test scene.
##
## It draws, for every PhysicalBone3D:
##   * the joint frame (X red, Y green, Z blue),
##   * the angular limits of 6DOF joints as arcs around each axis,
##   * the swing cone and twist arc of cone joints,
##   * the angular limits of hinge joints.
##
## The panel lets you start/stop the simulation, pause the tree to inspect a
## pose, and edit the limits of the selected bone while the ragdoll runs.
## Changes are applied straight to the PhysicsServer3D joint, so they are
## visible immediately; use "Copiar valores" to paste them into the .tscn.
##
## Free camera (editor style, works while the tree is paused):
##   * Right mouse button held -> look around (yaw/pitch).
##   * Wheel -> move forward/backward.
##   * W/A/S/D -> move horizontally, Q/E -> down/up.
##   * Shift -> faster.
##
## Bone forces: the panel applies a central impulse to the selected bone so you
## can watch how far its constraints let it travel. The axis is picked with the
## X/Y/Z buttons and the sign with +/-.
##
## Fuente verificada: `modules/jolt_physics/joints/jolt_generic_6dof_joint_3d.cpp`
## (rama 4.7-stable). En Jolt, PARA UN JOINT 6DOF ESTOS PARÁMETROS SE IGNORAN
## con un WARN_PRINT (el valor se descarta):
##   G6DOF_JOINT_LINEAR_LIMIT_SOFTNESS, LINEAR_RESTITUTION, LINEAR_DAMPING,
##   ANGULAR_LIMIT_SOFTNESS, ANGULAR_DAMPING, ANGULAR_RESTITUTION,
##   ANGULAR_FORCE_LIMIT, ANGULAR_ERP.
## Solo tienen efecto: los límites (lower/upper) y sus flags de habilitación,
## los LIMIT SPRINGS (limit_spring_enabled/frequency/damping), los motores y
## los springs comunes. El damping del CUERPO (PhysicalBone3D.angular_damp /
## linear_damp con DAMP_MODE_REPLACE) sí lo aplica el motor y es la palanca
## real contra el temblor.
##
## Axis conventions (Jolt Physics, the engine set in project.godot):
##   6DOF  -> limits are rotations around the joint-local X/Y/Z axes.
##   Cone  -> swing cone around +X (half-angle) and twist around X.
##   Hinge -> rotation around the joint-local Z axis.
##
## The scene contract is just a node path to a PhysicalBoneSimulator3D.

const AXIS_NAMES: Array[String] = ["x", "y", "z"]
const COLOR_X: Color = Color(1.0, 0.28, 0.28)
const COLOR_Y: Color = Color(0.35, 1.0, 0.35)
const COLOR_Z: Color = Color(0.4, 0.55, 1.0)
const COLOR_CONE: Color = Color(1.0, 0.8, 0.2)
const COLOR_SELECTED: Color = Color(1.0, 1.0, 0.25)
const COLOR_CHAIN: Color = Color(0.65, 0.65, 0.65, 0.55)

## Radians of camera rotation per pixel of mouse motion.
const CAMERA_SENSITIVITY: float = 0.0035
## Metres per second of camera movement with W/A/S/D/Q/E.
const CAMERA_SPEED: float = 4.0
## Wheel metres per notch.
const CAMERA_WHEEL_STEP: float = 0.4
const CAMERA_MIN_PITCH: float = -1.5
const CAMERA_MAX_PITCH: float = 1.5
## Impulse range offered by the force controls, in newton-seconds.
const IMPULSE_MIN: float = 0.5
const IMPULSE_MAX: float = 200.0

@export var simulator_path: NodePath = ^"../zombie/ZombiConRig/rig/Skeleton3D/PhysicalBoneSimulator3D"
@export var ragdoll_component_path: NodePath = ^"../zombie/RagdollComponent"
@export var camera_path: NodePath = ^"../Camera3D"
@export var show_axes: bool = true
@export var show_limits: bool = true
@export var show_labels: bool = true
## Radius of the arcs, in metres.
@export var gizmo_radius: float = 0.09
## Segments per arc. More segments = smoother, slightly more lines.
@export var arc_segments: int = 24

var simulator: PhysicalBoneSimulator3D
var ragdoll_component: ZombieRagdoll
var bones: Array[PhysicalBone3D] = []
var selected_bone: PhysicalBone3D

var _camera: Camera3D
var _looking: bool = false
var _cam_yaw: float = 0.0
var _cam_pitch: float = 0.0

var _mesh_instance: MeshInstance3D
var _mesh: ImmediateMesh
var _material: StandardMaterial3D
var _labels_root: Node3D
var _labels: Dictionary = {}  # PhysicalBone3D -> Label3D

var _panel: PanelContainer
var _bone_option: OptionButton
var _info_label: Label
var _status_label: Label
var _rows_root: VBoxContainer
var _control_rows: Array[Dictionary] = []
var _updating_ui: bool = false

# Force controls.
var _impulse_axis: int = 2
var _impulse_sign: float = 1.0
var _impulse_slider: HSlider
var _impulse_label: Label
var _axis_buttons: Array[Button] = []
var _sign_label: Label


func _ready() -> void:
	# Keep drawing and listening to the panel while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	simulator = get_node_or_null(simulator_path) as PhysicalBoneSimulator3D
	ragdoll_component = get_node_or_null(ragdoll_component_path) as ZombieRagdoll
	if simulator == null:
		simulator = _find_simulator()
	if simulator == null:
		push_warning("RagdollDebug: no PhysicalBoneSimulator3D found at %s" % simulator_path)
		return

	for child in simulator.get_children():
		var bone: PhysicalBone3D = child as PhysicalBone3D
		if bone != null:
			bones.append(bone)

	_build_gizmo_nodes()
	_build_ui()
	_select_bone(_preferred_bone())
	_setup_camera()


func _find_simulator() -> PhysicalBoneSimulator3D:
	var found: Array[Node] = get_tree().root.find_children("*", "PhysicalBoneSimulator3D", true, false)
	return found[0] as PhysicalBoneSimulator3D if not found.is_empty() else null


func _preferred_bone() -> PhysicalBone3D:
	for bone in bones:
		if bone.bone_name == "pelvis":
			return bone
	return bones[0] if not bones.is_empty() else null


# ---------------------------------------------------------------------------
# Free camera (editor style)
# ---------------------------------------------------------------------------

func _setup_camera() -> void:
	_camera = get_node_or_null(camera_path) as Camera3D
	if _camera == null:
		_camera = _find_camera()
	if _camera == null:
		push_warning("RagdollDebug: no Camera3D found at %s" % camera_path)
		return
	# Derive the euler angles from the scene transform so the first drag does
	# not snap the camera to a different orientation.
	var basis: Basis = _camera.global_basis.orthonormalized()
	_cam_yaw = atan2(-basis.x.z, basis.z.z)
	_cam_pitch = asin(clampf(basis.x.y, -1.0, 1.0))


func _find_camera() -> Camera3D:
	var found: Array[Node] = get_tree().root.find_children("*", "Camera3D", true, false)
	return found[0] as Camera3D if not found.is_empty() else null


func _apply_camera_rotation() -> void:
	if _camera == null:
		return
	# YXZ euler: yaw around Y, pitch around X. Left-handed sense of the editor.
	var basis: Basis = Basis.from_euler(Vector3(_cam_pitch, _cam_yaw, 0.0))
	_camera.global_basis = basis.orthonormalized()


func _unhandled_input(event: InputEvent) -> void:
	if _camera == null:
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and _looking:
		_cam_yaw -= motion.relative.x * CAMERA_SENSITIVITY
		_cam_pitch = clampf(_cam_pitch - motion.relative.y * CAMERA_SENSITIVITY, CAMERA_MIN_PITCH, CAMERA_MAX_PITCH)
		_apply_camera_rotation()
		get_viewport().set_input_as_handled()
		return

	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null:
		if button.button_index == MOUSE_BUTTON_RIGHT:
			_looking = button.pressed
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if _looking else Input.MOUSE_MODE_VISIBLE)
			get_viewport().set_input_as_handled()
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_move_camera(-CAMERA_WHEEL_STEP)
			get_viewport().set_input_as_handled()
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_move_camera(CAMERA_WHEEL_STEP)
			get_viewport().set_input_as_handled()


func _move_camera(distance: float) -> void:
	if _camera == null:
		return
	# Forward is -Z in Godot's camera convention.
	_camera.global_position += -_camera.global_basis.z * distance


func _process_free_camera(delta: float) -> void:
	if _camera == null:
		return
	var direction: Vector3 = Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		direction -= _camera.global_basis.z
	if Input.is_physical_key_pressed(KEY_S):
		direction += _camera.global_basis.z
	if Input.is_physical_key_pressed(KEY_A):
		direction -= _camera.global_basis.x
	if Input.is_physical_key_pressed(KEY_D):
		direction += _camera.global_basis.x
	if Input.is_physical_key_pressed(KEY_E):
		direction += Vector3.UP
	if Input.is_physical_key_pressed(KEY_Q):
		direction -= Vector3.UP
	if direction == Vector3.ZERO:
		return
	var speed: float = CAMERA_SPEED
	if Input.is_physical_key_pressed(KEY_SHIFT):
		speed *= 3.0
	_camera.global_position += direction.normalized() * speed * delta


# ---------------------------------------------------------------------------
# Gizmo nodes
# ---------------------------------------------------------------------------

func _build_gizmo_nodes() -> void:
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "JointGizmos"
	_mesh = ImmediateMesh.new()
	_mesh_instance.mesh = _mesh
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo = true
	_material.no_depth_test = true
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh_instance.material_override = _material
	add_child(_mesh_instance)

	_labels_root = Node3D.new()
	_labels_root.name = "JointLabels"
	add_child(_labels_root)
	for bone in bones:
		var label: Label3D = Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.font_size = 20
		label.pixel_size = 0.0016
		label.outline_size = 5
		label.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
		label.modulate = Color(0.95, 0.95, 0.95, 0.95)
		_labels_root.add_child(label)
		_labels[bone] = label


func _process(delta: float) -> void:
	_process_free_camera(delta)
	if _mesh == null or simulator == null:
		return
	_redraw_gizmos()


func _redraw_gizmos() -> void:
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _material)

	for bone in bones:
		_draw_bone(bone)
		_update_label(bone)

	_mesh.surface_end()


func _draw_bone(bone: PhysicalBone3D) -> void:
	var joint_frame: Transform3D = bone.global_transform * bone.joint_offset
	var origin: Vector3 = joint_frame.origin
	var basis: Basis = joint_frame.basis.orthonormalized()
	var is_selected: bool = bone == selected_bone

	# Bone chain: a faint line from the joint to the parent joint.
	var parent_bone: PhysicalBone3D = _parent_physical_bone(bone)
	if parent_bone != null:
		_draw_line(origin, (parent_bone.global_transform * parent_bone.joint_offset).origin, COLOR_CHAIN)

	if show_axes:
		var axis_len: float = gizmo_radius * (1.6 if is_selected else 1.1)
		_draw_line(origin, origin + basis.x * axis_len, COLOR_X)
		_draw_line(origin, origin + basis.y * axis_len, COLOR_Y)
		_draw_line(origin, origin + basis.z * axis_len, COLOR_Z)

	if is_selected:
		_draw_wire_circle(origin, basis.x, basis.y, gizmo_radius * 1.25, COLOR_SELECTED, 24)
		_draw_wire_circle(origin, basis.y, basis.z, gizmo_radius * 1.25, COLOR_SELECTED, 24)

	if show_limits:
		_draw_limits(bone, origin, basis)


func _draw_limits(bone: PhysicalBone3D, origin: Vector3, basis: Basis) -> void:
	match bone.joint_type:
		PhysicalBone3D.JOINT_TYPE_6DOF:
			for axis in range(3):
				var enabled: bool = bool(bone.get("joint_constraints/%s/angular_limit_enabled" % AXIS_NAMES[axis]))
				if not enabled:
					continue
				var lower: float = float(bone.get("joint_constraints/%s/angular_limit_lower" % AXIS_NAMES[axis]))
				var upper: float = float(bone.get("joint_constraints/%s/angular_limit_upper" % AXIS_NAMES[axis]))
				var color: Color = _axis_color(axis)
				var axis_vector: Vector3 = _basis_axis(basis, axis)
				var reference: Vector3 = _basis_axis(basis, (axis + 1) % 3)
				_draw_arc(origin, axis_vector, reference, lower, upper, gizmo_radius, color)
		PhysicalBone3D.JOINT_TYPE_CONE:
			var swing: float = float(bone.get("joint_constraints/swing_span"))
			var twist: float = float(bone.get("joint_constraints/twist_span"))
			# Jolt's swing/twist constraint: twist axis is +X, plane axis is +Z.
			_draw_cone(origin, basis.x, basis.y, basis.z, swing, gizmo_radius, COLOR_CONE)
			_draw_arc(origin, basis.x, basis.y, -twist, twist, gizmo_radius * 0.8, COLOR_CONE)
		PhysicalBone3D.JOINT_TYPE_HINGE:
			if bool(bone.get("joint_constraints/angular_limit_enabled")):
				var lower: float = float(bone.get("joint_constraints/angular_limit_lower"))
				var upper: float = float(bone.get("joint_constraints/angular_limit_upper"))
				# Jolt hinge: rotation around +Z, normal/reference axis +X.
				_draw_arc(origin, basis.z, basis.x, lower, upper, gizmo_radius, COLOR_CONE)


func _parent_physical_bone(bone: PhysicalBone3D) -> PhysicalBone3D:
	var skeleton: Skeleton3D = simulator.get_skeleton()
	if skeleton == null:
		return null
	var bone_id: int = skeleton.find_bone(bone.bone_name)
	if bone_id < 0:
		return null
	var parent_id: int = skeleton.get_bone_parent(bone_id)
	if parent_id < 0:
		return null
	var parent_name: String = skeleton.get_bone_name(parent_id)
	for candidate in bones:
		if candidate.bone_name == parent_name:
			return candidate
	return null


func _basis_axis(basis: Basis, axis: int) -> Vector3:
	match axis:
		0:
			return basis.x
		1:
			return basis.y
		_:
			return basis.z


func _axis_color(axis: int) -> Color:	match axis:
		0:
			return COLOR_X
		1:
			return COLOR_Y
		_:
			return COLOR_Z


func _draw_arc(origin: Vector3, axis: Vector3, reference: Vector3, lower_deg: float, upper_deg: float, radius: float, color: Color) -> void:
	# Zero reference, so asymmetric limits are readable.
	_draw_line(origin, origin + reference * radius * 0.85, Color(color, 0.35))

	if is_equal_approx(lower_deg, upper_deg):
		# Locked axis: one ray is enough.
		var locked_dir: Vector3 = Basis(axis, deg_to_rad(lower_deg)) * reference
		_draw_line(origin, origin + locked_dir * radius, color)
		return

	var lower: float = deg_to_rad(lower_deg)
	var upper: float = deg_to_rad(upper_deg)
	var steps: int = max(2, arc_segments)
	var previous: Vector3 = origin + (Basis(axis, lower) * reference) * radius
	_draw_line(origin, previous, color)
	for i in range(1, steps + 1):
		var t: float = float(i) / float(steps)
		var angle: float = lerpf(lower, upper, t)
		var point: Vector3 = origin + (Basis(axis, angle) * reference) * radius
		_draw_line(previous, point, color)
		previous = point
	_draw_line(origin, previous, color)


func _draw_cone(origin: Vector3, axis: Vector3, plane_a: Vector3, plane_b: Vector3, half_angle_deg: float, radius: float, color: Color) -> void:
	var theta: float = deg_to_rad(clampf(half_angle_deg, 0.0, 180.0))
	var steps: int = max(8, arc_segments * 2)
	var previous: Vector3 = Vector3.ZERO
	for i in range(steps + 1):
		var phi: float = TAU * float(i) / float(steps)
		var direction: Vector3 = axis * cos(theta) + (plane_a * cos(phi) + plane_b * sin(phi)) * sin(theta)
		var point: Vector3 = origin + direction * radius
		if i > 0:
			_draw_line(previous, point, color)
		previous = point
	# Generatrices so the cone reads as a volume, not just a ring.
	for i in range(8):
		var phi: float = TAU * float(i) / 8.0
		var direction: Vector3 = axis * cos(theta) + (plane_a * cos(phi) + plane_b * sin(phi)) * sin(theta)
		_draw_line(origin, origin + direction * radius, Color(color, 0.5))


func _draw_wire_circle(origin: Vector3, axis_a: Vector3, axis_b: Vector3, radius: float, color: Color, steps: int) -> void:
	var previous: Vector3 = Vector3.ZERO
	for i in range(steps + 1):
		var angle: float = TAU * float(i) / float(steps)
		var point: Vector3 = origin + (axis_a * cos(angle) + axis_b * sin(angle)) * radius
		if i > 0:
			_draw_line(previous, point, color)
		previous = point


func _draw_line(from: Vector3, to: Vector3, color: Color) -> void:
	_mesh.surface_set_color(color)
	_mesh.surface_add_vertex(from)
	_mesh.surface_set_color(color)
	_mesh.surface_add_vertex(to)


func _update_label(bone: PhysicalBone3D) -> void:
	var label: Label3D = _labels.get(bone) as Label3D
	if label == null:
		return
	label.visible = show_labels
	if not show_labels:
		return
	var joint_frame: Transform3D = bone.global_transform * bone.joint_offset
	label.global_position = joint_frame.origin + Vector3.UP * gizmo_radius * 0.9
	var text: String = bone.bone_name
	if bone == selected_bone:
		text += "\n" + _constraint_summary(bone)
	label.text = text
	label.modulate = COLOR_SELECTED if bone == selected_bone else Color(0.95, 0.95, 0.95, 0.85)


# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "RagdollDebugUI"
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	_panel = PanelContainer.new()
	_panel.position = Vector2(12.0, 12.0)
	_panel.custom_minimum_size = Vector2(520.0, 0.0)
	_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_panel.add_child(margin)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)

	var title: Label = Label.new()
	title.text = "RAGDOLL DEBUG — límites de articulación"
	title.add_theme_font_size_override("font_size", 16)
	column.add_child(title)

	column.add_child(_build_toolbar())
	column.add_child(_build_toggles())

	var bone_row: HBoxContainer = HBoxContainer.new()
	var bone_label: Label = Label.new()
	bone_label.text = "Hueso:"
	bone_row.add_child(bone_label)
	_bone_option = OptionButton.new()
	_bone_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for bone in bones:
		_bone_option.add_item(bone.bone_name)
	_bone_option.item_selected.connect(_on_bone_selected)
	bone_row.add_child(_bone_option)
	column.add_child(bone_row)

	_info_label = Label.new()
	_info_label.add_theme_font_size_override("font_size", 13)
	column.add_child(_info_label)

	_rows_root = VBoxContainer.new()
	_rows_root.add_theme_constant_override("separation", 4)
	column.add_child(_rows_root)

	column.add_child(_build_force_row())

	var copy_button: Button = Button.new()
	copy_button.text = "Copiar valores del hueso"
	copy_button.tooltip_text = "Copia las líneas joint_constraints/... para pegarlas en el .tscn"
	copy_button.pressed.connect(_on_copy_pressed)
	column.add_child(copy_button)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.modulate = Color(0.8, 0.8, 0.8)
	_status_label.text = "Cámara: clic derecho + mover; W/A/S/D; rueda; Q/E; Shift = rápido."
	column.add_child(_status_label)


func _build_force_row() -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)

	var title: Label = Label.new()
	title.text = "Fuerza al hueso seleccionado (ver hasta dónde llegan los límites)"
	title.add_theme_font_size_override("font_size", 13)
	box.add_child(title)

	var row: HBoxContainer = HBoxContainer.new()

	var axis_label: Label = Label.new()
	axis_label.text = "Eje:"
	row.add_child(axis_label)

	_axis_buttons.clear()
	for axis in range(3):
		var axis_button: Button = Button.new()
		axis_button.text = AXIS_NAMES[axis].to_upper()
		axis_button.toggle_mode = true
		axis_button.custom_minimum_size = Vector2(34.0, 0.0)
		axis_button.pressed.connect(_on_axis_pressed.bind(axis))
		row.add_child(axis_button)
		_axis_buttons.append(axis_button)

	var sign_button: Button = Button.new()
	sign_button.text = "+ / -"
	sign_button.custom_minimum_size = Vector2(52.0, 0.0)
	sign_button.pressed.connect(_on_sign_pressed)
	row.add_child(sign_button)

	_sign_label = Label.new()
	_sign_label.text = "+"
	_sign_label.custom_minimum_size = Vector2(20.0, 0.0)
	row.add_child(_sign_label)

	_impulse_slider = _make_slider(IMPULSE_MIN, IMPULSE_MAX, 0.5)
	_impulse_slider.value = 20.0
	_impulse_slider.value_changed.connect(_on_impulse_changed)
	row.add_child(_impulse_slider)

	_impulse_label = _fixed_label("20.0", 48.0)
	row.add_child(_impulse_label)

	var apply_button: Button = Button.new()
	apply_button.text = "Aplicar impulso"
	apply_button.pressed.connect(_on_apply_impulse)
	row.add_child(apply_button)

	box.add_child(row)
	_update_axis_buttons()
	return box


func _on_axis_pressed(axis: int) -> void:
	_impulse_axis = axis
	_update_axis_buttons()


func _update_axis_buttons() -> void:
	for index in range(_axis_buttons.size()):
		_axis_buttons[index].button_pressed = index == _impulse_axis


func _on_sign_pressed() -> void:
	_impulse_sign = -_impulse_sign
	_sign_label.text = "+" if _impulse_sign > 0.0 else "-"


func _on_impulse_changed(value: float) -> void:
	_impulse_label.text = "%.1f" % value


func _on_apply_impulse() -> void:
	if selected_bone == null:
		_status_label.text = "No hay hueso seleccionado."
		return
	if not simulator.is_simulating_physics() and ragdoll_component != null and not ragdoll_component.is_ragdoll:
		_status_label.text = "El ragdoll no está corriendo; el impulso se aplicará al arrancar."
	var direction: Vector3 = Vector3.ZERO
	match _impulse_axis:
		0:
			direction = Vector3.RIGHT
		1:
			direction = Vector3.UP
		_:
			direction = Vector3.BACK
	direction *= _impulse_sign
	var magnitude: float = _impulse_slider.value
	selected_bone.apply_central_impulse(direction * magnitude)
	_status_label.text = "Impulso %.1f N·s %s%s aplicado a %s." % [
		magnitude, "" if _impulse_sign > 0.0 else "-",
		AXIS_NAMES[_impulse_axis].to_upper(), selected_bone.bone_name]


func _build_toolbar() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	var start_button: Button = Button.new()
	start_button.text = "Iniciar ragdoll"
	start_button.pressed.connect(_on_start_pressed)
	row.add_child(start_button)

	var stop_button: Button = Button.new()
	stop_button.text = "Detener"
	stop_button.pressed.connect(_on_stop_pressed)
	row.add_child(stop_button)

	var pause_button: Button = Button.new()
	pause_button.text = "Pausa"
	pause_button.toggle_mode = true
	pause_button.toggled.connect(_on_pause_toggled)
	row.add_child(pause_button)

	var reload_button: Button = Button.new()
	reload_button.text = "Reiniciar escena"
	reload_button.pressed.connect(_on_reload_pressed)
	row.add_child(reload_button)
	return row


func _build_toggles() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_child(_make_check("Ejes", show_axes, _on_show_axes))
	row.add_child(_make_check("Límites", show_limits, _on_show_limits))
	row.add_child(_make_check("Nombres", show_labels, _on_show_labels))
	row.add_child(_make_check("Rayos X", true, _on_xray))
	return row


func _make_check(text: String, pressed: bool, callback: Callable) -> CheckBox:
	var check: CheckBox = CheckBox.new()
	check.text = text
	check.button_pressed = pressed
	check.toggled.connect(callback)
	return check


func _on_bone_selected(index: int) -> void:
	if index < 0 or index >= bones.size():
		return
	_select_bone(bones[index])


func _select_bone(bone: PhysicalBone3D) -> void:
	selected_bone = bone
	if bone == null:
		return
	var index: int = bones.find(bone)
	if index >= 0 and _bone_option.selected != index:
		_bone_option.select(index)
	_rebuild_controls()
	_refresh_controls()


func _rebuild_controls() -> void:
	for child in _rows_root.get_children():
		_rows_root.remove_child(child)
		child.queue_free()
	_control_rows.clear()
	if selected_bone == null:
		return

	match selected_bone.joint_type:
		PhysicalBone3D.JOINT_TYPE_6DOF:
			_info_label.text = "6DOF — arcos por eje local (X rojo, Y verde, Z azul)."
			_rows_root.add_child(_make_header_row())
			for axis in range(3):
				_rows_root.add_child(_make_axis_row(axis))
		PhysicalBone3D.JOINT_TYPE_CONE:
			_info_label.text = "Cone twist — cono de swing alrededor de +X (Jolt) y giro de twist."
			_rows_root.add_child(_make_cone_row("Swing", "joint_constraints/swing_span", 0.0, 180.0))
			_rows_root.add_child(_make_cone_row("Twist", "joint_constraints/twist_span", 0.0, 180.0))
		PhysicalBone3D.JOINT_TYPE_HINGE:
			_info_label.text = "Hinge — giro alrededor de +Z."
			_rows_root.add_child(_make_hinge_row())
		_:
			_info_label.text = "Este tipo de joint no tiene límites angulares editables."


func _make_header_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_child(_fixed_label("Eje", 34.0))
	row.add_child(_fixed_label("Activo", 56.0))
	row.add_child(_fixed_label("Mín", 92.0))
	row.add_child(_fixed_label("Máx", 92.0))
	row.add_child(_fixed_label("Valor", 110.0))
	return row


func _make_axis_row(axis: int) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_child(_fixed_label(AXIS_NAMES[axis].to_upper(), 34.0))

	var enabled: CheckBox = CheckBox.new()
	enabled.custom_minimum_size = Vector2(56.0, 0.0)
	enabled.toggled.connect(_on_enabled_toggled.bind(axis))
	row.add_child(enabled)

	var lower: HSlider = _make_slider(-180.0, 180.0, 1.0)
	lower.value_changed.connect(_on_limit_changed.bind(axis, false))
	row.add_child(lower)

	var upper: HSlider = _make_slider(-180.0, 180.0, 1.0)
	upper.value_changed.connect(_on_limit_changed.bind(axis, true))
	row.add_child(upper)

	var value_label: Label = _fixed_label("", 110.0)
	row.add_child(value_label)

	_control_rows.append({
		"kind": "6dof",
		"axis": axis,
		"enabled": enabled,
		"lower": lower,
		"upper": upper,
		"value": value_label,
	})
	return row


func _make_cone_row(text: String, property: String, min_value: float, max_value: float) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_child(_fixed_label(text, 60.0))
	var slider: HSlider = _make_slider(min_value, max_value, 0.1)
	slider.value_changed.connect(_on_scalar_changed.bind(property))
	row.add_child(slider)
	var value_label: Label = _fixed_label("", 90.0)
	row.add_child(value_label)
	_control_rows.append({
		"kind": "scalar",
		"property": property,
		"slider": slider,
		"value": value_label,
	})
	return row


func _make_hinge_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_child(_fixed_label("Límite", 60.0))
	var lower: HSlider = _make_slider(-180.0, 180.0, 1.0)
	lower.value_changed.connect(_on_hinge_changed.bind(false))
	row.add_child(lower)
	var upper: HSlider = _make_slider(-180.0, 180.0, 1.0)
	upper.value_changed.connect(_on_hinge_changed.bind(true))
	row.add_child(upper)
	var value_label: Label = _fixed_label("", 100.0)
	row.add_child(value_label)
	_control_rows.append({
		"kind": "hinge",
		"lower": lower,
		"upper": upper,
		"value": value_label,
	})
	return row


func _fixed_label(text: String, width: float) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(width, 0.0)
	return label


func _make_slider(min_value: float, max_value: float, step: float) -> HSlider:
	var slider: HSlider = HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.custom_minimum_size = Vector2(92.0, 0.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return slider


func _refresh_controls() -> void:
	if selected_bone == null:
		return
	_updating_ui = true
	for row in _control_rows:
		match String(row["kind"]):
			"6dof":
				var axis: int = int(row["axis"])
				var enabled: bool = bool(selected_bone.get("joint_constraints/%s/angular_limit_enabled" % AXIS_NAMES[axis]))
				var lower: float = float(selected_bone.get("joint_constraints/%s/angular_limit_lower" % AXIS_NAMES[axis]))
				var upper: float = float(selected_bone.get("joint_constraints/%s/angular_limit_upper" % AXIS_NAMES[axis]))
				(row["enabled"] as CheckBox).button_pressed = enabled
				(row["lower"] as HSlider).value = lower
				(row["upper"] as HSlider).value = upper
				(row["value"] as Label).text = "%.1f / %.1f" % [lower, upper]
			"scalar":
				var value: float = float(selected_bone.get(String(row["property"])))
				(row["slider"] as HSlider).value = value
				(row["value"] as Label).text = "%.1f°" % value
			"hinge":
				var lower: float = float(selected_bone.get("joint_constraints/angular_limit_lower"))
				var upper: float = float(selected_bone.get("joint_constraints/angular_limit_upper"))
				(row["lower"] as HSlider).value = lower
				(row["upper"] as HSlider).value = upper
				(row["value"] as Label).text = "%.1f / %.1f" % [lower, upper]
	_updating_ui = false


func _on_enabled_toggled(pressed: bool, axis: int) -> void:
	if _updating_ui or selected_bone == null:
		return
	selected_bone.set("joint_constraints/%s/angular_limit_enabled" % AXIS_NAMES[axis], pressed)
	_refresh_controls()


func _on_limit_changed(value: float, axis: int, is_upper: bool) -> void:
	if _updating_ui or selected_bone == null:
		return
	var suffix: String = "upper" if is_upper else "lower"
	selected_bone.set("joint_constraints/%s/angular_limit_%s" % [AXIS_NAMES[axis], suffix], value)
	_refresh_controls()


func _on_scalar_changed(value: float, property: String) -> void:
	if _updating_ui or selected_bone == null:
		return
	selected_bone.set(property, value)
	_refresh_controls()


func _on_hinge_changed(value: float, is_upper: bool) -> void:
	if _updating_ui or selected_bone == null:
		return
	var suffix: String = "upper" if is_upper else "lower"
	selected_bone.set("joint_constraints/angular_limit_%s" % suffix, value)
	_refresh_controls()


func _constraint_summary(bone: PhysicalBone3D) -> String:
	match bone.joint_type:
		PhysicalBone3D.JOINT_TYPE_6DOF:
			var parts: Array[String] = []
			for axis in range(3):
				var enabled: bool = bool(bone.get("joint_constraints/%s/angular_limit_enabled" % AXIS_NAMES[axis]))
				if not enabled:
					continue
				var lower: float = float(bone.get("joint_constraints/%s/angular_limit_lower" % AXIS_NAMES[axis]))
				var upper: float = float(bone.get("joint_constraints/%s/angular_limit_upper" % AXIS_NAMES[axis]))
				parts.append("%s[%.0f,%.0f]" % [AXIS_NAMES[axis].to_upper(), lower, upper])
			return "6DOF " + " ".join(PackedStringArray(parts))
		PhysicalBone3D.JOINT_TYPE_CONE:
			return "CONE swing %.0f° twist %.0f°" % [float(bone.get("joint_constraints/swing_span")), float(bone.get("joint_constraints/twist_span"))]
		PhysicalBone3D.JOINT_TYPE_HINGE:
			return "HINGE [%.0f, %.0f]" % [float(bone.get("joint_constraints/angular_limit_lower")), float(bone.get("joint_constraints/angular_limit_upper"))]
		_:
			return "PIN/NONE"


func _on_copy_pressed() -> void:
	if selected_bone == null:
		return
	var lines: PackedStringArray = PackedStringArray()
	lines.append("; %s" % selected_bone.name)
	match selected_bone.joint_type:
		PhysicalBone3D.JOINT_TYPE_6DOF:
			for axis in range(3):
				lines.append("joint_constraints/%s/angular_limit_enabled = %s" % [AXIS_NAMES[axis], str(bool(selected_bone.get("joint_constraints/%s/angular_limit_enabled" % AXIS_NAMES[axis]))).to_lower()])
				lines.append("joint_constraints/%s/angular_limit_lower = %.4f" % [AXIS_NAMES[axis], float(selected_bone.get("joint_constraints/%s/angular_limit_lower" % AXIS_NAMES[axis]))])
				lines.append("joint_constraints/%s/angular_limit_upper = %.4f" % [AXIS_NAMES[axis], float(selected_bone.get("joint_constraints/%s/angular_limit_upper" % AXIS_NAMES[axis]))])
		PhysicalBone3D.JOINT_TYPE_CONE:
			lines.append("joint_constraints/swing_span = %.4f" % float(selected_bone.get("joint_constraints/swing_span")))
			lines.append("joint_constraints/twist_span = %.4f" % float(selected_bone.get("joint_constraints/twist_span")))
		PhysicalBone3D.JOINT_TYPE_HINGE:
			lines.append("joint_constraints/angular_limit_lower = %.4f" % float(selected_bone.get("joint_constraints/angular_limit_lower")))
			lines.append("joint_constraints/angular_limit_upper = %.4f" % float(selected_bone.get("joint_constraints/angular_limit_upper")))
	DisplayServer.clipboard_set("\n".join(lines))
	_status_label.text = "Valores copiados: %s" % selected_bone.bone_name


func _on_start_pressed() -> void:
	if ragdoll_component == null:
		_status_label.text = "No hay RagdollComponent en %s" % ragdoll_component_path
		return
	ragdoll_component.start(true)
	_status_label.text = "Ragdoll iniciado."


func _on_stop_pressed() -> void:
	if simulator == null:
		return
	simulator.physical_bones_stop_simulation()
	if ragdoll_component != null:
		ragdoll_component.is_ragdoll = false
		ragdoll_component.permanent = false
	_status_label.text = "Simulación detenida (pose de reposo)."


func _on_pause_toggled(pressed: bool) -> void:
	get_tree().paused = pressed
	_status_label.text = "Pausado." if pressed else "Física reanudada."


func _on_reload_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_show_axes(pressed: bool) -> void:
	show_axes = pressed


func _on_show_limits(pressed: bool) -> void:
	show_limits = pressed


func _on_show_labels(pressed: bool) -> void:
	show_labels = pressed


func _on_xray(pressed: bool) -> void:
	_material.no_depth_test = pressed
