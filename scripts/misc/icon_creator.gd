# misc/icon_creator.gd — YA NO autoload, se instancia bajo demanda
extends SubViewport
@onready var camera_3d: Camera3D = $Camera3D


func create_texture(mesh: PackedScene) -> ImageTexture:
	render_target_update_mode = SubViewport.UPDATE_ONCE

	var display_mesh: Node3D = mesh.instantiate()
	add_child(display_mesh)
	display_mesh.look_at(camera_3d.global_position)
	# Esperar a que el viewport realmente dibuje este frame
	await RenderingServer.frame_post_draw

	var image: Image = get_texture().get_image()
	var texture := ImageTexture.create_from_image(image)

	display_mesh.queue_free()
	queue_free()  # esta instancia ya cumplió su función

	return texture
