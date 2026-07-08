extends State
var consuming_item : ItemConsumable
@onready var timer: Timer = %Timer

func enter(previous_state_path: String, data := {}) -> void:
	player.ui.progress.show()
	consuming_item = data.values()[0]
	timer.start(consuming_item.time_consume)
	await timer.timeout
	if get_parent().state == self:
		for stat in consuming_item.stats_affected.keys():
			player.player_needs.heal(stat,consuming_item.stats_affected.get(stat))
			player.ui.remove_item(consuming_item,1)
			consuming_item = null
			finished.emit("idle")
	

func update(_delta: float) -> void:
	player.ui.progress.value = timer.time_left

func handle_input(_event: InputEvent) -> void:
	if _event.is_action_pressed("M1"):
		finished.emit("idle")

func exit(next_state_path:String) -> void:
	player.ui.progress.hide()


func _on_ui_item_consumed(item: ItemConsumable) -> void:
	if item == consuming_item:
		finished.emit("idle")
