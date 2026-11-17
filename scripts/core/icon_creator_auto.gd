extends SubViewport
## Generador automático de íconos de respaldo.
##
## ItemDescriptor.ensure_icon() instancia esta escena liviana (sin el modelo del
## estudio) y llama create_texture() para los objetos que no tienen ícono manual.
## Mantiene el comportamiento histórico: malla centrada por AABB y cámara
## ortográfica, con fondo transparente.


func create_texture(malla: MeshInstance3D) -> ImageTexture:
	if DisplayServer.get_name() == "headless":
		if is_instance_valid(malla):
			malla.queue_free()
		queue_free()
		return null
	if not is_inside_tree():
		if is_instance_valid(malla):
			malla.queue_free()
		queue_free()
		return null

	add_child(malla)
	var aabb: AABB = malla.get_aabb()
	malla.global_position -= aabb.get_center()

	var radio: float = aabb.get_longest_axis_size() * 0.5
	var camara: Camera3D = $Camera3D
	camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	camara.size = 1.0
	camara.global_position = Vector3(0.0, 0.0, radio * 2.5)
	camara.look_at(malla.global_position)
	camara.current = true

	render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw

	var imagen: Image = get_texture().get_image()
	var textura: ImageTexture = null
	if imagen != null:
		textura = ImageTexture.create_from_image(imagen)

	if is_instance_valid(malla):
		malla.queue_free()
	queue_free()
	return textura
