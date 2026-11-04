@tool
extends Control

@onready var bone_tree = $BoneTree
@onready var skeleton_name_label = $ScrollContainer/VBoxContainer/SkeletonSelect/SkeletonName
@onready var bone_slots_container = $ScrollContainer/VBoxContainer/BoneSlots
@onready var total_mass_input_box: LineEdit = $ScrollContainer/VBoxContainer/BoneSlots/TotalMassInputBox

var current_skeleton: Skeleton3D = null

func _ready():
	if Engine.is_editor_hint():
		# FIX: Ensure the signal name matches the function name exactly
		var sel = EditorInterface.get_selection()
		if not sel.selection_changed.is_connected(_on_selection_changed):
			sel.selection_changed.connect(_on_selection_changed)
		
		# SET UP DRAG FORWARDING
		# We use get_drag_data_fw, can_drop_data_fw, and drop_data_fw
		for slot in bone_slots_container.get_children():
			if slot is LineEdit:
				slot.set_drag_forwarding(Callable(), _can_drop_data_fw, _drop_data_fw)

# FIX: Renamed to match the connection in _ready()
func _on_selection_changed():
	var selected_nodes = EditorInterface.get_selection().get_selected_nodes()
	if selected_nodes.size() > 0 and selected_nodes[0] is Skeleton3D:
		_set_skeleton(selected_nodes[0])

func _set_skeleton(skeleton: Skeleton3D):
	current_skeleton = skeleton
	if skeleton_name_label:
		skeleton_name_label.text = "Active: " + skeleton.name
	_update_bone_tree()

func _update_bone_tree():
	bone_tree.clear()
	if not current_skeleton: return
	
	var root = bone_tree.create_item()
	bone_tree.set_hide_root(true)
	
	var items = {}
	for i in current_skeleton.get_bone_count():
		var bone_name = current_skeleton.get_bone_name(i)
		var parent_idx = current_skeleton.get_bone_parent(i)
		
		var parent_item = root
		if parent_idx != -1:
			var parent_name = current_skeleton.get_bone_name(parent_idx)
			if items.has(parent_name):
				parent_item = items[parent_name]
		
		var item = bone_tree.create_item(parent_item)
		item.set_text(0, bone_name)
		item.set_metadata(0, bone_name)
		items[bone_name] = item

# --- Drag & Drop Fixes ---

func _get_drag_data(at_position):
	var selected = bone_tree.get_selected()
	if not selected: return null
	
	var bone_name = selected.get_metadata(0)
	var preview = Label.new()
	preview.text = bone_name
	set_drag_preview(preview)
	
	return {"type": "bone_name", "value": bone_name}

func _can_drop_data_fw(at_position, data):
	return typeof(data) == TYPE_DICTIONARY and data.get("type") == "bone_name"

func _drop_data_fw(at_position, data):
	# Find which LineEdit is currently under the mouse
	var mouse_pos = get_global_mouse_position()
	for slot in bone_slots_container.get_children():
		if slot is LineEdit and slot.get_global_rect().has_point(mouse_pos):
			slot.text = data["value"]
			return

func _on_copy_button_pressed(): # Connect this to a "Copy" button if you add one
	var selected = bone_tree.get_selected()
	if selected:
		DisplayServer.clipboard_set(selected.get_metadata(0))
		print("Bone name copied to clipboard!")

func _on_clear_slots_pressed():
	for child in bone_slots_container.get_children():
		if child is LineEdit:
			child.text = ""

func _on_create_button_pressed():
	var builder = get_tree().edited_scene_root.find_child("RagdollBuilder", true, false)
	if not builder:
		printerr("Add a RagdollBuilder node to your scene first!")
		return

	# Gather bone map from LineEdits
	var bone_map = {
		"pelvis": $ScrollContainer/VBoxContainer/BoneSlots/PelvisBoneSlot.text,
		"head": $ScrollContainer/VBoxContainer/BoneSlots/HeadBoneSlot.text, # New Head slot
		"left arm": $ScrollContainer/VBoxContainer/BoneSlots/leftArmBoneSlot.text,
		"left elbow" : $ScrollContainer/VBoxContainer/BoneSlots/leftElbowBoneSlot.text,
		"right arm" : $ScrollContainer/VBoxContainer/BoneSlots/RightArmBoneSlot.text,
		"right elbow" : $ScrollContainer/VBoxContainer/BoneSlots/RightElbowBoneSlot.text,
		"left hips" : $ScrollContainer/VBoxContainer/BoneSlots/leftHipsBoneSlot.text,
		"left knee" : $ScrollContainer/VBoxContainer/BoneSlots/leftkneeBoneSlot.text,
		"left foot" : $ScrollContainer/VBoxContainer/BoneSlots/leftFootBoneSlot.text,
		"right hips" : $ScrollContainer/VBoxContainer/BoneSlots/RightHipsBoneSlot.text,
		"right knee" : $ScrollContainer/VBoxContainer/BoneSlots/RightKneeBoneSlot.text,
		"right foot" : $ScrollContainer/VBoxContainer/BoneSlots/RightFootBoneSlot.text,
		"middle spine" : $ScrollContainer/VBoxContainer/BoneSlots/MiddleSpineBoneSlot.text
	}

	# Convert UI text to numbers
	var mass = float($ScrollContainer/VBoxContainer/BoneSlots/TotalMassInputBox.text)
	var strength = float($ScrollContainer/VBoxContainer/BoneSlots/StrengthInputBox.text)
	var fall_v = float($ScrollContainer/VBoxContainer/BoneSlots/FallVelocityInputBox.text)
	# Default values if input is empty
	if mass <= 0: mass = 70.0
	if strength <= 0: strength = 1.0
	if fall_v <= 0: fall_v = 0.0

	builder.build_ragdoll(current_skeleton, bone_map, mass, strength)
