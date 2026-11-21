class_name FlashlightDescriptor extends HoldableDescriptor
## Linterna de mano: se sostiene en cualquiera de las dos manos, pero se ancla
## visualmente al hueso de la mano izquierda del viewmodel.
## No es EquippableDescriptor: HandsModel usa ese tipo para decidir el arma
## principal. HoldableDescriptor aporta "se puede sostener" + acción "equipar".

## Escena completa del modelo (p. ej. linterna.glb): se instancia en la mano.
## Si trae un SpotLight3D se usa; si no, FlashlightController crea uno con los
## parámetros de abajo.
@export var held_scene: PackedScene
@export var hand_offset: Vector3 = Vector3.ZERO
@export var hand_rot : Vector3 = Vector3.ZERO
@export_flags_3d_physics var caster_mask : int = 1
## Parámetros del SpotLight3D creado por defecto (el modelo puede traer el suyo).
@export var light_energy: float = 2.0
@export var spot_range: float = 12.0
@export var spot_angle: float = 30.0
@export var shadow_enabled: bool = false

## Asegura que item_mesh exista (necesaria para soltar al mundo y para el icono)
## tomándola de la escena del modelo si hace falta.
func ensure_item_mesh() -> void:
	if item_mesh != null or held_scene == null:
		return
	var temp: Node = held_scene.instantiate()
	var malla := temp.find_child("Cilindro", true, false) as MeshInstance3D
	if malla == null:
		# Respaldo: primera MeshInstance3D que se encuentre.
		malla = _find_mesh_instance(temp)
	if malla and malla.mesh:
		item_mesh = malla.mesh
	temp.free()


func _ensure_item_mesh() -> void:
	ensure_item_mesh()


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_mesh_instance(child)
		if found:
			return found
	return null


func ensure_icon(host: Node) -> void:
	_ensure_item_mesh()
	await super.ensure_icon(host)


func decorar_malla(malla: MeshInstance3D) -> void:
	_ensure_item_mesh()
	if malla.mesh == null and item_mesh != null:
		malla.mesh = item_mesh
