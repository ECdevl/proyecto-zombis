extends Resource
class_name Interactable


@export var use_key : StringName = &"use"
@export var text_hint : String = "to interact"

func get_ui_hint() -> String:
	if InputMap.has_action(use_key):
		var events = InputMap.action_get_events(use_key)
		for event in events:
			if event is InputEvent:
				return "Press "+event.as_text()+" "+text_hint
	return "Press "+"Key not bound"+" "+text_hint
