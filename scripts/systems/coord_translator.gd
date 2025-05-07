# scripts/systems/coord_translator.gd
extends Node
class_name CoordTranslator

# Słownik do przechowywania danych o lokacjach
var location_data = {}

func _ready():
	# Inicjalizacja pustego słownika - będzie wypełniony przez lokacje
	location_data = {}

# Rejestruje lokację z jej danymi
func register_location(location_id: String, data: Dictionary):
	# Dodaj dane lokacji do naszego słownika
	location_data[location_id] = data
	print("Zarejestrowano lokację: " + location_id)

# Rejestruje POI
func register_poi(location_id: String, poi_id: String, back_pos: Vector2, poi_type: String = "generic"):
	# Upewnij się, że lokacja istnieje
	if not location_data.has(location_id):
		push_error("Location ID '" + location_id + "' not found in location_data")
		return
		
	# Upewnij się, że słownik POI istnieje
	if not location_data[location_id].has("pois"):
		location_data[location_id]["pois"] = {}
	
	# Dodaj POI do danych lokacji
	location_data[location_id]["pois"][poi_id] = {
		"position": back_pos,
		"type": poi_type
	}

# Rejestruje portal
func register_portal(location_id: String, portal_id: String, front_pos: Vector3, target_location: String, target_portal: String):
	# Upewnij się, że lokacja istnieje
	if not location_data.has(location_id):
		push_error("Location ID '" + location_id + "' not found in location_data")
		return
		
	# Upewnij się, że słownik portali istnieje
	if not location_data[location_id].has("portals"):
		location_data[location_id]["portals"] = {}
	
	# Dodaj portal do danych lokacji
	location_data[location_id]["portals"][portal_id] = {
		"front_pos": front_pos,
		"target_location": target_location,
		"target_portal": target_portal
	}

# Rejestruje marker zmiany lokacji
func register_location_change_marker(location_id: String, marker_id: String, back_pos: Vector2, target_location: String, spawn_point_id: String):
	# Upewnij się, że lokacja istnieje
	if not location_data.has(location_id):
		push_error("Location ID '" + location_id + "' not found in location_data")
		return
		
	# Upewnij się, że słownik markerów istnieje
	if not location_data[location_id].has("location_change_markers"):
		location_data[location_id]["location_change_markers"] = {}
	
	# Dodaj marker do danych lokacji
	location_data[location_id]["location_change_markers"][marker_id] = {
		"position": back_pos,
		"target_location": target_location,
		"spawn_point_id": spawn_point_id
	}

# Rejestruje punkt spawnu
func register_spawn_point(location_id: String, spawn_id: String, front_pos: Vector3):
	# Upewnij się, że lokacja istnieje
	if not location_data.has(location_id):
		push_error("Location ID '" + location_id + "' not found in location_data")
		return
		
	# Upewnij się, że słownik punktów spawnu istnieje
	if not location_data[location_id].has("spawn_points"):
		location_data[location_id]["spawn_points"] = {}
	
	# Dodaj punkt spawnu do danych lokacji
	location_data[location_id]["spawn_points"][spawn_id] = front_pos
	
# Tłumaczy z trybu front (3D) na tryb back (2D)
func front_to_back(location_id: String, front_pos: Vector3) -> Vector2:
	# Sprawdzenie bezpieczeństwa: Upewnij się, że location_id istnieje w naszych danych
	if not location_data.has(location_id):
		push_error("Location ID '" + location_id + "' not found in location_data")
		return Vector2.ZERO
		
	var location = location_data[location_id]
	var scale_factor = location["scale_factor"]
	
	# Konwertuj pozycję front na pozycję back
	# Ignorujemy Y (wysokość) z pozycji 3D
	var relative_pos = Vector2(front_pos.x / scale_factor.x, front_pos.z / scale_factor.y)
	
	# Dodaj offset pozycji na mapie strategicznej
	return location["world_pos"] + relative_pos

# Tłumaczy z trybu back (2D) na tryb front (3D)
func back_to_front(location_id: String, back_pos: Vector2) -> Vector3:
	# Sprawdzenie bezpieczeństwa: Upewnij się, że location_id istnieje w naszych danych
	if not location_data.has(location_id):
		push_error("Location ID '" + location_id + "' not found in location_data")
		return Vector3(0, 2, 0)
		
	var location = location_data[location_id]
	var scale_factor = location["scale_factor"]
	
	# Uzyskaj lokalne koordynaty w trybie back
	var local_back_pos = back_pos - location["world_pos"]
	
	# Konwertuj na koordynaty trybu front
	# Y (wysokość) jest ustawiona na 0, ale powinna być dostosowana na podstawie terenu
	return Vector3(
		local_back_pos.x * scale_factor.x,
		0,  # Poziom ziemi, powinien być dostosowany na podstawie wysokości terenu
		local_back_pos.y * scale_factor.y
	)
	
	# Pobierz pozycję docelową podczas przechodzenia przez portal
func get_portal_target_position(from_location: String, portal_id: String) -> Dictionary:
	# Sprawdzenie bezpieczeństwa: Upewnij się, że lokacja istnieje
	if not location_data.has(from_location):
		push_error("Location ID '" + from_location + "' not found in location_data")
		return {"location": "", "position": Vector3.ZERO}
		
	# Sprawdzenie bezpieczeństwa: Upewnij się, że portal istnieje
	if not location_data[from_location].has("portals") or not location_data[from_location]["portals"].has(portal_id):
		push_error("Portal ID '" + portal_id + "' not found in location '" + from_location + "'")
		return {"location": "", "position": Vector3.ZERO}
	
	var portal_data = location_data[from_location]["portals"][portal_id]
	var target_location = portal_data["target_location"]
	var target_portal = portal_data["target_portal"]
	
	# Sprawdzenie bezpieczeństwa: Upewnij się, że docelowa lokacja i portal istnieją
	if not location_data.has(target_location) or not location_data[target_location]["portals"].has(target_portal):
		push_error("Target location/portal not found: " + target_location + "/" + target_portal)
		return {"location": target_location, "position": Vector3.ZERO}
	
	var target_pos = location_data[target_location]["portals"][target_portal]["front_pos"]
	
	# Dodaj losowy offset, aby zapobiec zapętleniu teleportacji
	var random_angle = randf() * 2.0 * PI  # Losowy kąt w radianach
	var random_distance = randf_range(2.0, 5.0)  # Losowa odległość między 2 a 5 jednostek
	var offset = Vector3(
		cos(random_angle) * random_distance,
		0.0,  # Zachowaj tę samą wysokość
		sin(random_angle) * random_distance
	)
	
	# Zastosuj offset do pozycji docelowej
	var offset_target_pos = target_pos + offset
	
	return {
		"location": target_location,
		"position": offset_target_pos
	}

# Sprawdź czy pozycja w trybie back jest w granicach lokacji
func is_within_location(location_id: String, back_pos: Vector2) -> bool:
	# Sprawdzenie bezpieczeństwa: Upewnij się, że lokacja istnieje
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

# Znajdź w której lokacji znajduje się pozycja w trybie back
func get_location_at_position(back_pos: Vector2) -> String:
	for location_id in location_data:
		if is_within_location(location_id, back_pos):
			return location_id
	
	return ""  # Nie znaleziono lokacji
	
# Pobierz pozycje POI w lokacji (koordynaty trybu back)
func get_poi_positions(location_id: String) -> Dictionary:
	# Sprawdzenie bezpieczeństwa: Upewnij się, że lokacja istnieje
	if not location_data.has(location_id):
		push_error("Location ID '" + location_id + "' not found in location_data")
		return {}
		
	# Sprawdzenie bezpieczeństwa: Upewnij się, że lokacja ma POI
	if not location_data[location_id].has("pois"):
		push_error("No POIs found in location '" + location_id + "'")
		return {}
	
	# Konwertuj strukturę POI do formatu tylko z pozycjami (dla kompatybilności)
	var result = {}
	for poi_id in location_data[location_id]["pois"]:
		result[poi_id] = location_data[location_id]["pois"][poi_id]["position"]
		
	return result

# Pobierz pozycje POI w koordynatach trybu front
func get_front_poi_position(location_id: String, poi_id: String) -> Vector3:
	# Sprawdzenie bezpieczeństwa: Upewnij się, że lokacja istnieje
	if not location_data.has(location_id):
		push_error("Location ID '" + location_id + "' not found in location_data")
		return Vector3.ZERO
		
	# Sprawdzenie bezpieczeństwa: Upewnij się, że lokacja ma POI i że to konkretne POI istnieje
	if not location_data[location_id].has("pois") or not location_data[location_id]["pois"].has(poi_id):
		push_error("POI ID '" + poi_id + "' not found in location '" + location_id + "'")
		return Vector3.ZERO
	
	var back_pos = location_data[location_id]["pois"][poi_id]["position"]
	return back_to_front(location_id, back_pos)
