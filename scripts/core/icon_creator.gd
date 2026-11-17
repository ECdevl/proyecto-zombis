@tool
extends Node3D
## Estudio de íconos.
##
## EN EL EDITOR:
## 1. Arrastrá el modelo importado dentro del nodo "Modelo" y posicionalo.
## 2. Encuadralo con "Camera3D" (seleccioná la cámara para ver su vista previa).
## 3. Presioná "Capturar ícono" en el inspector del nodo raíz.
## El botón renderiza "SubViewport", toma su imagen con get_texture().get_image(),
## crea una ImageTexture y la guarda como .res o .tres.
## Si asignás un ItemDescriptor, además le asigna esa textura al campo icon.
##
## EN RUNTIME:
## El respaldo automático de los objetos sin ícono manual usa otra escena
## liviana (icon_creator_auto.tscn), para no cargar el modelo del estudio.

const FORMATO_BINARIO: int = 0
const FORMATO_TEXTO: int = 1

@onready var modelo: Node3D = $Modelo
@onready var camera_3d: Camera3D = $Camera3D
@onready var luz_estudio: OmniLight3D = $OmniLight3D
@onready var sub_viewport: SubViewport = $SubViewport
@onready var capture_camera: Camera3D = $SubViewport/Camera3D
@onready var capture_light: OmniLight3D = $SubViewport/OmniLight3D

## Nodos temporales agregados al SubViewport para una captura. Se liberan
## después de tomar la imagen, sin tocar los nodos fijos del estudio.
var _copias: Array[Node] = []

@export_group("Captura")
## Tamaño cuadrado de la textura capturada.
@export_range(16, 2048, 1) var resolucion: int = 256
## Carpeta donde se guarda la textura. Se crea si no existe.
@export_dir var directorio_salida: String = "res://assets/sprites/icons"
## Nombre del archivo, sin extensión.
@export var nombre_archivo: String = "icono"
## Formato del recurso de textura guardado.
@export_enum("Binario (.res)", "Texto (.tres)") var formato: int = FORMATO_BINARIO
## Si está activo y hay un descriptor asignado, le asigna y guarda el ícono.
@export var asignar_al_descriptor: bool = true
## Opcional: arrastrá acá el .tres del objeto (ItemDescriptor) para asignarle
## automáticamente la textura capturada.
@export var item_descriptor: Resource
@export_tool_button("Capturar ícono") var capturar_accion: Callable = capturar


func _ready() -> void:
	# El SubViewport solo se renderiza cuando se captura; no en cada frame.
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if Engine.is_editor_hint():
		return
	# En runtime el estudio no debe verse en el mundo: solo el SubViewport captura.
	if is_instance_valid(modelo):
		modelo.visible = false
	if is_instance_valid(luz_estudio):
		luz_estudio.visible = false
	if is_instance_valid(camera_3d):
		camera_3d.current = false


func capturar() -> void:
	if not Engine.is_editor_hint():
		return
	if not is_inside_tree():
		return
	if not _modelo_tiene_contenido():
		push_warning("IconCreator: arrastrá un modelo dentro del nodo 'Modelo' antes de capturar.")
		return

	var ruta: String = _construir_ruta()
	if ruta.is_empty():
		return

	var textura: ImageTexture = await _renderizar_captura()
	if textura == null:
		return

	var error: int = ResourceSaver.save(textura, ruta)
	if error != OK:
		push_error("IconCreator: no se pudo guardar %s (error %d)." % [ruta, error])
		return
	print("IconCreator: ícono guardado en ", ruta)

	var filesystem: EditorFileSystem = EditorInterface.get_resource_filesystem()
	if filesystem != null:
		filesystem.update_file(ruta)

	if asignar_al_descriptor:
		_asignar_icono(ruta)


## Renderiza el modelo del estudio dentro del SubViewport y devuelve la textura.
func _renderizar_captura() -> ImageTexture:
	sub_viewport.size = Vector2i(resolucion, resolucion)
	sub_viewport.transparent_bg = true
	_limpiar_copias()

	# Copia del estudio dentro del mundo aislado del SubViewport.
	var copia: Node3D = modelo.duplicate() as Node3D
	if copia == null:
		push_error("IconCreator: no se pudo duplicar el nodo 'Modelo'.")
		return null
	sub_viewport.add_child(copia)
	_copias.append(copia)
	copia.global_transform = modelo.global_transform

	# Si el modelo trae sus propias cámaras, que no reemplacen a la de captura.
	for nodo: Node in copia.find_children("*", "Camera3D", true, false):
		var camara_interna: Camera3D = nodo as Camera3D
		if camara_interna != null:
			camara_interna.current = false

	# La cámara y la luz de captura copian el encuadre del estudio.
	capture_camera.projection = camera_3d.projection
	capture_camera.fov = camera_3d.fov
	capture_camera.size = camera_3d.size
	capture_camera.near = camera_3d.near
	capture_camera.far = camera_3d.far
	capture_camera.frustum_offset = camera_3d.frustum_offset
	capture_camera.keep_aspect = camera_3d.keep_aspect
	capture_camera.global_transform = camera_3d.global_transform
	capture_camera.current = true

	capture_light.global_transform = luz_estudio.global_transform
	capture_light.light_color = luz_estudio.light_color
	capture_light.light_energy = luz_estudio.light_energy
	capture_light.omni_range = luz_estudio.omni_range
	capture_light.shadow_enabled = luz_estudio.shadow_enabled
	capture_light.visible = luz_estudio.visible

	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw

	var imagen: Image = sub_viewport.get_texture().get_image()
	_limpiar_copias()
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

	if imagen == null:
		push_error("IconCreator: el SubViewport no devolvió imagen.")
		return null
	return ImageTexture.create_from_image(imagen)


func _limpiar_copias() -> void:
	for nodo: Node in _copias:
		if not is_instance_valid(nodo):
			continue
		var padre: Node = nodo.get_parent()
		if padre != null:
			padre.remove_child(nodo)
		nodo.free()
	_copias.clear()


func _modelo_tiene_contenido() -> bool:
	if modelo is MeshInstance3D:
		var malla_modelo: MeshInstance3D = modelo as MeshInstance3D
		return malla_modelo.mesh != null
	return modelo.get_child_count() > 0


func _construir_ruta() -> String:
	var directorio: String = directorio_salida.strip_edges()
	if directorio.is_empty():
		directorio = "res://assets/sprites/icons"

	var nombre: String = nombre_archivo.strip_edges().get_file()
	if nombre.is_empty():
		nombre = "icono"
	var extension_escrita: String = nombre.get_extension().to_lower()
	if extension_escrita == "res" or extension_escrita == "tres":
		nombre = nombre.get_basename()

	var extension: String = ".res" if formato == FORMATO_BINARIO else ".tres"
	var ruta: String = directorio.path_join(nombre + extension)

	var error_dir: int = DirAccess.make_dir_recursive_absolute(directorio)
	if error_dir != OK and error_dir != ERR_ALREADY_EXISTS:
		push_error("IconCreator: no se pudo crear la carpeta %s (error %d)." % [directorio, error_dir])
		return ""
	return ruta


func _asignar_icono(ruta: String) -> void:
	if item_descriptor == null:
		return
	if not _tiene_propiedad(item_descriptor, "icon"):
		push_warning("IconCreator: el recurso asignado no tiene la propiedad 'icon'.")
		return

	var textura: Texture2D = ResourceLoader.load(ruta, "Texture2D", ResourceLoader.CACHE_MODE_REPLACE) as Texture2D
	if textura == null:
		push_error("IconCreator: no se pudo cargar la textura guardada para asignarla.")
		return

	item_descriptor.set("icon", textura)
	var ruta_descriptor: String = item_descriptor.resource_path
	if ruta_descriptor.is_empty():
		push_warning("IconCreator: el descriptor no tiene archivo propio; el ícono quedó asignado solo en memoria.")
		return

	var error: int = ResourceSaver.save(item_descriptor, ruta_descriptor)
	if error != OK:
		push_error("IconCreator: no se pudo guardar el descriptor %s (error %d)." % [ruta_descriptor, error])
		return
	print("IconCreator: ícono asignado a ", ruta_descriptor)


func _tiene_propiedad(objeto: Object, nombre: String) -> bool:
	if objeto == null:
		return false
	for propiedad: Dictionary in objeto.get_property_list():
		if propiedad.get("name", "") == nombre:
			return true
	return false
