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
		var location_data = {
			"world_pos": strategic_map_position,
			"size": strategic_map_size,
			"scale_factor": scale_factor,
			"portals": {},
			"pois": {},
			"location_change_markers": {},
			"spawn_points": {}
		}
		coord_translator.register_location(location_id, location_data)

# Znajduje i rejestruje wszystkie obiekty w scenie lokacji
func find_and_register_objects():
	# Znajdź wszystkie POI
	for node in get_tree().get_nodes_in_group("poi"):
		if node is POI and is_ancestor_of(node):
			register_poi(node)
	
	# Znajdź wszystkie portale
	for node in get_tree().get_nodes_in_group("portal"):
		if node is LocationPortal and is_ancestor_of(node):
			register_portal(node)
	
	# Znajdź wszystkie markery zmiany lokacji
	for node in get_tree().get_nodes_in_group("location_change_marker"):
		if node is LocationChangeMarker and is_ancestor_of(node):
			register_location_change_marker(node)
			
	# Znajdź wszystkie punkty spawnu
	for node in get_tree().get_nodes_in_group("spawn_point"):
		if node is SpawnPoint and is_ancestor_of(node):
			register_spawn_point(node)

# Rejestruje POI
func register_poi(poi_node: POI):
	var poi_id = poi_node.poi_id
	var poi_position = poi_node.global_position
	
	pois[poi_id] = poi_node
	
	# Przelicz pozycję do trybu back
	var back_pos = coord_translator.front_to_back(location_id, poi_position)
	
	# Zaktualizuj dane w systemie tłumaczenia koordynatów
	coord_translator.register_poi(location_id, poi_id, back_pos, poi_node.poi_type)

# Rejestruje portal
func register_portal(portal_node: LocationPortal):
	var portal_id = portal_node.portal_id
	var portal_position = portal_node.global_position
	
	portals[portal_id] = portal_node
	
	# Zaktualizuj dane w systemie tłumaczenia koordynatów
	coord_translator.register_portal(
		location_id, 
		portal_id, 
		portal_position, 
		portal_node.target_location, 
		portal_node.target_portal
	)

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
