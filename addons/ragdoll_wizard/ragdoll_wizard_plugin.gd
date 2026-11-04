@tool
extends EditorPlugin

var wizard_panel_scene = preload("res://addons/ragdoll_wizard/ragdoll_wizard_panel.tscn")
var wizard_panel_instance

func _enter_tree():
	# This adds the wizard as a tab in the bottom panel (near Output/Debugger)
	wizard_panel_instance = wizard_panel_scene.instantiate()
	add_control_to_bottom_panel(wizard_panel_instance, "Ragdoll Wizard")

func _exit_tree():
	# Cleanup when the plugin is disabled
	if wizard_panel_instance:
		remove_control_from_bottom_panel(wizard_panel_instance)
		wizard_panel_instance.queue_free()
