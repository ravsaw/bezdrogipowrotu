extends Node
class_name NPCGroup

signal mode_change_requested(group, to_front_mode, position)

# Common properties
var group_id: String
var current_location: String
var leader_position: Vector3  # 3D position in the world
var back_position: Vector2    # 2D position in back mode
var is_front_mode: bool = false
var target_poi: String = ""
var path_to_target: Array = []
var moving_between_locations: bool = false
var target_location: String = ""

# Reference to systems
var coord_translator: CoordTranslator
var alife_system

# Removed _init() method and replaced with initialize()
func initialize(id: String, location: String, start_pos: Vector2):
	group_id = id
	current_location = location
	back_position = start_pos
	leader_position = Vector3.ZERO  # Will be set properly when spawned
	return self  # Return self for chaining if needed

func _ready():
	# Get references to necessary systems
	coord_translator = get_node_or_null("/root/World/Systems/CoordTranslator")
	alife_system = get_node_or_null("/root/World/Systems/ALifeSystem")
	
	if not coord_translator:
		push_error("CoordTranslator not found in NPCGroup")
		return
		
	# Calculate initial 3D position from back position if we have the required data
	if not current_location.is_empty() and back_position != Vector2.ZERO:
		leader_position = coord_translator.back_to_front(current_location, back_position)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if not is_front_mode:
		_process_back_mode(delta)

# Update logic in back mode
func _process_back_mode(delta):
	if not target_poi.is_empty():
		_move_to_target(delta)

# Choose a new POI target
func choose_new_target():
	if not coord_translator:
		push_error("Cannot choose new target: CoordTranslator not found")
		return
		
	var pois = coord_translator.get_poi_positions(current_location)
	if pois.is_empty():
		return
		
	# Choose a different POI than current
	var poi_keys = pois.keys()
	var new_poi = poi_keys[randi() % poi_keys.size()]
	
	# If we have more than one POI, make sure we don't pick the same one
	if poi_keys.size() > 1 and new_poi == target_poi:
		poi_keys.erase(new_poi)
		new_poi = poi_keys[randi() % poi_keys.size()]
	
	target_poi = new_poi
	var target_position = pois[target_poi]
	
	# Calculate path to target
	path_to_target = _calculate_path_to(target_position)

# Simple direct path for now
func _calculate_path_to(target_pos: Vector2) -> Array:
	# In a real implementation, you would use navigation or pathfinding
	# For simplicity, we'll just return a direct path
	return [target_pos]

# Move toward current target
func _move_to_target(delta):
	if path_to_target.is_empty():
		# We reached our target
		target_poi = ""
		# Wait some time then choose a new target
		await get_tree().create_timer(randf_range(5.0, 15.0)).timeout
		choose_new_target()
		return
	
	# Move toward next point in path
	var target = path_to_target[0]
	var direction = (target - back_position).normalized()
	var move_speed = 5.0  # Units per second in back mode
	
	# Move the leader
	back_position += direction * move_speed * delta
	
	# Check if we've reached the target point
	if back_position.distance_to(target) < 1.0:
		path_to_target.pop_front()
	
	# Update 3D position
	if coord_translator:
		leader_position = coord_translator.back_to_front(current_location, back_position)

# Called when player gets close enough
func switch_to_front_mode():
	is_front_mode = true
	# Pass 'self' as the first argument to match the expected signature in ALifeSystem
	emit_signal("mode_change_requested", self, true, leader_position)

# Called when player moves far away
func switch_to_back_mode():
	is_front_mode = false
	# Pass 'self' as the first argument to match the expected signature in ALifeSystem
	emit_signal("mode_change_requested", self, false, leader_position)
	
	# Update back position from leader position
	if coord_translator:
		back_position = coord_translator.front_to_back(current_location, leader_position)

# Move to a different location through a portal
func travel_to_location(new_location: String, new_position: Vector3):
	current_location = new_location
	leader_position = new_position
	
	if coord_translator:
		back_position = coord_translator.front_to_back(current_location, leader_position)
	
	# Reset current path and target
	path_to_target.clear()
	target_poi = ""
	
	# Choose a new target in this location
	choose_new_target()
