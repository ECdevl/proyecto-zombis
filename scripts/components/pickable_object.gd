@tool
class_name PickableItem extends RigidBody3D
## Objeto agarrable del mundo: lata, botella, mochila, bate...
##
## Esta escena es una PRE-FAB física fija (D-009):
##   raíz RigidBody3D (capa 2, mask 7) + hijo "Malla" (MeshInstance3D) +
##   hijo "Colision" (CollisionShape3D) + "AreaInteraccion" (Area3D, capa 2).
## Al soltar, Player.drop_item() instancia SIEMPRE esta escena; el descriptor
## solo aporta el mesh (ItemDescriptor.item_mesh: Mesh).
##
## Script con @tool: al asignar el descriptor en el EDITOR se ve el mesh en el
## hijo "Malla", que puede rotarse/posicionarse/escalarme para decorar; la
## colisión convexa se recalcula sola y sigue la transformación de la malla.
##
## Ciclo de vida en el juego:
##   - El Player lo mira (el rayo choca con el Area3D de la capa 2) y aprieta
##     USE: Player._on_grabbed_object mete `item` en el inventario y libera
##     este nodo del mundo.
##   - Al soltarlo (clic derecho > "soltar", o la tecla G), Player.drop_item()
##     instancia esta escena y llama a launch().

## Ficha del tipo de objeto. Quien instancia el objeto (Player al soltar, o el
## editor al ponerlo en el mundo) la asigna ANTES de entrar al árbol: así el
## objeto conserva su contenido y estado (una mochila soltada sigue cargando
## lo que llevaba adentro).
@export var item_descriptor: ItemDescriptor:
	set(valor):
		item_descriptor = valor
		_aplicar_descriptor()

## El objeto REAL (con su contenido y estado). Si quien lo instancia no lo
## asigna, _ready lo crea a partir del descriptor.
var item: ItemInstance

## Última malla volcada en "Colision": evita regenerar el casco convexo
## (una operación cara) en cada frame del editor.
var _mesh_en_colision: Mesh

## Transformación de "Malla" ya horneada en el casco: si el usuario mueve o
## escala la malla en el editor, hay que regenerar los puntos.
var _transform_en_colision: Transform3D = Transform3D.IDENTITY


func _ready() -> void:
	# El setter pudo correr antes de que existieran los hijos: reaplica acá.
	_aplicar_descriptor()
	if Engine.is_editor_hint():
		return  # en el editor solo interesa el preview del mesh
	if item == null:
		if item_descriptor == null:
			push_warning("PickableItem '%s': sin item_descriptor y sin item; se descarta." % name)
			queue_free()
			return
		item = ItemInstance.new(item_descriptor)
	if item_descriptor != item.descriptor:
		item_descriptor = item.descriptor
	name = item.descriptor.item_name
	await item_descriptor.ensure_icon(self)


func _get_hint() -> String:
	return "Press USE to pickup"


## Lanza el objeto con una velocidad de salida (m/s) constante.
## Es velocidad y no fuerza a propósito: así la salida no depende de la masa
## (una mochila y una lata salen igual) y no hay que calibrar por objeto.
func launch(velocity: Vector3) -> void:
	linear_velocity = velocity


## Solo en el editor: la colisión sigue al hijo "Malla", de modo que decorar
## el mesh a mano (rotarlo, posicionarlo) mantiene el collider donde se ve.
func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_sincronizar_colision()


## Vuelca el mesh del descriptor en el hijo "Malla", deja que el descriptor lo
## decore (p. ej. el color propio de la ropa) y regenera la colisión convexa.
## Sin descriptor no hay mesh propio: si "Malla" tampoco tiene uno, la
## colisión se borra (nunca debe quedar un casco ajeno sin malla visible).
func _aplicar_descriptor() -> void:
	var malla := get_node_or_null(^"Malla") as MeshInstance3D

	if malla == null:
		return  # los hijos aún no existen: _ready lo reintenta
	if item_descriptor == null:
		_sincronizar_colision()
		return
	malla.mesh = item_descriptor.item_mesh
	item_descriptor.decorar_malla(malla)
	_sincronizar_colision()


## Colisión convexa derivada de la malla: la forma REAL del objeto (un casco
## convexo con su silueta), no una caja genérica. El casco sale en el espacio
## local de la malla, así que su transformación (rotación, posición y escala)
## se HORNEA en los puntos y "Colision" queda con transformación identidad:
## Godot no soporta escalar cuerpos ni formas de colisión (docs oficiales >
## Troubleshooting physics issues), y una escala en el nodo rompe la física.
func _sincronizar_colision() -> void:
	var malla := get_node_or_null(^"Malla") as MeshInstance3D
	var colision := get_node_or_null(^"Colision") as CollisionShape3D
	if malla == null or colision == null:
		return
	if malla.mesh == null:
		# Sin mesh no hay forma que derivar: borra la que quede (p. ej. el
		# casco horneado que el prefab traía) para no dar colisión a un
		# objeto invisible.
		if colision.shape != null:
			colision.shape = null
			_mesh_en_colision = null
			_transform_en_colision = Transform3D.IDENTITY
		return
	if colision.shape != null and _mesh_en_colision == malla.mesh \
			and _transform_en_colision == malla.transform:
		return  # nada cambió desde la última sincronización
	_mesh_en_colision = malla.mesh
	_transform_en_colision = malla.transform
	colision.transform = Transform3D.IDENTITY
	colision.shape = _casco_de_malla(malla)


## Casco convexo de la malla con su transformación horneada en los puntos
## (ver _sincronizar_colision): la forma vive en el espacio local de "Malla"
## sin necesidad de escalar el nodo "Colision".
func _casco_de_malla(malla: MeshInstance3D) -> Shape3D:
	var forma := malla.mesh.create_convex_shape(false, false)
	if forma is ConvexPolygonShape3D:
		var puntos := (forma as ConvexPolygonShape3D).points
		var horneados: PackedVector3Array = []
		horneados.resize(puntos.size())
		for i in puntos.size():
			horneados[i] = malla.transform * puntos[i]
		var casco := ConvexPolygonShape3D.new()
		casco.points = horneados
		return casco
	return forma
