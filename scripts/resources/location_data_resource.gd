# scripts/resources/location_data_resource.gd
extends Resource
class_name LocationDataResource

@export var world_pos: Vector2 = Vector2.ZERO
@export var size: Vector2 = Vector2(100, 100)
@export var scale_factor: Vector2 = Vector2(10, 10)

# Dictionary to store POI data
@export var pois: Dictionary = {}

# Helper methods
func add_poi(id: String, position: Vector2, poi_type: String = "generic"):
	pois[id] = {
		"position": position,
		"type": poi_type
	}
