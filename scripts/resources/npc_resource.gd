# scripts/resources/npc_resource.gd
extends Resource
class_name NPCResource

@export var npc_id: String = "npc1"
@export var npc_type: String = "stalker"  # stalker, bandit, military, etc.
@export var world_position: Vector2 = Vector2.ZERO  # Position on strategic map
@export var health: float = 100.0
@export var is_active: bool = true
@export var faction: String = "loner"
@export var current_poi_id: String = ""  # Current POI the NPC is at
@export var target_poi_id: String = ""   # POI the NPC is heading to
@export var target_connector_id: String = ""  # Connector the NPC is heading to
@export var target_position: Vector2 = Vector2.ZERO  # Target position for movement
@export var state: String = "idle"  # idle, moving, moving_to_connector, etc.
@export var color: Color = Color(0.2, 0.6, 1.0)  # Color for display on map
