extends SubViewport
@onready var camera_3d: Camera3D = $Camera3D

## Captura `malla` (una MeshInstance3D con su mesh y sus materiales ya puestos)
## como textura de ícono. Libera la malla y este viewport al terminar.
func create_texture(malla: MeshInstance3D) -> ImageTexture:
	render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(malla)

	# AABB del mesh (la malla llega con transformación identidad).
	var aabb := malla.get_aabb()
	malla.global_position -= aabb.get_center()

	# Ajustar cámara según tamaño del modelo
	var radius := aabb.get_longest_axis_size() * 0.5
	camera_3d.global_position = Vector3(0, 0, radius * 2.5)
	camera_3d.look_at(malla.global_position)

	await RenderingServer.frame_post_draw
	var image: Image = get_texture().get_image()
	var texture := ImageTexture.create_from_image(image)
	malla.queue_free()
	queue_free()
	return texture
