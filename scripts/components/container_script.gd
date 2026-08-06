extends Resource
class_name ContainerResource
signal added(item:Item)
signal removed(item:Item)
@export var items_inside : Array[Item] :
	set(new):
		items_inside = new
		emit_changed()

func add(item:Item) -> void:
	if !is_instance_valid(item):
		push_error("INVALID INSTANCE	")
		return
	items_inside.append(item)
	emit_signal("added",item)

func remove(item:Item) -> void:
	if !is_instance_valid(item):
		push_error("INVALID INSTANCE	")
		return
	items_inside.erase(item)
	emit_signal("removed",item)
