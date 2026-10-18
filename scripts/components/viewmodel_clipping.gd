class_name ViewmodelClipFix
extends Node
## Evita que brazos y armas atraviesen paredes.
##
## Usa BaseMaterial3D.use_z_clip_scale: acerca la PROFUNDIDAD del objeto a la cámara
## sin cambiar cómo se ve. Luces y sombras siguen funcionando.
## Se aplica a todo MeshInstance3D que cuelgue de `roots`, incluso armas que se
## instancien después. Trabaja sobre COPIAS de los materiales (el original no se toca).

## Nodos cuyo contenido es viewmodel (ej: WeaponPivot). Todo lo que cuelgue de ellos se arregla.
@export var roots: Array[Node3D]

## 1.0 = sin efecto. Más bajo = menos clipping.
## Cálculo: s = distancia_mínima_a_pared / largo_del_viewmodel
## Ejemplo: 0.35 / 0.8 = 0.43  ->  usar 0.4
@export_range(0.05, 1.0, 0.01) var z_clip_scale: float = 0.4

## Opcional: FOV propio del viewmodel, independiente del FOV de la cámara.
@export var use_fov_override: bool = false
@export_range(20.0, 120.0, 0.5) var fov_override: float = 75.0

const _DONE_META := &"viewmodel_clip_fixed"


func _ready() -> void:
	# Cubre lo que se instancie más tarde (armas nuevas al equipar).
	get_tree().node_added.connect(_on_node_added)
	# Cubre lo que ya existe.
	for root in roots:
		if not is_instance_valid(root):
			continue
		for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			_fix_mesh(mesh)


func _on_node_added(node: Node) -> void:
	var mesh := node as MeshInstance3D
	if mesh == null:
		return
	for root in roots:
		if is_instance_valid(root) and root.is_ancestor_of(mesh):
			_fix_mesh(mesh)
			return


func _fix_mesh(mesh: MeshInstance3D) -> void:
	if mesh.has_meta(_DONE_META):
		return
	mesh.set_meta(_DONE_META, true)

	# material_override tiene prioridad sobre los materiales por superficie.
	if mesh.material_override:
		mesh.material_override = _patched(mesh.material_override)
	elif mesh.mesh:
		for i in mesh.mesh.get_surface_count():
			var mat := mesh.get_active_material(i)
			if mat:
				mesh.set_surface_override_material(i, _patched(mat))

	if mesh.material_overlay:
		mesh.material_overlay = _patched(mesh.material_overlay)


## Devuelve una COPIA del material con el fix. Si no es BaseMaterial3D, lo deja igual.
func _patched(mat: Material) -> Material:
	var base := mat as BaseMaterial3D
	if base == null:
		push_warning("ViewmodelClipFix: %s no es BaseMaterial3D. Si es ShaderMaterial, escribir Z_CLIP_SCALE en vertex()." % mat.get_class())
		return mat

	var copy := base.duplicate() as BaseMaterial3D
	copy.use_z_clip_scale = true
	copy.z_clip_scale = z_clip_scale
	if use_fov_override:
		copy.use_fov_override = true
		copy.fov_override = fov_override
	if copy.next_pass:
		copy.next_pass = _patched(copy.next_pass)
	return copy
