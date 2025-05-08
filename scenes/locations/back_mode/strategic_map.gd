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

# Map navigation
var map_drag_active = false
var map_drag_start_pos = Vector2.ZERO
var map_offset = Vector2(0, 0)  # Starting offset
var map_zoom = 1.0
var min_zoom = 0.5
var max_zoom = 3.0
var zoom_step = 0.1
var map_content: Control  # Container for map elements that will be transformed

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

# Handle input for map navigation
func _input(event):
	if not visible:
		return
		
	# Mouse wheel for zooming
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_map(zoom_step)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_map(-zoom_step)
			get_viewport().set_input_as_handled()
		# Start dragging with left mouse button
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				map_drag_active = true
				map_drag_start_pos = event.position
			else:
				map_drag_active = false
	
	# Handle map dragging
	if event is InputEventMouseMotion and map_drag_active:
		var drag_delta = event.position - map_drag_start_pos
		map_offset += drag_delta
		map_drag_start_pos = event.position
		update_map_transform()
		get_viewport().set_input_as_handled()
			# Keyboard shortcuts
	if event is InputEventKey and event.pressed:
		# Center on player with C key
		if event.keycode == KEY_C:
			center_on_player()
			get_viewport().set_input_as_handled()
		# Show all locations with A key
		elif event.keycode == KEY_A:
			show_all_locations()
			get_viewport().set_input_as_handled()

func show_all_locations():
	# Calculate bounds of all locations
	var min_pos = Vector2(INF, INF)
	var max_pos = Vector2(-INF, -INF)
	
	for location_id in coord_translator.location_data:
		var location = coord_translator.location_data[location_id]
		var pos = location["world_pos"]
		var size = location["size"]
		
		min_pos.x = min(min_pos.x, pos.x)
		min_pos.y = min(min_pos.y, pos.y)
		max_pos.x = max(max_pos.x, pos.x + size.x)
		max_pos.y = max(max_pos.y, pos.y + size.y)
	
	# Calculate center and required zoom
	var center = (min_pos + max_pos) / 2
	var extent = max_pos - min_pos
	
	# Calculate zoom to fit all locations
	var viewport_size = get_viewport_rect().size
	var zoom_x = viewport_size.x / (extent.x + 100)  # Add padding
	var zoom_y = viewport_size.y / (extent.y + 100)
	map_zoom = min(zoom_x, zoom_y)
	map_zoom = clamp(map_zoom, min_zoom, max_zoom)
	
	# Set offset to center the view
	map_offset = viewport_size / 2 - center * map_zoom
	
	# Update transform
	update_map_transform()
	
# Zoom the map by specified amount
func zoom_map(amount):
	var old_zoom = map_zoom
	map_zoom = clamp(map_zoom + amount, min_zoom, max_zoom)
	
	# Adjust offset to zoom toward mouse position
	if map_zoom != old_zoom:
		# Get mouse position
		var mouse_pos = get_viewport().get_mouse_position()
		
		# Calculate zoom center (relative to map_content)
		var zoom_center = mouse_pos - map_content.global_position
		
		# Adjust offset based on zoom center
		var zoom_factor = map_zoom / old_zoom
		var new_offset = zoom_center - (zoom_center - map_offset) * zoom_factor
		map_offset = new_offset
		
		update_map_transform()

# Update map transform based on offset and zoom
func update_map_transform():
	map_content.position = map_offset
	map_content.scale = Vector2(map_zoom, map_zoom)

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
	style_box.bg_color = Color(0.1, 0.1, 0.15)  # Dark blue-ish background
	map_container.add_theme_stylebox_override("panel", style_box)
	
	add_child(map_container)
	
	# Create content container that will be transformed
	map_content = Control.new()
	map_content.name = "MapContent"
	map_content.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Pass mouse events to parent
	map_content.position = map_offset
	map_container.add_child(map_content)
	
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
	
	# Add help text
	var help_text = Label.new() 
	help_text.text = "Drag: Left mouse button | Zoom: Mouse wheel"
	help_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help_text.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	help_text.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	help_text.offset_bottom = -10
	help_text.offset_top = -40
	map_container.add_child(help_text)

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
		rect.color = Color(0.3, 0.3, 0.3)  # Semi-transparent gray
		
		# Calculate screen position and size
		rect.position = world_pos
		rect.size = size
		
		map_content.add_child(rect)
		
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
	
	# Show all locations initially
	show_all_locations()

func center_on_player():
	if player_marker == null:
		return
		
	# Calculate player position in world coordinates
	var player_pos = player.global_position
	var current_location = get_current_location()
	var back_pos = coord_translator.front_to_back(current_location, player_pos)
	
	# Calculate offset to center player in view
	var viewport_size = get_viewport_rect().size
	map_offset = viewport_size / 2 - back_pos * map_zoom
	
	# Update map transform
	update_map_transform()
	
# Setup POI markers for a location
func setup_pois(location_id: String, location_rect: ColorRect):
	# Check if location has POIs
	if not coord_translator.location_data[location_id].has("pois"):
		print("No POIs found in location: " + location_id)
		return
	
	var pois = coord_translator.location_data[location_id]["pois"]
	
	for poi_id in pois:
		var poi_data = pois[poi_id]
		var poi_pos = poi_data["position"]
		var poi_type = poi_data["type"]
		
		# Calculate relative position within the location
		var location_data = coord_translator.location_data[location_id]
		var local_pos = poi_pos - location_data["world_pos"]
		
		# Create POI marker
		var poi_marker = create_poi_marker(poi_id, poi_type)
		poi_marker.position = location_rect.position + local_pos - poi_marker.size / 2
		map_content.add_child(poi_marker)
		
		# Store marker reference
		poi_markers[location_id + "_" + poi_id] = poi_marker

# Create a visual marker for a POI
func create_poi_marker(poi_id: String, poi_type: String) -> Control:
	# Create container for the POI marker
	var marker_container = Control.new()
	marker_container.size = Vector2(20, 20)
	marker_container.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Pass mouse events through
	
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
	map_content.add_child(player_marker)
	
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
	
	# Update marker position directly (no conversion needed)
	player_marker.position = back_pos - player_marker.size / 2

# Get current location from world manager
func get_current_location() -> String:
	var world = get_node("/root/World")
	return world.current_location_id
