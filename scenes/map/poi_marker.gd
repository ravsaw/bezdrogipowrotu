# scenes/map/poi_marker.gd
extends Node2D
class_name POIMarker

@export var poi_id: String = "poi1"
@export var poi_type: String = "generic"  # Typ POI: generic, resource, danger, quest
@export var radius: float = 1.0  # Promień sfery w świecie 3D
@export var color: Color = Color(1, 0.8, 0, 0.8)  # Kolor POI
@export var description: String = ""  # Opcjonalny opis POI
@export var is_active: bool = true  # Czy POI jest domyślnie aktywne

# Wizualne elementy
var marker_shape: ColorRect
var label: Label

# Sygnały
signal clicked

func _ready():
	# Utwórz wizualną reprezentację
	create_visual_marker()
	
	# Dodaj do grupy POI dla łatwego wyszukiwania
	add_to_group("poi_markers")

# Utwórz wizualną reprezentację markera POI
func create_visual_marker():
	# Utwórz kolorowy marker
	marker_shape = ColorRect.new()
	marker_shape.color = color
	marker_shape.size = Vector2(12, 12)
	marker_shape.position = Vector2(-6, -6)  # Wycentruj względem pozycji węzła
	add_child(marker_shape)
	
	# Dodaj etykietę
	label = Label.new()
	label.text = poi_id
	label.position = Vector2(8, -10)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	
	# Dodaj obszar wykrywania kliknięć
	var click_area = Area2D.new()
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 10.0
	collision.shape = shape
	click_area.add_child(collision)
	add_child(click_area)
	
	# Połącz sygnały
	click_area.input_event.connect(_on_input_event)

# Obsługa zdarzeń wejściowych
func _on_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("clicked")

# Konwertuj do POIResource
func to_poi_resource() -> POIResource:   
	print("Tworzenie POIResource dla markera " + poi_id + " na pozycji " + str(global_position))
	var resource = POIResource.new()
	resource.poi_id = poi_id
	resource.world_position = global_position
	resource.poi_type = poi_type
	resource.radius = radius
	resource.color = color
	resource.description = description
	resource.is_active = is_active
	return resource
