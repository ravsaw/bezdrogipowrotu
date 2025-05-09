# scripts/systems/connector_manager.gd
extends Node
class_name ConnectorManager

# Collection of all connectors
var all_connectors = {}  # Dictionary of LocationConnectorResource by ID

# Signals
signal connector_state_changed(connector_id, is_active)
signal connector_manager_ready

# References
var coord_translator: CoordTranslator

func _ready():
	# Wait one frame to ensure the node is fully initialized
	await get_tree().process_frame
	
	# Get references
	coord_translator = get_node_or_null("/root/World/Systems/CoordTranslator")
	
	# Notify that Connector Manager is ready
	emit_signal("manager_ready")
	print("Connector Manager ready")

# Register a connector from scene
func register_scene_connectors(connectors_array: Array):
	print("Registering connector data...")
	
	for connector_data in connectors_array:
		if connector_data is Dictionary:
			var connector = LocationConnectorResource.new()
			connector.connector_id = connector_data["connector_id"]
			connector.location_a = connector_data["location_a"]
			connector.location_b = connector_data["location_b"]
			connector.position_a = connector_data["position_a"]
			connector.position_b = connector_data["position_b"]
			connector.is_active = connector_data["is_active"]
			
			all_connectors[connector.connector_id] = connector
			print("Registered connector: " + connector.connector_id + 
				" connecting " + connector.location_a + " and " + connector.location_b)
	
	print("Registered a total of " + str(all_connectors.size()) + " connectors")

# Get connector by ID
func get_connector(connector_id: String) -> LocationConnectorResource:
	if all_connectors.has(connector_id):
		return all_connectors[connector_id]
	return null

# Get all connectors for a location
func get_connectors_for_location(location_id: String) -> Array:
	var result = []
	
	for connector_id in all_connectors:
		var connector = all_connectors[connector_id]
		if (connector.location_a == location_id or connector.location_b == location_id) and connector.is_active:
			result.append(connector)
	
	return result

# Find path between locations
func find_path_between_locations(from_location: String, to_location: String) -> Array:
	# If same location, no path needed
	if from_location == to_location:
		return []
		
	# Direct connection
	for connector_id in all_connectors:
		var connector = all_connectors[connector_id]
		if not connector.is_active:
			continue
			
		if (connector.location_a == from_location and connector.location_b == to_location) or (connector.location_b == from_location and connector.location_a == to_location):
			return [connector]
	
	# TODO: Implement more complex pathfinding between multiple locations
	# For now, return empty array if no direct connection
	return []

# Set connector active state
func set_connector_active(connector_id: String, active: bool):
	if all_connectors.has(connector_id):
		var connector = all_connectors[connector_id]
		if connector.is_active != active:
			connector.is_active = active
			emit_signal("connector_state_changed", connector_id, active)
