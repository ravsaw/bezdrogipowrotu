extends Node3D
class_name WorldManager

# Location scenes
var location_scenes = {
	"location1": preload("res://scenes/locations/front_mode/location1.tscn"),
}

# References
var coord_translator: CoordTranslator
var player
var strategic_map

# Current state
var current_location_id: String = "location1"
var current_location: Node3D

# Nodes
var locations_container: Node3D
var systems_container: Node
var ui_container: Control

func _ready():
	# Create containers for organization
	locations_container = Node3D.new()
	locations_container.name = "Locations"
	add_child(locations_container)
	
	systems_container = Node.new()
	systems_container.name = "Systems"
	add_child(systems_container)
	
	ui_container = Control.new()
	ui_container.name = "UI"
	add_child(ui_container)
	
	# Initialize systems
	initialize_systems()
	
	# Load initial location FIRST
	load_location(current_location_id)
	
	# Wait for a frame to ensure location is registered with coord_translator
	await get_tree().process_frame
	
	# THEN setup player (after location data is available)
	setup_player()
	
	# Finally, setup strategic map
	setup_strategic_map()

# Initialize game systems
func initialize_systems():
	# Create coordinate translator
	coord_translator = CoordTranslator.new()
	coord_translator.name = "CoordTranslator"
	systems_container.add_child(coord_translator)

# Setup the player
func setup_player():
	# Instantiate player scene
	var player_scene = preload("res://scenes/player/player.tscn")
	player = player_scene.instantiate()
	player.name = "Player"
	add_child(player)
	
	# Set initial position
	var spawn_pos = coord_translator.back_to_front(current_location_id, Vector2(150, 150))
	player.global_position = spawn_pos

# Load a location
func load_location(location_id: String):
	# Remove current location if it exists
	if current_location:
		current_location.queue_free()
	
	# Create new location
	var location_scene = location_scenes[location_id]
	current_location = location_scene.instantiate()
	current_location.name = location_id
	locations_container.add_child(current_location)
	
	# Update current location tracking
	current_location_id = location_id

# Setup strategic map (back mode view)
func setup_strategic_map():
	var map_scene = preload("res://scenes/locations/back_mode/strategic_map.tscn")
	strategic_map = map_scene.instantiate()
	strategic_map.name = "StrategicMap"
	ui_container.add_child(strategic_map)
	
	# Hide by default, can be toggled with a key
	strategic_map.visible = false

# Toggle strategic map visibility
func toggle_strategic_map():
	strategic_map.visible = !strategic_map.visible

# Process input for world controls
func _input(event):
	# Toggle strategic map with M key
	if event is InputEventKey and event.pressed and event.keycode == KEY_M:
		toggle_strategic_map()
