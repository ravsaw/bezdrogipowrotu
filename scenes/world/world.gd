extends Node3D
class_name WorldManager

# Location scenes
var location_scenes = {
	"location1": preload("res://scenes/locations/front_mode/location1.tscn"),
	#"location2": preload("res://scenes/locations/front_mode/location2.tscn")
}

# References
var coord_translator: CoordTranslator
var alife_system
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
	
	await get_tree().process_frame
	
	# Setup player first
	setup_player()
	
	# Load initial location
	load_location(current_location_id)
	
	# Setup strategic map
	setup_strategic_map()
	
	# Now initialize A-Life system with the player reference
	# This fixes the dependency issue
	alife_system.initialize(player)

# Initialize game systems
func initialize_systems():
	# Create coordinate translator
	coord_translator = CoordTranslator.new()
	coord_translator.name = "CoordTranslator"
	systems_container.add_child(coord_translator)
	
	# Create A-Life system
	alife_system = ALifeSystem.new()
	alife_system.name = "ALifeSystem"
	systems_container.add_child(alife_system)

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
	# Usuń aktualną lokację, jeśli istnieje
	if current_location:
		current_location.queue_free()
	
	# Utwórz nową lokację
	var location_scene = location_scenes[location_id]
	current_location = location_scene.instantiate()
	current_location.name = location_id
	locations_container.add_child(current_location)
	
	# Zaktualizuj śledzenie aktualnej lokacji
	current_location_id = location_id
	
	# Powiedz systemowi A-Life o zmianie lokacji, jeśli jest zainicjalizowany
	if alife_system and alife_system.initialized:
		alife_system.set_player_location(location_id)

# Setup strategic map (back mode view)
func setup_strategic_map():
	var map_scene = preload("res://scenes/locations/back_mode/strategic_map.tscn")
	strategic_map = map_scene.instantiate()
	strategic_map.name = "StrategicMap"
	ui_container.add_child(strategic_map)
	
	# Hide by default, can be toggled with a key
	strategic_map.visible = false

# Change to a different location
func change_location(location_id: String, spawn_position: Vector3):
	# Load the new location
	load_location(location_id)
	
	# Move player to spawn position
	player.global_position = spawn_position
	
	# Force an A-Life update if initialized
	if alife_system and alife_system.initialized:
		alife_system.set_player_location(location_id)

# Toggle strategic map visibility
func toggle_strategic_map():
	strategic_map.visible = !strategic_map.visible

# Process input for world controls
func _input(event):
	# Toggle strategic map with M key
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_M:
			toggle_strategic_map()
		
		# Debug key to add a new NPC group (for testing)
		elif event.keycode == KEY_G:
			_debug_spawn_test_group()

# Debug function to spawn a test group
func _debug_spawn_test_group():
	# Skip if A-Life is not initialized
	if not alife_system or not alife_system.initialized:
		print("Cannot spawn test group: A-Life system not fully initialized")
		return
		
	# Get a random location
	var locations = location_scenes.keys()
	var rand_location = locations[randi() % locations.size()]
	
	# Get a random position in that location
	var pois = coord_translator.get_poi_positions(rand_location)
	var spawn_pos = Vector2.ZERO
	
	# Check if POIs exist, otherwise use default position
	if pois.is_empty():
		print("No POIs found in location " + rand_location + ", using default position")
		# Use the center of the location as default position
		var location_data = coord_translator.location_data[rand_location]
		spawn_pos = location_data["world_pos"] + location_data["size"] / 2
	else:
		var poi_keys = pois.keys()
		var rand_poi = poi_keys[randi() % poi_keys.size()]
		spawn_pos = pois[rand_poi]
	
	# Create a unique ID
	var group_id = "group" + str(Time.get_ticks_msec())
	
	# Add the group
	alife_system.add_npc_group(group_id, rand_location, spawn_pos)
	
	# Debug message
	print("Spawned new test group: ", group_id, " at ", rand_location, " position ", spawn_pos)
