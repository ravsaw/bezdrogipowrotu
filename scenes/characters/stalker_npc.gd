# scenes/characters/stalker_npc.gd
extends BaseNPC
class_name StalkerNPC

# Stalker-specific properties
var radiation_level: float = 0.0
var artifact_detector: bool = false

func _ready():
	super._ready()  # Call parent _ready
	# Stalker-specific setup
