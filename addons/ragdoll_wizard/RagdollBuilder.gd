@tool
extends Node
class_name RagdollBuilder

# Base configurations for joint behavior. 
# These are multiplied by the 'Strength' input from the UI.
const JOINT_CONFIGS = {
	"forearm": {"type": "hinge", "min": 0, "max": 120, "softness": 0.9},
	"calf": {"type": "hinge", "min": -120, "max": 0, "softness": 0.9},
	"thigh": {"type": "6dof", "cone": 45, "twist": 20, "softness": 0.8},
	"arm": {"type": "6dof", "cone": 80, "twist": 30, "softness": 0.8},
	"spine": {"type": "6dof", "cone": 15, "twist": 10, "softness": 0.5},
	"head": {"type": "6dof", "cone": 30, "twist": 30, "softness": 0.7}
}

func build_ragdoll(skeleton: Skeleton3D, bone_map: Dictionary, total_mass: float, strength_mult: float = 1.0, fall_velocity: float = 0.0):
	if not skeleton: return
	
	# --- SCALE CHECK ---
	# Dynamically detect if this is a GMod model or a standard model
	var unit_scale = _calculate_skeleton_scale(skeleton, bone_map)
	
	# Clean up existing physical bones
	for child in skeleton.get_children():
		if child is PhysicalBoneSimulator3D:
			child.free()
			
	var simulator = PhysicalBoneSimulator3D.new()
	skeleton.add_child(simulator)
	simulator.owner = skeleton.get_tree().edited_scene_root
	simulator.active = true 

	for slot_name in bone_map.keys():
		var bone_name = bone_map[slot_name]
		if bone_name == "" or skeleton.find_bone(bone_name) == -1: continue
		
		var pb = PhysicalBone3D.new()
		pb.name = "PhysicalBone_" + bone_name
		pb.bone_name = bone_name
		
		# Set simulation mode to 'Simulated'
		if pb.has_method("set_simulation_mode"):
			pb.call("set_simulation_mode", 2) 
		else:
			pb.set("simulation_mode", 2)
		
		# PHYSICS SETUP
		pb.mass = total_mass / bone_map.size()
		# Apply fall velocity scaled by the skeleton size
		pb.linear_velocity = Vector3(0, -fall_velocity * unit_scale, 0)
		
		# Remove damping to allow floppy movement
		pb.friction = 0.3
		pb.linear_damp = 0.0
		pb.angular_damp = 0.0
		pb.can_sleep = false
		
		simulator.add_child(pb)
		pb.owner = skeleton.get_tree().edited_scene_root
		
		_setup_collision(pb, skeleton, bone_name, unit_scale)
		_apply_joint_logic(pb, slot_name.to_lower(), strength_mult)

	print("Ragdoll Wizard: Success! (Scale: ", unit_scale, ")")

func _calculate_skeleton_scale(skeleton: Skeleton3D, bone_map: Dictionary) -> float:
	var p_idx = skeleton.find_bone(bone_map.get("pelvis", ""))
	var h_idx = skeleton.find_bone(bone_map.get("head", ""))
	
	if p_idx != -1 and h_idx != -1:
		var p_pos = skeleton.get_bone_global_rest(p_idx).origin
		var h_pos = skeleton.get_bone_global_rest(h_idx).origin
		var height = p_pos.distance_to(h_pos)
		# Normalizes scale based on a roughly 1.0 unit torso
		return clamp(height, 0.1, 50.0) 
	return 1.0

func _setup_collision(pb: PhysicalBone3D, skeleton: Skeleton3D, bone_name: String, unit_scale: float):
	var collision = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	var bone_idx = skeleton.find_bone(bone_name)
	var children = skeleton.get_bone_children(bone_idx)
	
	var height = 0.2 * unit_scale
	if children.size() > 0:
		var child_pos = skeleton.get_bone_rest(children[0]).origin
		height = child_pos.length()
	
	shape.height = height * 0.95
	shape.radius = height * 0.12 # Relative radius for proper thickness
	
	collision.shape = shape
	pb.add_child(collision)
	collision.owner = pb.owner
	
	# Align capsule with the bone direction
	collision.rotation_degrees.x = 90 
	collision.position.y = height / 2

func _apply_joint_logic(pb: PhysicalBone3D, slot_name: String, strength_mult: float):
	var config = JOINT_CONFIGS["spine"]
	for key in JOINT_CONFIGS.keys():
		if key in slot_name:
			config = JOINT_CONFIGS[key]
			break
			
	if config["type"] == "hinge":
		pb.joint_type = PhysicalBone3D.JOINT_TYPE_HINGE
		pb.set("joint_constraints/angular_limit_enabled", true)
		pb.set("joint_constraints/angular_limit_upper", deg_to_rad(config["max"] * strength_mult))
		pb.set("joint_constraints/angular_limit_lower", deg_to_rad(config["min"] * strength_mult))
	else:
		pb.joint_type = PhysicalBone3D.JOINT_TYPE_6DOF
		pb.set("joint_constraints/linear_limit_enabled", false)
		pb.set("joint_constraints/angular_limit_enabled", true)
		
		var cone_limit = deg_to_rad(config["cone"] * strength_mult)
		var twist_limit = deg_to_rad(config["twist"] * strength_mult)
		
		pb.set("joint_constraints/x/angular_limit_upper", cone_limit)
		pb.set("joint_constraints/x/angular_limit_lower", -cone_limit)
		pb.set("joint_constraints/y/angular_limit_upper", cone_limit)
		pb.set("joint_constraints/y/angular_limit_lower", -cone_limit)
		pb.set("joint_constraints/z/angular_limit_upper", twist_limit)
		pb.set("joint_constraints/z/angular_limit_lower", -twist_limit)
