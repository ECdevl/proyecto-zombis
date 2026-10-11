extends PlayerState
class_name ConsumeState

signal consumed(item: ItemInstance)  # null si se canceló
signal tick_consumed(duration: float, max_duration: float)

var item: ItemInstance
var descriptor: ConsumableItemDescriptor
var remaining_duration: float
var stat_enum: PlayerNeeds.Needs
var rate_per_second: float
var fully_consumed: bool = false
var cancel: bool = false


func enter(_previous_state_path: String, data := {}) -> void:
	item = data.get("item")
	descriptor = null
	if item:
		descriptor = item.descriptor as ConsumableItemDescriptor
	if descriptor == null:
		finished.emit("normal")
		return
	cancel = false
	fully_consumed = false
	remaining_duration = descriptor.effect_duration * item.remaining_ratio
	rate_per_second = descriptor.effect_amount / descriptor.effect_duration

	match descriptor.consume_type:
		ConsumableItemDescriptor.ConsumeType.EAT:
			stat_enum = PlayerNeeds.Needs.HUNGER
		ConsumableItemDescriptor.ConsumeType.DRINK:
			stat_enum = PlayerNeeds.Needs.THIRST
		ConsumableItemDescriptor.ConsumeType.HEAL:
			stat_enum = PlayerNeeds.Needs.HEALTH

	while not fully_consumed and not cancel:
		var delta := get_process_delta_time()
		remaining_duration -= delta
		player.player_needs.heal(stat_enum, rate_per_second * delta)
		tick_consumed.emit(remaining_duration, descriptor.effect_duration)
		if remaining_duration <= 0.0:
			fully_consumed = true
			finished.emit("normal")
		await get_tree().process_frame


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel"):
		cancel = true
		finished.emit("normal")


func exit(_next_state_path: String) -> void:
	if item == null:
		consumed.emit(null)
	elif fully_consumed:
		consumed.emit(item)
	else:
		# Se guarda en ESTE objeto (no en el descriptor compartido) lo que falta.
		item.remaining_ratio = remaining_duration / descriptor.effect_duration
		consumed.emit(null)
