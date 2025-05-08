extends Node
class_name CoordTranslator

# Słownik do przechowywania danych lokacji
var location_data = {}

func _ready():
	# Inicjalizuj pusty słownik - będzie wypełniony przez lokacje
	location_data = {}

# Zarejestruj lokację z jej danymi
func register_location(location_id: String, data: Dictionary):
	# Dodaj dane lokacji do naszego słownika
	location_data[location_id] = data
	print("Zarejestrowano lokację: " + location_id)

# Przetłumacz z trybu frontowego (3D) na tryb backendowy (2D)
func front_to_back(location_id: String, front_pos: Vector3) -> Vector2:
	# Sprawdzenie bezpieczeństwa: upewnij się, że location_id istnieje w naszych danych
	if not location_data.has(location_id):
		push_error("Location ID '" + location_id + "' not found in location_data")
		return Vector2.ZERO
		
	var location = location_data[location_id]
	var scale_factor = location["scale_factor"]
	
	# Konwertuj pozycję frontową na pozycję backendową
	# Ignoruj Y (wysokość) z pozycji 3D
	var relative_pos = Vector2(front_pos.x / scale_factor.x, front_pos.z / scale_factor.y)
	
	# Dodaj offset pozycji na mapie strategicznej
	return location["world_pos"] + relative_pos

# Przetłumacz z trybu backendowego (2D) na tryb frontowy (3D) 
func back_to_front(location_id: String, back_pos: Vector2) -> Vector3:
	# Sprawdzenie bezpieczeństwa: upewnij się, że location_id istnieje w naszych danych
	if not location_data.has(location_id):
		push_error("Location ID '" + location_id + "' not found in location_data")
		return Vector3(0, 2, 0)
		
	var location = location_data[location_id]
	var scale_factor = location["scale_factor"]
	
	# Pobierz lokalne współrzędne w trybie backendowym
	var local_back_pos = back_pos - location["world_pos"]
	
	# Konwertuj na współrzędne trybu frontowego
	# Y (wysokość) jest ustawione na 0, ale powinno być dostosowane na podstawie terenu
	return Vector3(
		local_back_pos.x * scale_factor.x,
		0,  # Poziom ziemi, powinien być dostosowany na podstawie wysokości terenu
		local_back_pos.y * scale_factor.y
	)

# Sprawdź, czy pozycja backendowa znajduje się w granicach lokacji
func is_within_location(location_id: String, back_pos: Vector2) -> bool:
	# Sprawdzenie bezpieczeństwa: upewnij się, że lokacja istnieje
	if not location_data.has(location_id):
		push_error("Location ID '" + location_id + "' not found in location_data")
		return false
		
	var location = location_data[location_id]
	var local_pos = back_pos - location["world_pos"]
	
	return (
		local_pos.x >= 0 and 
		local_pos.x < location["size"].x and 
		local_pos.y >= 0 and 
		local_pos.y < location["size"].y
	)

# Znajdź, która lokacja zawiera pozycję backendową
func get_location_at_position(back_pos: Vector2) -> String:
	for location_id in location_data:
		if is_within_location(location_id, back_pos):
			return location_id
	
	return ""  # Nie znaleziono lokacji
