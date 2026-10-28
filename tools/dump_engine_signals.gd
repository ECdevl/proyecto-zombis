extends SceneTree
## Genera tools/engine_signals.py: la tabla de senales que declara cada clase
## del motor (con sus clases base) que el proyecto usa de verdad.
## Sirve para que el verificador estatico de conexiones pueda distinguir
## "senal del motor" de "senal que no existe".
##
## Uso:  godot --headless --path . --script res://tools/dump_engine_signals.gd

const SALIDA := "res://tools/engine_signals.py"


func _initialize() -> void:
	var tipo_re := RegEx.create_from_string("type=\"(\\w+)\"")

	var tipos := {}
	for escena in _escenas("res://"):
		var texto := FileAccess.get_file_as_string(escena)
		for m in tipo_re.search_all(texto):
			tipos[m.get_string(1)] = true

	var tabla := {}
	for tipo in tipos.keys():
		var senales: Array[String] = []
		var actual: String = tipo
		while actual != "":
			for s in ClassDB.class_get_signal_list(actual):
				var nombre: String = s["name"]
				if not senales.has(nombre):
					senales.append(nombre)
			actual = ClassDB.get_parent_class(actual)
		if not senales.is_empty():
			tabla[tipo] = senales

	var lineas: Array[String] = []
	lineas.append("# Tabla de senales del motor, generada por tools/dump_engine_signals.gd.")
	lineas.append("# Solo incluye las clases que aparecen como type=\"...\" en alguna escena.")
	lineas.append("# NO EDITAR A MANO. Regenerar con:")
	lineas.append("#   godot --headless --path . --script res://tools/dump_engine_signals.gd")
	lineas.append("")
	lineas.append("ENGINE_SIGNALS = {")
	for clase in tabla.keys():
		var senales: Array = tabla[clase]
		senales.sort()
		lineas.append('\t"%s": %s,' % [clase, str(senales)])
	lineas.append("}")
	lineas.append("")

	var f := FileAccess.open(SALIDA, FileAccess.WRITE)
	if f == null:
		push_error("No se pudo escribir %s" % SALIDA)
		quit(1)
		return
	f.store_string("\n".join(lineas))
	f.close()
	print("OK: %d tipos de nodo -> %s" % [tabla.size(), SALIDA])
	quit(0)


## Lista recursivamente los .tscn del proyecto.
func _escenas(ruta: String) -> Array[String]:
	var salida: Array[String] = []
	var dir := DirAccess.open(ruta)
	if dir == null:
		return salida
	dir.list_dir_begin()
	var nombre := dir.get_next()
	while nombre != "":
		if dir.current_is_dir():
			if not nombre.begins_with("."):
				salida.append_array(_escenas(ruta.path_join(nombre)))
		elif nombre.ends_with(".tscn"):
			salida.append(ruta.path_join(nombre))
		nombre = dir.get_next()
	dir.list_dir_end()
	return salida
