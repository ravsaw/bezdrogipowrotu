extends Node3D
class_name Location

@export var location_id: String = "location1"
@export var strategic_map_position: Vector2 = Vector2(0, 0) # Position on strategic map
@export var strategic_map_size: Vector2 = Vector2(100, 100) # Size on strategic map 
@export var scale_factor: Vector2 = Vector2(10, 10) # Scaling factor front->back

# Collections of objects in location
var pois = {}

# System references
var coord_translator: CoordTranslator
var world_manager: WorldManager

func _ready():
	# Get system references
	coord_translator = get_node("/root/World/Systems/CoordTranslator")
	world_manager = get_node("/root/World")
	
	# Wait a frame to ensure systems are ready
	await get_tree().process_frame
	
	# Register this location with coordinate system
	register_with_coord_translator()
	
	# Find and collect objects
	find_and_register_objects()
	
	# Register again to make sure POIs are included
	register_with_coord_translator()

# Register location with coordinate translation system
func register_with_coord_translator():
	if coord_translator:
		# Create formatted data dictionaries
		var formatted_pois = {}
		
		print("Registering location " + location_id + " with " + str(pois.size()) + " POIs")
		
		# Convert POI nodes to expected format
		for poi_id in pois:
			var poi_node = pois[poi_id]
			var back_pos = coord_translator.front_to_back(location_id, poi_node.global_position)
			formatted_pois[poi_id] = {
				"position": back_pos,
				"type": poi_node.poi_type
			}
			
			print("Registering POI: " + poi_id + " at position " + str(back_pos))
		
		# Register with the formatted data
		var location_data = {
			"world_pos": strategic_map_position,
			"size": strategic_map_size,
			"scale_factor": scale_factor,
			"pois": formatted_pois
		}
		
		print("Location data being registered: " + str(location_data))
		coord_translator.register_location(location_id, location_data)
	else:
		push_error("No CoordTranslator found when trying to register location: " + location_id)

# Finds and collects all objects in the scene location
func find_and_register_objects():
	# Find all POIs
	print("Searching for POIs in location: " + location_id)
	var poi_nodes = get_tree().get_nodes_in_group("poi")
	print("Found " + str(poi_nodes.size()) + " POI nodes in the entire scene tree")
	
	for node in poi_nodes:
		if node is POI:
			print("Found POI: " + node.name + " with ID " + node.poi_id)
			if is_ancestor_of(node):
				print("POI " + node.poi_id + " is in this location, collecting it")
				collect_poi(node)
			else:
				print("POI " + node.poi_id + " is NOT in this location")

# Collects a POI (only adds to local dictionary)
func collect_poi(poi_node: POI):
	var poi_id = poi_node.poi_id
	pois[poi_id] = poi_node
	print("Collected POI " + poi_id + " at position " + str(poi_node.global_position))
