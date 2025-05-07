# scenes/objects/location_change_marker.gd
extends Node3D
class_name LocationChangeMarker

@export var target_location: String = "location2"
@export var spawn_point_id: String = "entry1" # Do jakiego punktu NPC powinny się kierować po zmianie lokacji
@export var marker_color: Color = Color(0.2, 1.0, 0.4, 0.8) # Zielony

func register_with_location(location: Location):
	location.register_location_change_marker(self)
