# scripts/resources/location_connector_resource.gd
extends Resource
class_name LocationConnectorResource

@export var connector_id: String = "connector1"
@export var location_a: String = ""
@export var location_b: String = ""
@export var position_a: Vector2 = Vector2.ZERO  # Position in location A
@export var position_b: Vector2 = Vector2.ZERO  # Position in location B
@export var is_active: bool = true
