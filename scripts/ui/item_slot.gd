extends Button
class_name ItemSlot
@onready var logo: TextureRect = %logo
@onready var name_label: Label = %name_label
@onready var quantity: Label = %quantity
var timer_tied : Timer
@export var slot_resource : Item : 
	set(new):
		if new == null:
			slot_resource = new
			queue_free()
		else:
			slot_resource = new
func _initialize(resource: Item) -> void:
	slot_resource = resource
	name = resource.item_name
	if resource.icon:
		logo.texture = resource.icon
	name_label.text = resource.item_name
	quantity.text = str(resource.stack)
@onready var texture_progress_bar: TextureProgressBar = $TextureProgressBar

func _process(delta: float) -> void:
	if timer_tied:
		disabled = true
		texture_progress_bar.max_value = timer_tied.wait_time
		texture_progress_bar.value = timer_tied.time_left
	else:
		disabled = false
		timer_tied = null
		texture_progress_bar.value = 0

func _ready() -> void:
	if !slot_resource:
		queue_free()
	else:
		_initialize(slot_resource)
