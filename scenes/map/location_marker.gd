@tool  # Dodaj tę linię na początku, aby skrypt działał w edytorze
extends Node2D
class_name LocationMarker

@export var location_id: String = "location1":
	set(new_id):
		location_id = new_id
		if is_inside_tree() and Engine.is_editor_hint() and label:
			label.text = new_id

@export var color: Color = Color(0.3, 0.3, 0.3, 0.5):
	set(new_color):
		color = new_color
		if is_inside_tree() and Engine.is_editor_hint() and rect:
			rect.color = new_color

@export var width: float = 200:
	set(new_width):
		width = new_width
		if is_inside_tree() and Engine.is_editor_hint() and rect:
			rect.size.x = new_width
			update_navigation_polygon()

@export var height: float = 200:
	set(new_height):
		height = new_height
		if is_inside_tree() and Engine.is_editor_hint() and rect:
			rect.size.y = new_height
			update_navigation_polygon()

@export var scale_factor: Vector2 = Vector2(5, 5)

# Referencje do elementów UI
var rect: ColorRect
var label: Label
var region: NavigationRegion2D

func _ready():
	add_to_group("location_markers")
	
	if Engine.is_editor_hint():
		setup_visual_elements()
	else:
		# W runtime, ten węzeł będzie używany tylko do zbierania danych
		pass

func setup_visual_elements():
	# Usuwamy istniejące elementy, jeśli istnieją
	for child in get_children():
		child.queue_free()
	
	# Utwórz prostokąt reprezentujący lokację
	rect = ColorRect.new()
	rect.color = color
	rect.position = Vector2.ZERO
	rect.size = Vector2(width, height)
	add_child(rect)
	
	# Dodaj etykietę
	label = Label.new()
	label.text = location_id
	label.position = Vector2(10, 10)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	rect.add_child(label)
	
	# Dodaj region nawigacyjny
	region = NavigationRegion2D.new()
	region.name = location_id + "NavRegion"
	add_child(region)
	
	# Utwórz poligon nawigacyjny
	update_navigation_polygon()

func update_navigation_polygon():
	if not region:
		return
		
	var nav_poly = NavigationPolygon.new()
	var outline = PackedVector2Array([
		Vector2(0, 0),
		Vector2(width, 0),
		Vector2(width, height),
		Vector2(0, height)
	])
	
	nav_poly.add_outline(outline)
	nav_poly.make_polygons_from_outlines()
	region.navigation_polygon = nav_poly

func get_location_data() -> Dictionary:
	return {
		"location_id": location_id,
		"position": global_position,
		"size": Vector2(width, height),
		"scale_factor": scale_factor,
		"color": color  # Dodajemy kolor do danych lokacji
	}

# Dodaj te funkcje, aby umożliwić przeciąganie i zmianę rozmiaru w edytorze
func _get_configuration_warnings():
	return ["Ten węzeł służy do wizualnego definiowania lokacji na mapie."]
