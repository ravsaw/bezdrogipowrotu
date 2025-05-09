# scenes/characters/bandit_npc.gd
extends BaseNPC
class_name BanditNPC

# Bandit-specific properties
var radiation_level: float = 0.0
var artifact_detector: bool = false
var aggression_level: float = 0.7

func _ready():
	super._ready()  # Call parent _ready
	# Bandit-specific setup
	set_appearance_color(Color(0.1, 0.1, 0.1))
