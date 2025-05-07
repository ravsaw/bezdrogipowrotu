extends Node3D
class_name FrontNPCGroup

# Settings
var group_id: String
var current_location: String
var members = []  # Array of individual NPCs
var leader_index = 0  # Index of the leader in the members array
var is_active = false

# References
var npc_scene = preload("res://scenes/npc/individual/npc.tscn")
var coord_translator: CoordTranslator
var npc_group_data  # Reference to the base group data

# Formation settings
var formation_spacing = 2.0  # Space between NPCs in formation
var formation_rows = 2
var formation_cols = 3

func initialize(base_group, spawn_position: Vector3):
	group_id = base_group.group_id
	current_location = base_group.current_location
	npc_group_data = base_group
	
	# Spawn NPCs
	spawn_group_members(spawn_position)
	
	is_active = true

func _ready():
	coord_translator = get_node("/root/World/Systems/CoordTranslator")

func _process(delta):
	if is_active:
		# Update base group leader position with the 3D leader position
		if not members.is_empty():
			var leader = members[leader_index]
			npc_group_data.leader_position = leader.global_position
		
		# Process group behavior
		process_group_behavior(delta)

# Spawn all NPCs in the group
func spawn_group_members(spawn_position: Vector3):
	# Clear existing members if any
	for member in members:
		member.queue_free()
	
	members.clear()
	
	# Determine group size (between 3-6 NPCs)
	var group_size = randi() % 4 + 3
	
	# Spawn leader
	var leader = spawn_npc(spawn_position, true)
	members.append(leader)
	leader_index = 0
	
	# Spawn followers in formation around leader
	for i in range(1, group_size):
		var row = i / formation_cols
		var col = i % formation_cols
		
		var offset = Vector3(
			(col - formation_cols/2.0) * formation_spacing,
			0,  # Same height
			row * formation_spacing  # Behind the leader
		)
		
		var member_pos = spawn_position + offset
		var member = spawn_npc(member_pos, false)
		members.append(member)

# Spawn individual NPC
func spawn_npc(position: Vector3, is_leader: bool) -> Node3D:
	var npc_instance = npc_scene.instantiate()
	add_child(npc_instance)
	
	npc_instance.global_position = position
	npc_instance.is_leader = is_leader
	
	# Set different appearance for leader vs followers
	if is_leader:
		npc_instance.setup_as_leader()
	else:
		npc_instance.setup_as_follower()
		
	return npc_instance

# Process group behavior
func process_group_behavior(delta):
	# If we have target POI in the base group, move toward it
	if not npc_group_data.target_poi.is_empty():
		var target_pos = coord_translator.get_front_poi_position(
			current_location, 
			npc_group_data.target_poi
		)
		
		move_group_to_position(target_pos, delta)
	
	# Check for nearby threats
	check_threats()
	
	# Check for nearby items/resources
	check_resources()

# Move the entire group toward a position
func move_group_to_position(target_pos: Vector3, delta):
	# First move the leader
	if members.size() > leader_index:
		var leader = members[leader_index]
		var leader_pos = leader.global_position
		
		# Calculate direction to target
		var direction = (target_pos - leader_pos).normalized()
		direction.y = 0  # Keep on ground plane
		
		# Move leader
		var speed = 3.0  # Units per second in front mode
		leader.move_in_direction(direction, speed, delta)
		
		# Move followers to follow leader in formation
		for i in range(members.size()):
			if i != leader_index:
				move_follower(i, delta)

# Move follower to maintain formation
func move_follower(follower_index: int, delta):
	if members.size() <= follower_index:
		return
		
	var follower = members[follower_index]
	var leader = members[leader_index]
	
	# Calculate desired position in formation
	var row = follower_index / formation_cols
	var col = follower_index % formation_cols
	
	# Calculate offset from leader
	var offset = Vector3(
		(col - formation_cols/2.0) * formation_spacing,
		0,
		row * formation_spacing
	)
	
	# Rotate offset based on leader's forward direction
	var leader_forward = -leader.transform.basis.z
	var angle = atan2(leader_forward.x, leader_forward.z)
	var rotated_offset = Vector3(
		offset.x * cos(angle) - offset.z * sin(angle),
		0,
		offset.x * sin(angle) + offset.z * cos(angle)
	)
	
	# Calculate target position
	var target_pos = leader.global_position + rotated_offset
	
	# Move toward target position
	var direction = (target_pos - follower.global_position).normalized()
	var speed = 3.5  # Slightly faster to catch up
	follower.move_in_direction(direction, speed, delta)

# Check for threats near the group
func check_threats():
	# This would integrate with your combat system
	pass

# Check for resources/items the group might be interested in
func check_resources():
	# This would integrate with your item/resource system
	pass

# Handle portal detection and location transition  
func handle_portal_interaction(portal_id: String):
	# Get target location and position from the portal
	var target_data = coord_translator.get_portal_target_position(current_location, portal_id)
	var new_location = target_data["location"]
	var new_position = target_data["position"]
	
	# Update the base group data
	npc_group_data.travel_to_location(new_location, new_position)
	
	# Update our own tracking
	current_location = new_location
	
	# Reposition the group
	for i in range(members.size()):
		if i == leader_index:
			members[i].global_position = new_position
		else:
			# Recalculate follower positions
			move_follower(i, 0.0)
	
# Switch to back mode (despawn)
func deactivate():
	is_active = false
	for member in members:
		member.queue_free()
	
	members.clear()
	queue_free()
