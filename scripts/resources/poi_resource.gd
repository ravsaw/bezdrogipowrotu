# scripts/resources/poi_resource.gd
extends Resource
class_name POIResource

@export var poi_id: String = "poi1"
@export var world_position: Vector2 = Vector2.ZERO  # Pozycja na mapie strategicznej
@export var poi_type: String = "generic"  # generic, resource, danger, quest, itp.
@export var radius: float = 1.0  # Promień sfery w świecie 3D
@export var color: Color = Color(1, 0.8, 0, 0.8)  # Kolor POI
@export var description: String = ""  # Opcjonalny opis POI
@export var is_active: bool = true  # Czy POI jest aktywne
