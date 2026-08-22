extends State
class_name ConsumeState
var consuming_item : Item
@onready var timer: Timer = %Timer
signal proceed(canceled:bool)


func enter(previous_state_path: String, data := {}) -> void:
	player.ui.progress.show()
	consuming_item = data.values()[0]
	timer.start(consuming_item.time_consume)
	await timer.timeout
	if get_parent().state == self:
		if consuming_item is ItemConsumable:
			emit_signal("proceed",false)
			finished.emit("normal")
		elif consuming_item is ItemCloth:
			emit_signal("proceed",false)
			finished.emit("normal")
		else:
			emit_signal("proceed",false)
			finished.emit("normal")
		
	

func update(_delta: float) -> void:
	player.ui.progress.value = timer.time_left

func handle_input(_event: InputEvent) -> void:
	if _event.is_action_pressed("cancel"):
		emit_signal("proceed",true)
		finished.emit("normal")

func exit(next_state_path:String) -> void:
	player.ui.progress.hide()


func _on_ui_item_consumed(item: ItemConsumable) -> void:
	if item == consuming_item:
		finished.emit("normal")
