# scenes/characters/stalker_npc.gd
extends BaseNPC
class_name StalkerNPC

# Stalker-specific properties
var radiation_level: float = 0.0
var artifact_detector: bool = false

func _ready():
	super._ready()  # Call parent _ready
	# Stalker-specific setup

# Override update_appearance to handle stalker-specific equipment
func update_appearance():
	# Find model container
	var model_container = $ModelContainer
	if not model_container:
		return
	
	# Update head gear
	if equipment.has("head"):
		var helmet_id = equipment["head"]
		update_model_part("head", helmet_id)
	
	# Update body armor
	if equipment.has("body"):
		var armor_id = equipment["body"]
		update_model_part("body", armor_id)
	
	# Update weapon
	if equipment.has("weapon"):
		var weapon_id = equipment["weapon"]
		update_model_part("weapon", weapon_id)

# Update a specific part of the model
func update_model_part(part: String, item_id: String):
	var model_container = $ModelContainer
	
	# Remove existing part if any
	var existing = model_container.get_node_or_null(part)
	if existing:
		existing.queue_free()
	
	# Load new model if item_id is valid
	if item_id != "none":
		var model_path = "res://assets/models/equipment/" + part + "/" + item_id + ".tscn"
		var model_scene = load(model_path)
		if model_scene:
			var model_instance = model_scene.instantiate()
			model_instance.name = part
			model_container.add_child(model_instance)
