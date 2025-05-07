# scenes/portals/location_portal.gd
extends Area3D
class_name LocationPortal

@export var portal_id: String = "portal1"
@export var target_location: String = "location2"
@export var target_portal: String = "portal1"
@export var visual_radius: float = 2.0
@export var visual_height: float = 4.0
@export var portal_color: Color = Color(0.2, 0.4, 1.0, 0.6)

# Ta funkcja będzie wywoływana podczas inicjalizacji lokacji
func register_with_location(location: Location):
	location.register_portal(self)
