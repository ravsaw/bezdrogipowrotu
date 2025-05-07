# scenes/objects/spawn_point.gd
extends Node3D
class_name SpawnPoint

@export var spawn_id: String = "spawn1"
@export var marker_color: Color = Color(0.2, 0.2, 1.0, 0.8) # Niebieski

func register_with_location(location: Location):
	location.register_spawn_point(self)
