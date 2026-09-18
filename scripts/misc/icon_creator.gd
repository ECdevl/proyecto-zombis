extends SubViewport
@onready var camera_3d: Camera3D = $Camera3D

func create_texture(mesh: PackedScene) -> ImageTexture:
	render_target_update_mode = SubViewport.UPDATE_ONCE
	var display_mesh: Node3D = mesh.instantiate()
	add_child(display_mesh)

	# AABB combinado de todos los MeshInstance3D hijos
	var aabb := _get_combined_aabb(display_mesh)
	var center := aabb.get_center()
	display_mesh.global_position -= center

	# Ajustar cámara según tamaño del modelo
	var radius := aabb.get_longest_axis_size() * 0.5
	camera_3d.global_position = Vector3(0, 0, radius * 2.5)
	camera_3d.look_at(Vector3.ZERO)

	await RenderingServer.frame_post_draw
	var image: Image = get_texture().get_image()
	var texture := ImageTexture.create_from_image(image)
	display_mesh.queue_free()
	queue_free()
	return texture

func _get_combined_aabb(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for child in node.get_children():
		if child is VisualInstance3D:
			var box: AABB = child.get_aabb()
			box = child.transform * box
			if first:
				result = box
				first = false
			else:
				result = result.merge(box)
		if child is Node3D:
			var sub := _get_combined_aabb(child)
			if sub.size != Vector3.ZERO:
				if first:
					result = sub
					first = false
				else:
					result = result.merge(sub)
	return result
