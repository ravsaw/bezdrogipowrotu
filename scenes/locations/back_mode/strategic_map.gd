extends Control
class_name StrategicMap

# References
var coord_translator: CoordTranslator
var player

# UI elements
var map_container: Panel
var location_rects = {}
var player_marker: ColorRect
var poi_markers = {} # Dictionary to store POI markers by ID

func _ready():
	# Get system references
	coord_translator = get_node("/root/World/Systems/CoordTranslator")
	player = get_node("/root/World/Player")
	
	# Setup layout
	setup_ui()
	
	# Wait for a frame to ensure locations are registered
	await get_tree().process_frame
	
	# Setup locations
	setup_locations()
	
	# Create player marker
	setup_player_marker()
	
func _process(_delta):
	# Update player position on the map
	if player_marker != null:
		update_player_position()

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
	style_box.bg_color = Color(0.1, 0.1, 0.15, 0.9)  # Dark blue-ish background
	map_container.add_theme_stylebox_override("panel", style_box)
	
	add_child(map_container)
	
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
		setup_pois(location_id, rect)

# Setup POI markers for a location
func setup_pois(location_id: String, location_rect: ColorRect):
	# Check if location has POIs
	if not coord_translator.location_data[location_id].has("pois"):
		print("No POIs found in location: " + location_id)
		return
	
	var pois = coord_translator.location_data[location_id]["pois"]
	print("Setting up POIs for location " + location_id + ": " + str(pois.keys()))
	
	for poi_id in pois:
		var poi_data = pois[poi_id]
		var poi_pos = poi_data["position"]
		var poi_type = poi_data["type"]
		
		# Calculate relative position within the location
		var location_data = coord_translator.location_data[location_id]
		var local_pos = poi_pos - location_data["world_pos"]
		
		# Scale to match the rectangle size
		var scaled_pos = Vector2(
			local_pos.x / location_data["size"].x * location_rect.size.x,
			local_pos.y / location_data["size"].y * location_rect.size.y
		)
		
		# Create POI marker
		var poi_marker = create_poi_marker(poi_id, poi_type)
		poi_marker.position = scaled_pos - poi_marker.size / 2
		location_rect.add_child(poi_marker)
		
		# Store marker reference
		poi_markers[location_id + "_" + poi_id] = poi_marker

# Create a visual marker for a POI
func create_poi_marker(poi_id: String, poi_type: String) -> Control:
	# Create container for the POI marker
	var marker_container = Control.new()
	marker_container.size = Vector2(20, 20)
	
	# Create colored marker based on POI type
	var marker = ColorRect.new()
	
	# Different colors based on POI type
	var color = Color(1, 0.8, 0)  # Default yellow
	match poi_type:
		"resource":
			color = Color(0, 0.8, 0.2)  # Green for resources
		"danger":
			color = Color(0.9, 0.2, 0.2)  # Red for danger
		"quest":
			color = Color(0.2, 0.4, 0.9)  # Blue for quests
	
	marker.color = color
	marker.size = Vector2(12, 12)
	marker.position = Vector2(4, 4)  # Center in container
	marker_container.add_child(marker)
	
	# Add label
	var label = Label.new()
	label.text = poi_id
	label.position = Vector2(15, 0)
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 14)
	marker_container.add_child(label)
	
	# Make a cool visual effect - pulsing
	var animation = AnimationPlayer.new()
	marker_container.add_child(animation)
	
	var anim = Animation.new()
	var track_idx = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track_idx, "../ColorRect:scale")
	anim.track_insert_key(track_idx, 0.0, Vector2(1, 1))
	anim.track_insert_key(track_idx, 0.5, Vector2(1.2, 1.2))
	anim.track_insert_key(track_idx, 1.0, Vector2(1, 1))
	anim.loop_mode = Animation.LOOP_LINEAR
	
	var anim_lib = AnimationLibrary.new()
	anim_lib.add_animation("pulse", anim)
	animation.add_animation_library("poi_anims", anim_lib)
	animation.play("poi_anims/pulse")
	
	return marker_container

# Setup player marker
func setup_player_marker():
	player_marker = ColorRect.new()
	player_marker.color = Color(0, 0.8, 0.2)  # Green for player
	player_marker.size = Vector2(15, 15)
	player_marker.pivot_offset = player_marker.size / 2
	map_container.add_child(player_marker)
	
	# Add player label
	var label = Label.new()
	label.text = "Player"
	label.position = Vector2(player_marker.size.x + 5, -5)
	label.add_theme_color_override("font_color", Color(0, 1, 0.2))
	player_marker.add_child(label)
	
	# Update initial position
	update_player_position()

# Update player position marker on map
func update_player_position():
	
	if player_marker == null:
		return

	# Get player's 3D position
	var player_pos = player.global_position
	
	# Get current location
	var current_location = get_current_location()
	
	# Convert to back position
	var back_pos = coord_translator.front_to_back(current_location, player_pos)
	
	# Convert to screen position
	var screen_pos = map_to_screen(back_pos)
	
	# Update marker position
	player_marker.position = screen_pos - player_marker.size / 2

# Get current location from world manager
func get_current_location() -> String:
	var world = get_node("/root/World")
	return world.current_location_id

# Convert world coordinates to screen coordinates
func map_to_screen(world_pos: Vector2) -> Vector2:
	# Apply scaling and offset for visualization
	var scale_factor = 1.0
	var offset = Vector2(50, 50)  # Margin from the edges
	
	return world_pos * scale_factor + offset
