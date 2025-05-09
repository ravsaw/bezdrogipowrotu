# scripts/systems/npc_manager.gd
extends Node
class_name NPCManager

var npc_scenes = {
	"stalker": preload("res://scenes/characters/stalker_npc.tscn"),
	"bandit": preload("res://scenes/characters/bandit_npc.tscn"),
	# Add more NPC types as needed
	"default": preload("res://scenes/characters/base_npc.tscn")
}

# Collection of all NPCs in the game
var player_visibility_range: float = 150.0  # 50 meters visibility range
var all_npcs = {}       # Dictionary of NPCResource objects by ID (master data)
var npc_instances = {}  # Dictionary of 3D Node instances that are currently active/visible
var npc_containers = {} # Dictionary of container nodes for NPCs in each location
var current_location: String = ""  # Track current location
var visibility_check_timer: float = 0.0
var visibility_check_interval: float = 1.0  # Check every 3 seconds

# References
var coord_translator: CoordTranslator
var poi_manager: POIManager
var world_manager: WorldManager
var player: Player
var connector_manager: ConnectorManager

# Signals
signal npc_state_changed(npc_id, state)
signal npc_position_changed(npc_id, position)
signal manager_ready  # Renamed from npc_manager_ready
signal npc_registered(npc_id)
signal npcs_registered
signal npc_despawned(npc_id)

# Movement speed in strategic map coordinates per second
var npc_movement_speed: float = 5.0

func _ready():
	# Wait one frame to ensure the node is fully initialized
	await get_tree().process_frame
	
	# Get references
	coord_translator = get_node_or_null("/root/World/Systems/CoordTranslator")
	poi_manager = get_node_or_null("/root/World/Systems/POIManager")
	world_manager = get_node_or_null("/root/World")
	player = get_node_or_null("/root/World/Player")
	connector_manager = get_node_or_null("/root/World/Systems/ConnectorManager")
	
	# Notify that NPC Manager is ready
	emit_signal("manager_ready")  # Changed from npc_manager_ready
	print("NPC Manager ready")
	current_location = world_manager.current_location_id
	
	if world_manager:
		world_manager.location_changed.connect(_on_location_changed)

# [Rest of the NPCManager code remains unchanged]
