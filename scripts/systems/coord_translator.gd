extends Node
class_name CoordTranslator

# Dictionary to store location translation data
# Structure:
# {
#   "location1": {
#     "world_pos": Vector2(x, y),  # Position in the back mode world
#     "size": Vector2(width, height),  # Size in the back mode world
#     "portals": {
#       "portal1": {
#         "front_pos": Vector3(x, y, z),  # Position in front mode
#         "target_location": "location2",
#         "target_portal": "portal1"  # Target portal ID
#       }
#     }
#   }
# }
var location_data = {}

func _ready():
	# Initialize with example data
	_initialize_test_data()

func _initialize_test_data():
	# Example for our two test locations
	location_data = {
		"location1": {
			"world_pos": Vector2(0, 0),  # Starting position in back mode
			"size": Vector2(100, 100),   # Size in back mode (scaled down from 1000x1000)
			"scale_factor": Vector2(10, 10),  # Translation scale factor (1000/100)
			"portals": {
				"portal1": {
					"front_pos": Vector3(900, 0, 100),  # Position in front mode
					"target_location": "location2",
					"target_portal": "portal1"
				}
			},
			"pois": {
				"poi1": Vector2(25, 25),  # In back mode coords
				"poi2": Vector2(75, 25)
			}
		},
		"location2": {
			"world_pos": Vector2(150, 0),  # Starting position in back mode
			"size": Vector2(100, 100),     # Size in back mode
			"scale_factor": Vector2(10, 10),  # Translation scale factor
			"portals": {
				"portal1": {
					"front_pos": Vector3(50, 0, 50),  # Position in front mode
					"target_location": "location1",
					"target_portal": "portal1"
				}
			},
			"pois": {
				"poi1": Vector2(25, 75),  # In back mode coords
				"poi2": Vector2(75, 75)
			}
		}
	}

# Translate from front mode (3D) to back mode (2D)
func front_to_back(location_id: String, front_pos: Vector3) -> Vector2:
	# Safety check: Ensure location_id exists in our data
	if not location_data.has(location_id):
		push_error("Location ID '" + location_id + "' not found in location_data")
		return Vector2.ZERO
		
	var location = location_data[location_id]
	var scale_factor = location["scale_factor"]
	
	# Convert front position to back position
	# Ignoring Y (height) from the 3D position
	var relative_pos = Vector2(front_pos.x / scale_factor.x, front_pos.z / scale_factor.y)
	
	# Add the world position offset
	return location["world_pos"] + relative_pos

# Translate from back mode (2D) to front mode (3D)
func back_to_front(location_id: String, back_pos: Vector2) -> Vector3:
	# Safety check: Ensure location_id exists in our data
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

# Get target position when moving through a portal
func get_portal_target_position(from_location: String, portal_id: String) -> Dictionary:
	# Safety check: Ensure location exists
	if not location_data.has(from_location):
		push_error("Location ID '" + from_location + "' not found in location_data")
		return {"location": "", "position": Vector3.ZERO}
		
	# Safety check: Ensure portal exists
	if not location_data[from_location].has("portals") or not location_data[from_location]["portals"].has(portal_id):
		push_error("Portal ID '" + portal_id + "' not found in location '" + from_location + "'")
		return {"location": "", "position": Vector3.ZERO}
	
	var portal_data = location_data[from_location]["portals"][portal_id]
	var target_location = portal_data["target_location"]
	var target_portal = portal_data["target_portal"]
	
	# Safety check: Ensure target location and portal exist
	if not location_data.has(target_location) or not location_data[target_location]["portals"].has(target_portal):
		push_error("Target location/portal not found: " + target_location + "/" + target_portal)
		return {"location": target_location, "position": Vector3.ZERO}
	
	var target_pos = location_data[target_location]["portals"][target_portal]["front_pos"]
	
	return {
		"location": target_location,
		"position": target_pos
	}

# Check if a position in back mode is within a location's bounds
func is_within_location(location_id: String, back_pos: Vector2) -> bool:
	# Safety check: Ensure location exists
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

# Find which location a back mode position is in
func get_location_at_position(back_pos: Vector2) -> String:
	for location_id in location_data:
		if is_within_location(location_id, back_pos):
			return location_id
	
	return ""  # No location found
	
# Get POI positions in a location (back mode coordinates)
func get_poi_positions(location_id: String) -> Dictionary:
	# Safety check: Ensure location exists
	if not location_data.has(location_id):
		push_error("Location ID '" + location_id + "' not found in location_data")
		return {}
		
	# Safety check: Ensure location has pois
	if not location_data[location_id].has("pois"):
		push_error("No POIs found in location '" + location_id + "'")
		return {}
		
	return location_data[location_id]["pois"]
	
# Get POI positions in front mode coordinates
func get_front_poi_position(location_id: String, poi_id: String) -> Vector3:
	# Safety check: Ensure location exists
	if not location_data.has(location_id):
		push_error("Location ID '" + location_id + "' not found in location_data")
		return Vector3.ZERO
		
	# Safety check: Ensure location has pois and the specific poi exists
	if not location_data[location_id].has("pois") or not location_data[location_id]["pois"].has(poi_id):
		push_error("POI ID '" + poi_id + "' not found in location '" + location_id + "'")
		return Vector3.ZERO
	
	var back_pos = location_data[location_id]["pois"][poi_id]
	return back_to_front(location_id, back_pos)
