extends Control
class_name StrategicMap

# References
var coord_translator: CoordTranslator
var alife_system
var player

# UI elements
var map_container: Panel
var location_rects = {}
var player_marker: ColorRect
var path_container: Node2D
var navigation_container: Node2D

func _ready():
	# Get system references
	coord_translator = get_node("/root/World/Systems/CoordTranslator")
	alife_system = get_node("/root/World/Systems/ALifeSystem")
	player = get_node("/root/World/Player")
	
	# Setup layout
	setup_ui()
	
	# Setup locations
	setup_locations()
	
	# Create player marker
	setup_player_marker()
	
	# Setup paths between locations
	setup_paths()
	
	# Przygotuj nawigację dla NPC
	setup_navigation()

	
func _process(_delta):
	# Update player position on the map
	update_player_position()

# Przygotowuje nawigację dla NPC
func setup_navigation():
	# Utwórz kontener dla nawigacji
	navigation_container = Node2D.new()
	add_child(navigation_container)
	
	# Utwórz główny region nawigacji
	var nav_region = NavigationRegion2D.new()
	navigation_container.add_child(nav_region)
	
	# Utwórz siatkę nawigacji
	var nav_poly = NavigationPolygon.new()
	
	# Dodaj węzły dla każdej lokacji
	for location_id in coord_translator.location_data:
		var location = coord_translator.location_data[location_id]
		var world_pos = location["world_pos"]
		var size = location["size"]
		
		# Dodaj obszar lokacji jako dozwolony teren
		var outline = PackedVector2Array([
			world_pos,
			world_pos + Vector2(size.x, 0),
			world_pos + size,
			world_pos + Vector2(0, size.y)
		])
		nav_poly.add_outline(outline)
	
	# Dodaj ścieżki między lokacjami
	for from_id in coord_translator.location_data:
		var from_location = coord_translator.location_data[from_id]
		
		# Sprawdź połączenia portalowe
		for portal_id in from_location.get("portals", {}):
			var portal = from_location["portals"][portal_id]
			var to_id = portal["target_location"]
			
			# Utwórz ścieżkę nawigacji między lokacjami
			create_navigation_path(from_id, to_id)
	
	# Finalizuj siatkę nawigacji
	nav_poly.make_polygons_from_outlines()
	nav_region.navigation_polygon = nav_poly

# Tworzy ścieżkę nawigacji między dwoma lokacjami
func create_navigation_path(from_id: String, to_id: String):
	var from_location = coord_translator.location_data[from_id]
	var to_location = coord_translator.location_data[to_id]
	
	# Oblicz środki lokacji
	var from_center = from_location["world_pos"] + from_location["size"] / 2
	var to_center = to_location["world_pos"] + to_location["size"] / 2
	
	# Szerokość ścieżki
	var path_width = 10.0
	
	# Oblicz kierunek i normalną ścieżki
	var direction = (to_center - from_center).normalized()
	var normal = Vector2(-direction.y, direction.x)
	
	# Utwórz wielokąt ścieżki
	var path_poly = NavigationPolygon.new()
	var outline = PackedVector2Array([
		from_center + normal * path_width/2,
		from_center - normal * path_width/2,
		to_center - normal * path_width/2,
		to_center + normal * path_width/2
	])
	path_poly.add_outline(outline)
	path_poly.make_polygons_from_outlines()
	
	# Dodaj ścieżkę do regionu nawigacji
	var path_region = NavigationRegion2D.new()
	path_region.navigation_polygon = path_poly
	navigation_container.add_child(path_region)

# Setup UI layout
func setup_ui():
	# Set to full screen
	anchor_right = 1.0
	anchor_bottom = 1.0
	
	# Create container for the map
	map_container = Panel.new()
	map_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_container.anchor_right = 1.0
	map_container.anchor_bottom = 1.0
	
	# Set semi-transparent dark background
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.2, 0.2, 0.2)
	map_container.add_theme_stylebox_override("panel", style_box)
	
	add_child(map_container)
	
	# Create container for paths
	path_container = Node2D.new()
	map_container.add_child(path_container)
	
	# Add title
	var title = Label.new()
	title.text = "Strategic Map (M to toggle)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 10
	title.offset_bottom = 40
	title.add_theme_font_size_override("font_size", 24)
	map_container.add_child(title)

# Setup locations on the map
func setup_locations():
	# Get location data from translator
	var locations = coord_translator.location_data
	
	# Create a rectangle for each location
	for location_id in locations:
		var location = locations[location_id]
		var world_pos = location["world_pos"]
		var size = location["size"]
		
		# Create rectangle
		var rect = ColorRect.new()
		rect.color = Color(0.3, 0.3, 0.3, 0.5)  # Semi-transparent gray
		
		# Calculate screen position and size
		# Map from world coordinates to screen coordinates
		var screen_pos = map_to_screen(world_pos)
		var screen_size = Vector2(size.x, size.y)  # Scale factor for visualization
		
		rect.position = screen_pos
		rect.size = screen_size
		
		map_container.add_child(rect)
		
		# Store reference
		location_rects[location_id] = rect
		
		# Add label for the location
		var label = Label.new()
		label.text = location_id
		label.position = Vector2(10, 10)
		label.add_theme_color_override("font_color", Color(1, 1, 1))
		rect.add_child(label)
		
		# Add POI markers
		setup_pois(location_id, rect, location["pois"])

# Setup POI markers within a location
func setup_pois(location_id: String, location_rect: ColorRect, pois: Dictionary):
	for poi_id in pois:
		var poi_pos = pois[poi_id]
		
		# Calculate relative position within the location
		var local_pos = poi_pos - coord_translator.location_data[location_id]["world_pos"]
		
		# Scale to match the rectangle size
		var scaled_pos = Vector2(
			local_pos.x / coord_translator.location_data[location_id]["size"].x * location_rect.size.x,
			local_pos.y / coord_translator.location_data[location_id]["size"].y * location_rect.size.y
		)
		
		# Create POI marker
		var poi_marker = ColorRect.new()
		poi_marker.color = Color(1, 0.8, 0)  # Yellow for POIs
		poi_marker.size = Vector2(10, 10)
		poi_marker.position = scaled_pos - poi_marker.size / 2
		location_rect.add_child(poi_marker)
		
		# Add label
		var label = Label.new()
		label.text = poi_id
		label.position = poi_marker.position + Vector2(15, 0)
		label.add_theme_color_override("font_color", Color(1, 1, 0.8))
		location_rect.add_child(label)

# Setup player marker
func setup_player_marker():
	player_marker = ColorRect.new()
	player_marker.color = Color(0, 1, 0)  # Green for player
	player_marker.size = Vector2(15, 15)
	player_marker.pivot_offset = player_marker.size / 2
	map_container.add_child(player_marker)
	
	# Update initial position
	update_player_position()

# Setup paths between locations
func setup_paths():
	# Draw lines between connected locations
	var locations = coord_translator.location_data
	var drawn_connections = []
	
	for from_id in locations:
		var from_location = locations[from_id]
		
		# Check portal connections
		for portal_id in from_location.get("portals", {}):
			var portal = from_location["portals"][portal_id]
			var to_id = portal["target_location"]
			
			# Skip if already drawn
			var connection_id = from_id + "_" + to_id
			var reverse_id = to_id + "_" + from_id
			if connection_id in drawn_connections or reverse_id in drawn_connections:
				continue
				
			# Draw the path
			draw_path_between(from_id, to_id)
			
			# Mark as drawn
			drawn_connections.append(connection_id)

# Draw a path between two locations
func draw_path_between(from_id: String, to_id: String):
	var from_rect = location_rects[from_id]
	var to_rect = location_rects[to_id]
	
	# Calculate centers
	var from_center = from_rect.position + from_rect.size / 2
	var to_center = to_rect.position + to_rect.size / 2
	
	# Create line
	var line = Line2D.new()
	line.width = 3.0
	line.default_color = Color(0.5, 0.5, 1.0)  # Light blue for paths
	
	# Add points
	line.add_point(from_center)
	line.add_point(to_center)
	
	path_container.add_child(line)

# Update player position marker on map
func update_player_position():
	# Get player's 3D position
	var player_pos = player.global_position
	
	# Get current location
	var current_location = alife_system.current_location
	
	# Convert to back position
	var back_pos = coord_translator.front_to_back(current_location, player_pos)
	
	# Convert to screen position
	var screen_pos = map_to_screen(back_pos)
	
	# Update marker position
	player_marker.position = screen_pos - player_marker.size / 2

# Convert world coordinates to screen coordinates
func map_to_screen(world_pos: Vector2) -> Vector2:
	# Apply scaling and offset for visualizationasd
	# This would need tuning based on actual map size
	var scale_factor = 2.0
	var offset = Vector2(50, 50)  # Margin from the edges
	
	return world_pos * scale_factor + offset
