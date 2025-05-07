# scenes/objects/poi.gd
extends Node3D
class_name POI

@export var poi_id: String = "poi1"
@export var poi_type: String = "generic" # Możemy mieć różne typy POI
@export var marker_color: Color = Color(1, 0.8, 0, 0.8) # Domyślnie żółty
@export var is_npc_destination: bool = true # Czy NPC mogą tu się kierować
