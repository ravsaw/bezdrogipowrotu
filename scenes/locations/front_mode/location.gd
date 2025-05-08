# scenes/locations/front_mode/location.gd
extends Node3D
class_name Location

@export var location_id: String = "location1"
@export var strategic_map_position: Vector2 = Vector2(0, 0) # Pozycja na mapie strategicznej
@export var strategic_map_size: Vector2 = Vector2(100, 100) # Rozmiar na mapie strategicznej
@export var scale_factor: Vector2 = Vector2(10, 10) # Współczynnik skalowania front->back

# Kolekcje obiektów w lokacji
var pois = {}
var portals = {}
var location_change_markers = {}
var spawn_points = {}

# Referencje do systemu
var coord_translator: CoordTranslator
var world_manager: WorldManager

func _ready():
	# Pobierz referencje do systemów
	coord_translator = get_node("/root/World/Systems/CoordTranslator")
	world_manager = get_node("/root/World")
	
	# Zarejestruj tę lokację w systemie koordynatów
	register_with_coord_translator()
	
	find_and_register_objects()

# Rejestruje lokację w systemie tłumaczenia koordynatów
func register_with_coord_translator():
	if coord_translator:
		# Create formatted data dictionaries
		var formatted_pois = {}
		var formatted_portals = {}
		var formatted_markers = {}
		var formatted_spawns = {}
		
		# Convert POI nodes to expected format
		for poi_id in pois:
			var poi_node = pois[poi_id]
			var back_pos = coord_translator.front_to_back(location_id, poi_node.global_position)
			formatted_pois[poi_id] = {
				"position": back_pos,
				"type": poi_node.poi_type
			}
		
		# Convert portal nodes to expected format
		for portal_id in portals:
			var portal_node = portals[portal_id]
			formatted_portals[portal_id] = {
				"front_pos": portal_node.global_position,
				"target_location": portal_node.target_location,
				"target_portal": portal_node.target_portal
			}
		
		# Convert location change markers to expected format
		for marker_id in location_change_markers:
			var marker_node = location_change_markers[marker_id]
			var back_pos = coord_translator.front_to_back(location_id, marker_node.global_position)
			formatted_markers[marker_id] = {
				"position": back_pos,
				"target_location": marker_node.target_location,
				"spawn_point_id": marker_node.spawn_point_id
			}
		
		# Convert spawn points to expected format
		for spawn_id in spawn_points:
			var spawn_node = spawn_points[spawn_id]
			formatted_spawns[spawn_id] = spawn_node.global_position
		
		# Register with the formatted data
		var location_data = {
			"world_pos": strategic_map_position,
			"size": strategic_map_size,
			"scale_factor": scale_factor,
			"portals": formatted_portals,
			"pois": formatted_pois,
			"location_change_markers": formatted_markers,
			"spawn_points": formatted_spawns
		}
		
		coord_translator.register_location(location_id, location_data)

# Finds and collects all objects in the scene location
func find_and_register_objects():
	# Find all POIs
	for node in get_tree().get_nodes_in_group("poi"):
		if node is POI and is_ancestor_of(node):
			collect_poi(node)
	
	# Find all portals
	for node in get_tree().get_nodes_in_group("portal"):
		if node is LocationPortal and is_ancestor_of(node):
			collect_portal(node)
	
	# Find all location change markers
	for node in get_tree().get_nodes_in_group("location_change_marker"):
		if node is LocationChangeMarker and is_ancestor_of(node):
			collect_location_change_marker(node)
			
	# Find all spawn points
	for node in get_tree().get_nodes_in_group("spawn_point"):
		if node is SpawnPoint and is_ancestor_of(node):
			collect_spawn_point(node)

# Collects a POI (only adds to local dictionary)
func collect_poi(poi_node: POI):
	var poi_id = poi_node.poi_id
	pois[poi_id] = poi_node

func collect_portal(portal_node: POI):
	var portal_id = portal_node.poi_id
	portals[portal_id] = portal_node

func collect_location_change_marker(marker_node: POI):
	var marker_id = marker_node.poi_id
	location_change_markers[marker_id] = marker_node

func collect_spawn_point(spawn_node: POI):
	var spawn_id = spawn_node.poi_id
	spawn_points[spawn_id] = spawn_node

# Rejestruje marker zmiany lokacji dla NPC
func register_location_change_marker(marker: LocationChangeMarker):
	var marker_id = marker.name
	var marker_position = marker.global_position
	
	location_change_markers[marker_id] = marker
	
	# Przelicz pozycję do trybu back
	var back_pos = coord_translator.front_to_back(location_id, marker_position)
	
	# Zaktualizuj dane w systemie tłumaczenia koordynatów
	coord_translator.register_location_change_marker(
		location_id,
		marker_id,
		back_pos,
		marker.target_location,
		marker.spawn_point_id
	)

# Rejestruje punkt spawnu
func register_spawn_point(spawn_point: SpawnPoint):
	var spawn_id = spawn_point.spawn_id
	var spawn_position = spawn_point.global_position
	
	spawn_points[spawn_id] = spawn_point
	
	# Zaktualizuj dane w systemie tłumaczenia koordynatów
	coord_translator.register_spawn_point(location_id, spawn_id, spawn_position)
