extends Node
class_name ALifeSystem

# Settings
var front_distance_threshold = 100.0  # Distance at which NPCs switch to front mode
var back_distance_threshold = 150.0   # Distance at which NPCs switch to back mode
var simulation_tick_time = 1.0        # Seconds between simulation updates in back mode
var simulation_timer = 0.0

# References
var coord_translator: CoordTranslator
var player
var current_location: String = "location1"
var initialized = false

# Scenes
var npc_group_scene = preload("res://scenes/npc/group/npc_group.tscn")
var front_npc_group_scene = preload("res://scenes/npc/group/front_npc_group.tscn")
var back_npc_group_scene = preload("res://scenes/npc/group/back_npc_group.tscn")

# Collections
var npc_groups = {}  # Dictionary of all NPC groups by ID
var active_front_groups = {}  # Dictionary of active 3D groups
var active_back_groups = {}   # Dictionary of active 2D groups

# Containers for organizing scene tree
var front_groups_container: Node3D
var back_groups_container: Node2D

func _ready():
	# Set up references for the coordinator
	coord_translator = get_node_or_null("/root/World/Systems/CoordTranslator")
	if not coord_translator:
		push_error("Warning: CoordTranslator not found, will try to initialize later")
	
	# Create containers
	front_groups_container = Node3D.new()
	front_groups_container.name = "FrontGroups"
	add_child(front_groups_container)
	
	back_groups_container = Node2D.new()
	back_groups_container.name = "BackGroups"
	add_child(back_groups_container)
	
	# We'll initialize the rest when the player is available and we get initialize() called

# Call this method from the World script after the player is created
func initialize(player_node):
	player = player_node
	initialized = true
	
	# Now get the references that might not have been available in _ready()
	if not coord_translator:
		coord_translator = get_node_or_null("/root/World/Systems/CoordTranslator")
		if not coord_translator:
			push_error("Failed to find CoordTranslator node, A-Life system will not function correctly")
			return
	
	# Initialize test groups
	_initialize_test_groups()
	
	# Initial processing to set up groups correctly
	_process_mode_switches()
	
	print("A-Life system initialized successfully")

func _process(delta):
	# Skip processing if not initialized
	if not initialized:
		return
		
	# Update simulation timer
	simulation_timer += delta
	
	# Run simulation tick for back mode
	if simulation_timer >= simulation_tick_time:
		simulation_timer = 0.0
		_simulation_tick()
	
	# Process switches between front and back mode
	_process_mode_switches()

# Create initial test groups
func _initialize_test_groups():
	# Create a test group in each location
	_create_npc_group("group1", "location1", Vector2(25, 25))
	_create_npc_group("group2", "location2", Vector2(75, 75))

# Create a new NPC group
func _create_npc_group(id: String, location: String, position: Vector2):
	# Create base data group
	var new_group = npc_group_scene.instantiate()
	add_child(new_group)
	
	# Initialize with data using initialize() instead of _init()
	new_group.initialize(id, location, position)
	
	# Connect signals
	new_group.mode_change_requested.connect(_on_group_mode_change_requested)
	
	# Add to collection
	npc_groups[id] = new_group
	
	# Choose initial target for the group
	new_group.choose_new_target()
	
	# Create back mode representation
	_spawn_back_group(new_group)

# Simulate a tick for all back mode groups
func _simulation_tick():
	# This is where simulation updates happen for groups in back mode
	for group_id in npc_groups:
		var group = npc_groups[group_id]
		
		# Only process for groups in back mode
		if not group.is_front_mode:
			# Maybe change the target sometimes
			if randf() < 0.05:  # 5% chance each tick
				group.choose_new_target()

# Process switches between front and back mode based on distance to player
func _process_mode_switches():
	# Ensure player exists
	if not player:
		return
		
	# Get player position and convert to back mode for comparison
	var player_pos = player.global_position
	var player_back_pos = coord_translator.front_to_back(current_location, player_pos)
	
	# Check each group
	for group_id in npc_groups:
		var group = npc_groups[group_id]
		
		# Skip groups not in the current location
		if group.current_location != current_location:
			# Ensure they're in back mode
			if group.is_front_mode:
				group.switch_to_back_mode()
				_despawn_front_group(group_id)
				_spawn_back_group(group)
			continue
		
		# Calculate distance in back mode (2D strategic map)
		var distance = player_back_pos.distance_to(group.back_position)
		
		# Switch to front mode if close enough
		if not group.is_front_mode and distance < front_distance_threshold:
			group.switch_to_front_mode()
			_spawn_front_group(group)
			_despawn_back_group(group_id)
		
		# Switch to back mode if far enough
		elif group.is_front_mode and distance > back_distance_threshold:
			group.switch_to_back_mode()
			_despawn_front_group(group_id)
			_spawn_back_group(group)

# Spawn a 3D representation of the group
func _spawn_front_group(group):
	# Skip if already spawned
	if group.group_id in active_front_groups:
		return
		
	# Create front mode group
	var front_group = front_npc_group_scene.instantiate()
	front_groups_container.add_child(front_group)
	
	# Initialize with data
	front_group.initialize(group, group.leader_position)
	
	# Add to active groups
	active_front_groups[group.group_id] = front_group

# Despawn a 3D representation
func _despawn_front_group(group_id):
	if group_id in active_front_groups:
		var front_group = active_front_groups[group_id]
		front_group.deactivate()  # This will queue_free()
		active_front_groups.erase(group_id)

# Spawn a 2D representation of the group
func _spawn_back_group(group):
	# Skip if already spawned
	if group.group_id in active_back_groups:
		return
		
	# Create back mode group
	var back_group = back_npc_group_scene.instantiate()
	back_groups_container.add_child(back_group)
	
	# Initialize with data
	back_group.initialize(group)
	
	# Add to active groups
	active_back_groups[group.group_id] = back_group

# Despawn a 2D representation
func _despawn_back_group(group_id):
	if group_id in active_back_groups:
		var back_group = active_back_groups[group_id]
		back_group.activate()  # This will queue_free()
		active_back_groups.erase(group_id)

# Signal handler for when a group requests mode change
func _on_group_mode_change_requested(group, to_front_mode, position):
	var group_id = group.group_id
	
	if to_front_mode:
		_spawn_front_group(group)
		_despawn_back_group(group_id)
	else:
		_despawn_front_group(group_id)
		_spawn_back_group(group)

# Set the current player location
func set_player_location(location_id: String):
	current_location = location_id
	
	# Force process mode switches after location change
	_process_mode_switches()

# Handle portal traversals for groups
func handle_group_portal_traversal(group_id: String, portal_id: String):
	if group_id in npc_groups:
		var group = npc_groups[group_id]
		
		# Get portal target data
		var target_data = coord_translator.get_portal_target_position(
			group.current_location, portal_id
		)
		
		# Update group location
		group.travel_to_location(
			target_data["location"],
			target_data["position"]
		)
		
		# Force mode processing
		_process_mode_switches()

# Get all active groups in a location
func get_active_groups_in_location(location_id: String) -> Array:
	var result = []
	
	for group_id in npc_groups:
		var group = npc_groups[group_id]
		if group.current_location == location_id:
			result.append(group)
	
	return result

# Add a new group to the simulation
func add_npc_group(id: String, location: String, position: Vector2):
	_create_npc_group(id, location, position)

# Remove a group from the simulation
func remove_npc_group(group_id: String):
	if group_id in npc_groups:
		# Despawn visual representations
		if group_id in active_front_groups:
			_despawn_front_group(group_id)
		
		if group_id in active_back_groups:
			_despawn_back_group(group_id)
		
		# Remove base group
		npc_groups[group_id].queue_free()
		npc_groups.erase(group_id)
