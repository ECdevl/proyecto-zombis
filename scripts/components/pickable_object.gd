extends Node3D
class_name PickableItem
## Objeto agarrable del mundo: lata, botella, mochila...
##
## Cómo se usa (flujo del proyecto):
##   1. En Blender el objeto lleva el sufijo `-rigid`; Godot lo importa como
##      RigidBody3D con su colisión convexa ya generada.
##   2. Arrancás el modelo a la escena y le pegás este script al nodo raíz.
##      Funciona tanto si la raíz ES el RigidBody3D como si es un nodo
##      envoltorio con el cuerpo adentro.
##   3. Asignás `item_descriptor` (la ficha del objeto).
##
## Ciclo de vida en el juego:
##   - El Player lo mira (el rayo choca con el Area3D de la capa 2) y aprieta
##     USE: `Player._on_grabbed_object` mete `item` en el inventario y libera
##     este nodo del mundo.
##   - Al soltarlo (clic derecho > "soltar", o la tecla G),
##     `Player.drop_item()` instancia `item_descriptor.item_mesh`, le pasa el
##     `ItemInstance` y llama a `launch()`.

## Ficha del tipo de objeto. Si se la asigna ANTES de entrar al árbol (al
## soltar), el objeto conserva su contenido y estado: una mochila soltada
## sigue cargando lo que llevaba adentro.
@export var item_descriptor: ItemDescriptor

## Forma del Area3D de interacción. Si la escena ya trae un área en la capa 2
## (por ejemplo `pickup_area.tscn`), se reutiliza y ésta no interviene.
@export var interact_resource: Shape3D = preload("uid://fg2o3foj2ole")

## Capas del cuerpo físico. 2 = capa de actores del proyecto (objetos y zombis);
## el mask 7 NO incluye la capa 4 del Player, así el objeto soltado no choca
## contra quien lo lanzó. Exportadas por si algún objeto necesita lo distinto.
@export_flags_3d_physics var body_layer: int = 2
@export_flags_3d_physics var body_mask: int = 7

## El objeto REAL (con su contenido y estado). Ver arriba: quién lo instancia
## lo asigna antes de agregar este nodo a la escena.
var item: ItemInstance

var _body: RigidBody3D
var _area: Area3D


func _get_hint() -> String:
	return "Press USE to pickup"


func _ready() -> void:
	if item == null:
		if item_descriptor == null:
			push_warning("PickableItem '%s': sin item_descriptor y sin item asignado; se descarta." % name)
			queue_free()
			return
		item = ItemInstance.new(item_descriptor)
	item_descriptor = item.descriptor
	name = item.descriptor.item_name
	_body = _find_rigid_body()
	if _body == null:
		push_warning("PickableItem '%s': no hay RigidBody3D. Importá el modelo de Blender con el sufijo -rigid." % name)
	else:
		_body.collision_layer = body_layer
		_body.collision_mask = body_mask
	_area = _setup_interact_area()
	await item_descriptor.ensure_icon(self)


## El cuerpo físico real de este objeto (null si no hay: se aviso en _ready).
func get_rigid_body() -> RigidBody3D:
	return _body


## Lanza el objeto con una velocidad de salida (m/s) constante.
## Es velocidad y no fuerza a propósito: así la salida no depende de la masa
## (una mochila y una lata salen igual) y no hay que calibrar por objeto.
func launch(velocity: Vector3) -> void:
	if _body == null:
		push_warning("PickableItem '%s': no se puede lanzar sin RigidBody3D." % name)
		return
	_body.linear_velocity = velocity


## El cuerpo puede ser este propio nodo (script pegado en la raíz -rigid) o un
## RigidBody3D adentro del modelo (si la raíz importada es un nodo envoltorio).
##
## Se testea sobre una referencia 'Node': el analizador de GDScript no permite
## `self is RigidBody3D` aunque el nodo SEA un RigidBody3D en runtime, porque el
## script declara `extends Node3D`. Ver ERRORES.md E-009.
func _find_rigid_body() -> RigidBody3D:
	var me: Node = self
	if me is RigidBody3D:
		return me as RigidBody3D
	return _buscar_cuerpo(self)


func _buscar_cuerpo(from: Node) -> RigidBody3D:
	for child in from.get_children():
		if child is RigidBody3D:
			return child as RigidBody3D
		var found := _buscar_cuerpo(child)
		if found:
			return found
	return null


## Area3D en la capa 2: es lo que el rayo de interacción del Player "ve".
## Si la escena ya trae un área en esa capa se reutiliza; si no, se crea.
func _setup_interact_area() -> Area3D:
	var host: Node3D = _body if _body else self
	for child in host.get_children():
		var existing := child as Area3D
		if existing and existing.get_collision_layer_value(2):
			if existing.get_child_count() == 0:
				existing.add_child(_crear_shape())
			# owner = self: el Player identifica el objeto vía area.owner.
			existing.owner = self
			return existing
	var area := Area3D.new()
	area.set_collision_layer_value(1, false)
	area.set_collision_layer_value(2, true)
	area.add_child(_crear_shape())
	host.add_child(area)
	# owner = self: el Player identifica el objeto vía area.owner.
	area.owner = self
	return area


func _crear_shape() -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	shape.shape = interact_resource
	return shape
