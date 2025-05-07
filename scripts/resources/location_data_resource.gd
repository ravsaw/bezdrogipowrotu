# scripts/resources/location_data_resource.gd
extends Resource
class_name LocationDataResource

@export var world_pos: Vector2 = Vector2.ZERO
@export var size: Vector2 = Vector2(100, 100)
@export var scale_factor: Vector2 = Vector2(10, 10)

# Dictionary to store portal data
@export var portals: Dictionary = {}

# Dictionary to store POI data
@export var pois: Dictionary = {}

# Helper methods
func add_portal(id: String, front_pos: Vector3, target_location: String, target_portal: String):
	portals[id] = {
		"front_pos": front_pos,
		"target_location": target_location,
		"target_portal": target_portal
	}

func add_poi(id: String, position: Vector2):
	pois[id] = position
