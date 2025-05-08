extends Node
class_name CoordTranslator

# Dictionary to store location data
var location_data = {}

func _ready():
	# Initialize empty dictionary - will be filled by locations
	location_data = {}

# Register a location with its data
func register_location(location_id: String, data: Dictionary):
	# Add location data to our dictionary
	location_data[location_id] = data
	print("Registered location: " + location_id + " with " + str(data.get("pois", {}).size()) + " POIs")
	print("POI keys: " + str(data.get("pois", {}).keys()))

# Register a POI
func register_poi(location_id: String, poi_id: String, back_pos: Vector2, poi_type: String = "generic"):
	# Make sure location exists
	if not location_data.has(location_id):
		push_error("Location ID '" + location_id + "' not found in location_data")
		return
		
	# Make sure POIs dictionary exists
	if not location_data[location_id].has("pois"):
		location_data[location_id]["pois"] = {}
	
	# Add POI to location data
	location_data[location_id]["pois"][poi_id] = {
		"position": back_pos,
		"type": poi_type
	}

# Translate from front mode (3D) to back mode (2D)
func front_to_back(location_id: String, front_pos: Vector3) -> Vector2:
	# Safety check: Make sure location_id exists in our data
	if not location_data.has(location_id):
		push_error("Location ID '" + location_id + "' not found in location_data")
		return Vector2.ZERO
		
	var location = location_data[location_id]
	var scale_factor = location["scale_factor"]
	
	# Convert front position to back position
	# Ignore Y (height) from 3D position
	var relative_pos = Vector2(front_pos.x / scale_factor.x, front_pos.z / scale_factor.y)
	
	# Add strategic map position offset
	return location["world_pos"] + relative_pos

# Translate from back mode (2D) to front mode (3D) 
func back_to_front(location_id: String, back_pos: Vector2) -> Vector3:
	# Safety check: Make sure location_id exists in our data
	if not location_data.has(location_id):
		push_error("Location ID '" + location_id + "' not found in location_data")
		return Vector3(0, 2, 0)
		
	var location = location_data[location_id]
	var scale_factor = location["scale_factor"]
	
	# Get local coordinates in back mode
	var local_back_pos = back_pos - location["world_pos"]
	
	# Convert to front mode coordinates
	# Y (height) is set to 0, but should be adjusted based on terrain
	return Vector3(
		local_back_pos.x * scale_factor.x,
		0,  # Ground level, should be adjusted based on terrain height
		local_back_pos.y * scale_factor.y
	)

# Check if a back mode position is within a location's bounds
func is_within_location(location_id: String, back_pos: Vector2) -> bool:
	# Safety check: Make sure location exists
	if not location_data.has(location_id):
		push_error("Location ID '" + location_id + "' not found in location_data")
		return false
		
	var location = location_data[location_id]
	var local_pos = back_pos - location["world_pos"]
	
	return (
		local_pos.x >= 0 and 
		local_pos.x < location["size"].x and 
		local_pos.y >= 0 and 
		local_pos.y < location["size"].y
	)

# Find which location contains a back mode position
func get_location_at_position(back_pos: Vector2) -> String:
	for location_id in location_data:
		if is_within_location(location_id, back_pos):
			return location_id
	
	return ""  # No location found

# Get POI positions in a location (back mode coordinates)
func get_poi_positions(location_id: String) -> Dictionary:
	# Safety check: Make sure location exists
	if not location_data.has(location_id):
		push_error("Location ID '" + location_id + "' not found in location_data")
		return {}
		
	# Safety check: Make sure location has POIs
	if not location_data[location_id].has("pois"):
		push_error("No POIs found in location '" + location_id + "'")
		return {}
	
	# Convert POI structure to format with just positions (for compatibility)
	var result = {}
	for poi_id in location_data[location_id]["pois"]:
		result[poi_id] = location_data[location_id]["pois"][poi_id]["position"]
		
	return result

# Get POI position in front mode coordinates
func get_front_poi_position(location_id: String, poi_id: String) -> Vector3:
	# Safety check: Make sure location exists
	if not location_data.has(location_id):
		push_error("Location ID '" + location_id + "' not found in location_data")
		return Vector3.ZERO
		
	# Safety check: Make sure location has POIs and this specific POI exists
	if not location_data[location_id].has("pois") or not location_data[location_id]["pois"].has(poi_id):
		push_error("POI ID '" + poi_id + "' not found in location '" + location_id + "'")
		return Vector3.ZERO
	
	var back_pos = location_data[location_id]["pois"][poi_id]["position"]
	return back_to_front(location_id, back_pos)
