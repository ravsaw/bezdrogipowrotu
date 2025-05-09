# scenes/characters/base_npc.gd
extends CharacterBody3D
class_name BaseNPC

# Character data
var npc_id: String = ""
var npc_type: String = "stalker"
var faction: String = "loner"
var health: float = 100.0
var equipment = {}  # Dictionary to store equipment data

# Navigation
var target_position: Vector3 = Vector3.ZERO
var is_moving: bool = false
var movement_speed: float = 15.0  # Units per second
var current_poi_id: String = ""
var target_poi_id: String = ""

# References
var world_manager: WorldManager
var coord_translator: CoordTranslator
var poi_manager: POIManager

# Signals
signal health_changed(new_health)
signal equipment_changed(slot, item_id)
signal arrived_at_target

func _ready():
	# Set up references
	world_manager = get_node("/root/World")
	coord_translator = get_node("/root/World/Systems/CoordTranslator") 
	poi_manager = get_node("/root/World/Systems/POIManager")
	
	# Set up collision
	var collision_shape = $CollisionShape3D
	if not collision_shape:
		collision_shape = CollisionShape3D.new()
		var shape = CapsuleShape3D.new()
		shape.radius = 0.5
		shape.height = 2.0
		collision_shape.shape = shape
		add_child(collision_shape)

func _process(delta):
	# Handle basic movement
	if is_moving:
		move_toward_target(delta)

# Initialize NPC with data
func initialize(data: Dictionary):
	npc_id = data.get("npc_id", "unknown")
	npc_type = data.get("npc_type", "stalker")
	faction = data.get("faction", "loner")
	health = data.get("health", 100.0)
	
	# Set name for easy retrieval
	name = npc_id
	
	# Initialize equipment if specified
	var equip_data = data.get("equipment", {})
	for slot in equip_data:
		set_equipment(slot, equip_data[slot])
	
	# Set color or appearance if needed
	if data.has("color"):
		set_appearance_color(data.get("color"))

# Handle movement
func move_toward_target(delta):
	if target_position == Vector3.ZERO:
		return
		
	# Calculate direction and distance
	var direction = target_position - global_position
	direction.y = 0  # Keep level with the ground
	var distance = direction.length()
	
	# If close enough, stop moving
	if distance < 0.5:
		is_moving = false
		emit_signal("arrived_at_target")
		return
	
	# Move toward target
	direction = direction.normalized()
	var movement = direction * movement_speed * delta
	
	# Option 1: Use velocity (preferred for CharacterBody3D)
	velocity = Vector3(movement.x, velocity.y, movement.z)
	move_and_slide()
	
	# Option 2: Direct position change (simpler)
	# global_position += movement

# Set target position to move toward
func set_target_position(pos: Vector3):
	target_position = pos
	is_moving = true
	
	# Rotate to face target
	look_at(Vector3(pos.x, global_position.y, pos.z), Vector3.UP)

# Set equipment in a slot
func set_equipment(slot: String, item_id: String):
	equipment[slot] = item_id
	update_appearance()
	emit_signal("equipment_changed", slot, item_id)

# Update visual appearance based on equipment
func update_appearance():
	# This will be overridden by specific NPC types
	# By default just update color based on faction
	pass

# Set appearance color (basic visual differentiation)
func set_appearance_color(color: Color):
	# Find mesh instance
	var mesh_instance = find_child("MeshInstance3D", true, false)
	if mesh_instance and mesh_instance is MeshInstance3D:
		var material = StandardMaterial3D.new()
		material.albedo_color = color
		mesh_instance.material_override = material

# Take damage
func take_damage(amount: float):
	health -= amount
	if health <= 0:
		health = 0
		die()
	emit_signal("health_changed", health)

# Die
func die():
	# Override this in specific NPC types
	queue_free()
