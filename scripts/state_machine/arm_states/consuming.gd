extends State
class_name ConsumeState

signal consumed(descript:ConsumableItemDescriptor)
signal tick_consumed(duration:float,max:float)

var consuming_descriptor: ConsumableItemDescriptor
var remaining_duration: float
var stat_enum: PlayerNeeds.Needs
var rate_per_second: float
var fully_consumed: bool = false
var cancel: bool = false

func enter(previous_state_path: String, data := {}) -> void:
	consuming_descriptor = data.get("descriptor")
	print_debug(consuming_descriptor)
	if not consuming_descriptor:
		finished.emit("normal")
		return
	cancel = false
	remaining_duration = consuming_descriptor.effect_duration
	rate_per_second = consuming_descriptor.effect_amount / consuming_descriptor.effect_duration
	fully_consumed = false

	match consuming_descriptor.consume_type:
		ConsumableItemDescriptor.ConsumeType.EAT:
			stat_enum = PlayerNeeds.Needs.HUNGER
		ConsumableItemDescriptor.ConsumeType.DRINK:
			stat_enum = PlayerNeeds.Needs.THIRST
		ConsumableItemDescriptor.ConsumeType.HEAL:
			stat_enum = PlayerNeeds.Needs.HEALTH

	
	
	while not fully_consumed and not cancel:
		var delta = get_process_delta_time()
		remaining_duration -= delta
		player.player_needs.heal(stat_enum, rate_per_second * delta)
		tick_consumed.emit(remaining_duration,consuming_descriptor.effect_duration)

		if remaining_duration <= 0.0:
			fully_consumed = true
			finished.emit("normal")
		await get_tree().process_frame
			


func handle_input(_event: InputEvent) -> void:
	if _event.is_action_pressed("cancel"):
		fully_consumed = false
		cancel = true
		finished.emit("normal")

func exit(next_state_path: String) -> void:

	if fully_consumed:
		consumed.emit(consuming_descriptor)
	else:

		consuming_descriptor.effect_amount = rate_per_second * remaining_duration
		consuming_descriptor.effect_duration = remaining_duration
		consumed.emit(null)
