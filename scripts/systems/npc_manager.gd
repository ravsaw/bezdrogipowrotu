# scripts/systems/npc_manager.gd
extends Node
class_name NPCManager

var npc_scenes = {
	"stalker": preload("res://scenes/characters/stalker_npc.tscn"),
	"bandit": preload("res://scenes/characters/bandit_npc.tscn"),
	# Add more NPC types as needed
	"default": preload("res://scenes/characters/base_npc.tscn")
}


# Collection of all NPCs in the game
var player_visibility_range: float = 150.0  # 50 meters visibility range
var all_npcs = {}       # Dictionary of NPCResource objects by ID (master data)
var npc_instances = {}  # Dictionary of 3D Node instances that are currently active/visible
var npc_containers = {} # Dictionary of container nodes for NPCs in each location
var current_location: String = ""  # Track current location
var visibility_check_timer: float = 0.0
var visibility_check_interval: float = 1.0  # Check every 3 seconds

# References
var coord_translator: CoordTranslator
var poi_manager: POIManager
var world_manager: WorldManager
var player: Player
var connector_manager: ConnectorManager

# Signals
signal npc_state_changed(npc_id, state)
signal npc_position_changed(npc_id, position)
signal npc_manager_ready
signal npc_registered
signal npcs_registered  # New signal to notify when NPCs are registered
signal npc_despawned(npc_id)

# Movement speed in strategic map coordinates per second
var npc_movement_speed: float = 5.0

func _ready():
	# Wait one frame to ensure the node is fully initialized
	await get_tree().process_frame
	
	# Get references
	coord_translator = get_node_or_null("/root/World/Systems/CoordTranslator")
	poi_manager = get_node_or_null("/root/World/Systems/POIManager")
	world_manager = get_node_or_null("/root/World")
	player = get_node_or_null("/root/World/Player")
	connector_manager = get_node_or_null("/root/World/Systems/ConnectorManager")
	
	# Notify that NPC Manager is ready
	emit_signal("npc_manager_ready")
	print("NPC Manager ready")
	current_location = world_manager.current_location_id
	
	if world_manager:
		world_manager.location_changed.connect(_on_location_changed)

# Add this function for NPCs to use connectors
func npc_choose_target_location(npc_id: String, target_location: String):
	if not all_npcs.has(npc_id):
		return
		
	var npc = all_npcs[npc_id]
	
	# Get current location of NPC
	var npc_location = coord_translator.get_location_at_position(npc.world_position)
	
	# If already in target location, just choose a POI there
	if npc_location == target_location:
		_on_npc_choose_new_target(npc_id)
		return
	
	# Find path between locations
	var connectors = connector_manager.find_path_between_locations(npc_location, target_location)
	
	if connectors.is_empty():
		print("NPC " + npc_id + " cannot find path from " + npc_location + " to " + target_location)
		return
	
	# For now, just handle direct connections
	var connector = connectors[0]
	
	# Get connector position in current location
	var target_pos = Vector2.ZERO
	if connector.location_a == npc_location:
		target_pos = connector.position_a
	else:
		target_pos = connector.position_b
	
	# Set NPC to move to connector
	npc.target_poi_id = ""  # Not moving to a POI
	npc.target_connector_id = connector.connector_id
	npc.state = "moving_to_connector"
	
	print("NPC " + npc_id + " moving to connector " + connector.connector_id + 
		 " to travel from " + npc_location + " to " + target_location)
	
	# Update target position
	npc.target_position = target_pos
	emit_signal("npc_state_changed", npc_id, "moving_to_connector")
	


func _process(delta):
	# Update NPCs in 2D mode (strategic map)
	update_npcs_movement(delta)
	
	visibility_check_timer += delta
	if visibility_check_timer >= visibility_check_interval:
		visibility_check_timer = 0.0
		if player:
			print("Performing NPC visibility check...")
			update_npc_visibility()

# Update which NPCs should be visible in 3D
func update_npc_visibility():
	if not player or not world_manager or not coord_translator:
		print("Missing references for NPC visibility check")
		return
		
	var current_location = world_manager.current_location_id

	# First, make a copy of the active_npcs keys to avoid modifying during iteration
	var active_npc_ids = npc_instances.keys()
	
	# STEP 1: Check all active NPCs to see if any should be despawned
	for npc_id in active_npc_ids:
		# Get the node instance
		var npc_instance = npc_instances[npc_id]
		
		# Check if instance is still valid
		if not is_instance_valid(npc_instance) or not npc_instance.is_inside_tree():
			print("NPC " + npc_id + " has invalid instance, removing from active_npcs")
			npc_instances.erase(npc_id)
			continue
		
		# Verify the NPC still exists in our registry
		if not all_npcs.has(npc_id):
			print("NPC " + npc_id + " no longer in all_npcs, despawning")
			npc_instance.queue_free()
			npc_instances.erase(npc_id)
			continue
		
		var npc = all_npcs[npc_id]
		
		# Check if NPC is in the current location
		var npc_location = coord_translator.get_location_at_position(npc.world_position)
		if npc_location != current_location:
			print("NPC " + npc_id + " in different location: " + npc_location + ", despawning")
			npc_instance.queue_free()
			npc_instances.erase(npc_id)
			continue
		
		# Check distance to player
		var npc_pos_3d = coord_translator.back_to_front(current_location, npc.world_position)
		var distance = player.global_position.distance_to(npc_pos_3d)
		
		if distance > player_visibility_range:
			print("NPC " + npc_id + " too far (" + str(distance) + "m), despawning")
			npc_instance.queue_free()
			npc_instances.erase(npc_id)
	
	# STEP 2: Check all NPCs to see if any should be spawned
	for npc_id in all_npcs:
		# Skip already active NPCs
		if npc_instances.has(npc_id):
			continue
			
		var npc = all_npcs[npc_id]
		
		# Check if NPC is in current location
		var npc_location = coord_translator.get_location_at_position(npc.world_position)
		if npc_location != current_location:
			continue
		
		# Calculate distance to player
		var npc_pos_3d = coord_translator.back_to_front(current_location, npc.world_position)
		var distance = player.global_position.distance_to(npc_pos_3d)
		
		# Spawn if within visibility range
		if distance <= player_visibility_range:
			print("NPC " + npc_id + " in range (" + str(distance) + "m), spawning")
			spawn_npc_3d(npc_id, current_location)
	debug_print_scene_tree()

func spawn_npc_3d(npc_id: String, location_id: String):
	# Check if NPC is already active
	if npc_instances.has(npc_id):
		if is_instance_valid(npc_instances[npc_id]) and npc_instances[npc_id].is_inside_tree():
			print("NPC " + npc_id + " is already active, not spawning")
			return
		else:
			# Instance is invalid but still in active_npcs
			npc_instances.erase(npc_id)
	
	# Check if NPC exists
	var npc = get_npc(npc_id)
	if not npc:
		print("Cannot spawn NPC " + npc_id + ": Not found in all_npcs")
		return
	
	# Get location node
	var location = world_manager.current_location
	if not location:
		print("Cannot spawn NPC " + npc_id + ": No current location")
		return
	
	# Get or create NPC container for this location
	var npc_container
	if not npc_containers.has(location_id):
		npc_container = Node3D.new()
		npc_container.name = "NPCs"
		location.add_child(npc_container)
		npc_containers[location_id] = npc_container
		print("Created new NPCs container for location " + location_id)
	else:
		npc_container = npc_containers[location_id]
		
		# Ensure the container is valid
		if not is_instance_valid(npc_container) or not npc_container.is_inside_tree():
			npc_container = Node3D.new()
			npc_container.name = "NPCs"
			location.add_child(npc_container)
			npc_containers[location_id] = npc_container
			print("Re-created NPCs container for location " + location_id)
	
	print("Spawning 3D NPC: " + npc_id)
	
	var npc_instance = create_npc_instance(npc_id)
	if npc_instance:
		# Add to container
		npc_container.add_child(npc_instance)
		npc_instances[npc_id] = npc_instance
		
		# Set position
		var npc_data = all_npcs[npc_id]
		var pos_3d = coord_translator.back_to_front(location_id, npc_data.world_position)
		npc_instance.global_position = pos_3d
		
		# If NPC was moving to a target, restore that state
		if npc_data.state == "moving":
			if npc_data.target_poi_id:
				# Get target POI in 3D
				var target_poi = poi_manager.get_poi(npc_data.target_poi_id)
				if target_poi:
					var target_pos = coord_translator.back_to_front(location_id, target_poi.world_position)
					npc_instance.set_target_position(target_pos)
		
		print("NPC " + npc_id + " is now visible in 3D at position " + str(pos_3d))
		
		# Connect to NPC signals
		npc_instance.arrived_at_target.connect(_on_npc_arrived_at_target.bind(npc_id))
		
		return npc_instance
	
	return null

# Handle NPC arrival at target
func _on_npc_arrived_at_target(npc_id: String):
	if all_npcs.has(npc_id):
		var npc_data = all_npcs[npc_id]
		
		# Update NPC state
		if npc_data.target_poi_id:
			npc_data.current_poi_id = npc_data.target_poi_id
			npc_data.target_poi_id = ""
			npc_data.state = "idle"
			emit_signal("npc_state_changed", npc_id, "idle")
			
			print("NPC " + npc_id + " arrived at POI " + npc_data.current_poi_id)
			
			# Choose new target after delay
			var timer = get_tree().create_timer(rand_range(5.0, 15.0))
			timer.timeout.connect(_on_npc_choose_new_target.bind(npc_id))
			
func _on_location_changed(new_location_id: String):
	print("Location changed to " + new_location_id + ", clearing all active NPCs")
	
	# Clear all active NPCs
	clear_all_active_npcs()
	
	# Update current location
	current_location = new_location_id
	
	# Clear npc_containers for old locations
	for loc_id in npc_containers.keys():
		if loc_id != new_location_id:
			if is_instance_valid(npc_containers[loc_id]):
				npc_containers[loc_id].queue_free()
			npc_containers.erase(loc_id)
	
	print("Cleared old location containers, remaining: " + str(npc_containers.size()))
	
func clear_all_active_npcs():
	print("Clearing all active NPCs, count: " + str(npc_instances.size()))
	
	# Create a copy of the keys to avoid modification during iteration
	var active_npc_ids = npc_instances.keys()
	
	for npc_id in active_npc_ids:
		despawn_npc_3d(npc_id)
	
	# Just to be sure, clear the dictionary
	npc_instances.clear()
	print("All active NPCs cleared")
	
# Despawn 3D representation of NPC
func despawn_npc_3d(npc_id: String):
	if npc_instances.has(npc_id):
		var npc_node = npc_instances[npc_id]
		
		# Remove from tracking dictionary first
		npc_instances.erase(npc_id)
		
		if is_instance_valid(npc_node) and npc_node.is_inside_tree():
			print("Despawning 3D NPC: " + npc_id + " - Node path: " + str(npc_node.get_path()))
			
			# Get the parent node for debugging
			var parent = npc_node.get_parent()
			if parent:
				print("  Parent node: " + parent.name)
			
			# Instead of just queue_free, forcefully remove from parent first
			if parent:
				parent.remove_child(npc_node)
			
			# Then queue_free
			npc_node.queue_free()
		else:
			print("NPC " + npc_id + " node is invalid but was in active_npcs, cleaning up")
		
		# Emit signal so locations know to remove this NPC
		emit_signal("npc_despawned", npc_id)
			
		print("Active NPCs after despawn: " + str(npc_instances.size()))
	else:
		print("Cannot despawn NPC " + npc_id + ": Not in active_npcs")
			
# Register a new NPC
func register_npc(npc_resource: NPCResource):
	all_npcs[npc_resource.npc_id] = npc_resource
	emit_signal("npc_registered", npc_resource.npc_id)
	print("Registered NPC: " + npc_resource.npc_id)

# In the register_npcs function, add:
func register_npcs(npcs_array: Array):
	for npc_resource in npcs_array:
		if npc_resource is NPCResource:
			register_npc(npc_resource)
	
	print("Registered a total of " + str(all_npcs.size()) + " NPCs")
	
	# Add this line to emit the signal
	emit_signal("npcs_registered")

# Update movement of all NPCs in 2D mode
# Update update_npcs_movement to handle connectors
func update_npcs_movement(delta):
	# Update current location
	current_location = world_manager.current_location_id
	
	for npc_id in all_npcs:
		var npc = all_npcs[npc_id]
		
		# Handle different states
		match npc.state:
			"moving":
				update_npc_moving_to_poi(npc, delta)
			"moving_to_connector":
				update_npc_moving_to_connector(npc, delta)
			"idle":
				# Idle NPCs might decide to move
				if randf() < 0.01:  # 1% chance per frame to choose new target
					_on_npc_choose_new_target(npc_id)

# Update NPC moving to POI
func update_npc_moving_to_poi(npc: NPCResource, delta: float):
	# Skip if no target
	if npc.target_poi_id.is_empty():
		npc.state = "idle"
		emit_signal("npc_state_changed", npc.npc_id, "idle")
		return
	
	# Get target POI
	var target_poi = poi_manager.get_poi(npc.target_poi_id)
	if not target_poi:
		npc.state = "idle"
		npc.target_poi_id = ""
		emit_signal("npc_state_changed", npc.npc_id, "idle")
		return
	
	# Calculate direction to target
	var direction = target_poi.world_position - npc.world_position
	var distance = direction.length()
	
	# If close enough to target, arrive
	if distance < 5.0:  # Within 5 units of POI
		npc.world_position = target_poi.world_position
		npc.current_poi_id = npc.target_poi_id
		npc.target_poi_id = ""
		npc.state = "idle"
		emit_signal("npc_state_changed", npc.npc_id, "idle")
		emit_signal("npc_position_changed", npc.npc_id, npc.world_position)
		print("NPC " + npc.npc_id + " arrived at POI " + npc.current_poi_id)
		
		# Choose new target after short delay
		var timer = get_tree().create_timer(rand_range(5.0, 15.0))
		timer.timeout.connect(_on_npc_choose_new_target.bind(npc.npc_id))
		return
	
	# Move towards target
	direction = direction.normalized()
	var movement = direction * npc_movement_speed * delta
	npc.world_position += movement
	
	# Update 3D instance if it exists
	if npc_instances.has(npc.npc_id):
		var npc_instance = npc_instances[npc.npc_id]
		
		# Validate instance before updating position
		if is_instance_valid(npc_instance) and npc_instance.is_inside_tree():
			var location_id = world_manager.current_location_id
			var pos_3d = coord_translator.back_to_front(location_id, npc.world_position)
			npc_instance.global_position = pos_3d
		else:
			# Instance is no longer valid, remove from active_npcs
			print("Removing invalid NPC instance for " + npc.npc_id + " from active_npcs")
			npc_instances.erase(npc.npc_id)
	
	emit_signal("npc_position_changed", npc.npc_id, npc.world_position)
	
func update_npc_moving_to_connector(npc: NPCResource, delta: float):
	# Skip if no target connector
	if npc.target_connector_id.is_empty():
		npc.state = "idle"
		emit_signal("npc_state_changed", npc.npc_id, "idle")
		return
	
	# Calculate direction to target position
	var direction = npc.target_position - npc.world_position
	var distance = direction.length()
	
	# If close enough to connector, travel to other location
	if distance < 5.0:  # Within 5 units of connector
		var connector = connector_manager.get_connector(npc.target_connector_id)
		if not connector:
			npc.state = "idle"
			npc.target_connector_id = ""
			emit_signal("npc_state_changed", npc.npc_id, "idle")
			return
		
		# Determine destination location
		var current_location = coord_translator.get_location_at_position(npc.world_position)
		var destination_location = connector.location_a
		if current_location == connector.location_a:
			destination_location = connector.location_b
		
		# Get destination position
		var destination_position = connector.position_a
		if current_location == connector.location_a:
			destination_position = connector.position_b
		
		# Teleport NPC to other side of connector
		npc.world_position = destination_position
		npc.target_connector_id = ""
		npc.state = "idle"
		
		emit_signal("npc_state_changed", npc.npc_id, "idle")
		emit_signal("npc_position_changed", npc.npc_id, npc.world_position)
		
		print("NPC " + npc.npc_id + " traveled from " + current_location + 
			 " to " + destination_location + " through connector " + connector.connector_id)
		
		# Choose new target in new location after delay
		var timer = get_tree().create_timer(rand_range(2.0, 5.0))
		timer.timeout.connect(_on_npc_choose_new_target.bind(npc.npc_id))
		return
	
	# Move towards connector
	direction = direction.normalized()
	var movement = direction * npc_movement_speed * delta
	npc.world_position += movement
	
	# Update 3D instance if it exists
	if npc_instances.has(npc.npc_id):
		var location_id = world_manager.current_location_id
		var pos_3d = coord_translator.back_to_front(location_id, npc.world_position)
		npc_instances[npc.npc_id].global_position = pos_3d
	
	emit_signal("npc_position_changed", npc.npc_id, npc.world_position)

# Called when an NPC should choose a new target
func _on_npc_choose_new_target(npc_id):
	if not all_npcs.has(npc_id):
		return
		
	var npc = all_npcs[npc_id]
	
	# Skip if NPC is already moving
	if npc.state == "moving":
		return
	
	# Get all active POIs
	var all_pois = poi_manager.get_all_pois()
	var active_pois = []
	
	for poi_id in all_pois:
		var poi = all_pois[poi_id]
		if poi.is_active and poi_id != npc.current_poi_id:
			active_pois.append(poi)
	
	# If no other POIs available, stay idle
	if active_pois.is_empty():
		return
	
	# Choose random POI from available ones
	var target_poi = active_pois[randi() % active_pois.size()]
	npc.target_poi_id = target_poi.poi_id
	npc.state = "moving"
	
	emit_signal("npc_state_changed", npc_id, "moving")
	print("NPC " + npc_id + " moving to POI " + npc.target_poi_id)

# Create 3D instance of NPC in the world
func create_npc_instance(npc_id: String) -> Node3D:
	
	if not all_npcs.has(npc_id):
		push_error("Cannot create NPC instance - NPC ID not found: " + npc_id)
		return null
	
	var npc_data = all_npcs[npc_id]
	
	# Get the appropriate scene based on NPC type
	var scene = npc_scenes.get(npc_data.npc_type, npc_scenes["default"])
	
	# Instantiate the scene
	var npc_instance = scene.instantiate()
	
	# Initialize with data
	var init_data = {
		"npc_id": npc_data.npc_id,
		"npc_type": npc_data.npc_type,
		"faction": npc_data.faction,
		"health": npc_data.health,
		"color": npc_data.color,
		# Add equipment if defined
		"equipment": {
			"head": "none",  # Default values
			"body": "none",
			"weapon": "none"
		}
	}
	
	# Call initialize method
	npc_instance.initialize(init_data)
	
	print("Created " + npc_data.npc_type + " NPC instance: " + npc_id)
	
	return npc_instance
	
# Remove 3D instance of NPC
func remove_npc_instance(npc_id: String):
	if npc_instances.has(npc_id):
		npc_instances[npc_id].queue_free()
		npc_instances.erase(npc_id)

# Get NPC resource
func get_npc(npc_id: String) -> NPCResource:
	if all_npcs.has(npc_id):
		return all_npcs[npc_id]
	return null

# Get all NPCs
func get_all_npcs() -> Dictionary:
	return all_npcs

# Get NPCs in a rectangle (for a location)
func get_npcs_in_rect(rect_pos: Vector2, rect_size: Vector2) -> Array:
	var result = []
	
	for npc_id in all_npcs:
		var npc = all_npcs[npc_id]
		var npc_pos = npc.world_position
		
		if (npc_pos.x >= rect_pos.x and npc_pos.x < rect_pos.x + rect_size.x and
			npc_pos.y >= rect_pos.y and npc_pos.y < rect_pos.y + rect_size.y):
			result.append(npc)
	
	return result

# Helper function
func rand_range(min_val: float, max_val: float) -> float:
	return min_val + (max_val - min_val) * randf()

func debug_print_scene_tree():
	print("=== DEBUG: NPC Scene Tree ===")
	var location = world_manager.current_location
	if location:
		var npc_container = location.get_node_or_null("NPCs")
		if npc_container:
			print("NPCs container has " + str(npc_container.get_child_count()) + " children")
			for i in range(npc_container.get_child_count()):
				var child = npc_container.get_child(i)
				print("  Child " + str(i) + ": " + child.name)
		else:
			print("No NPCs container found in location")
	else:
		print("No current location")
	print("=== END DEBUG ===")
