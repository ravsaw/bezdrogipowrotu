# scripts/systems/poi_manager.gd
extends Node
class_name POIManager

# Kolekcja wszystkich POI w świecie gry
var all_pois = {}  # Dictionary of POIResource by ID

# Sygnały
signal poi_state_changed(poi_id, is_active)
signal poi_manager_ready  # Dodany nowy sygnał
signal pois_registered  # Dodaj ten brakujący sygnał!

func _ready():
	# Poczekaj na klatkę, aby zapewnić, że węzeł jest w pełni inicjalizowany
	await get_tree().process_frame
	
	# Powiadom wszystkich, że POI Manager jest gotowy
	emit_signal("poi_manager_ready")
	print("POI Manager gotowy - zarejestrowano " + str(all_pois.size()) + " POI")

# Rejestruj POI markery z sceny strategic_map
func register_scene_pois(pois_array: Array):
	print("Rejestrowanie danych POI...")
	
	for poi_resource in pois_array:
		if poi_resource is POIResource:
			all_pois[poi_resource.poi_id] = poi_resource
			print("Zarejestrowano dane POI: " + poi_resource.poi_id + " na pozycji: " + str(poi_resource.world_position))
	
	print("Zarejestrowano łącznie " + str(all_pois.size()) + " zasobów POI")
	
	# Wyemituj sygnał po rejestracji POI
	emit_signal("pois_registered")

# Pobierz POI po ID
func get_poi(poi_id: String) -> POIResource:
	if all_pois.has(poi_id):
		return all_pois[poi_id]
	return null

# Pobierz wszystkie POI
func get_all_pois() -> Dictionary:
	return all_pois

# Pobierz wszystkie POI w danym prostokącie (np. dla lokacji)
func get_pois_in_rect(rect_pos: Vector2, rect_size: Vector2) -> Array:
	var result = []
	
	for poi_id in all_pois:
		var poi = all_pois[poi_id]
		if is_poi_in_rect(poi, rect_pos, rect_size):
			result.append(poi)
			print("POI w granicach lokacji: " + poi_id + " na pozycji: " + str(poi.world_position) + 
				" (granice: " + str(rect_pos) + " do " + str(rect_pos + rect_size) + ")")
	
	print("Znaleziono " + str(result.size()) + " POI w prostokącie: " + str(rect_pos) + ", " + str(rect_size))
	return result

# Sprawdź czy POI jest w danym prostokącie
func is_poi_in_rect(poi: POIResource, rect_pos: Vector2, rect_size: Vector2) -> bool:
	var poi_pos = poi.world_position
	var is_within = (
		poi_pos.x >= rect_pos.x and
		poi_pos.x < rect_pos.x + rect_size.x and
		poi_pos.y >= rect_pos.y and
		poi_pos.y < rect_pos.y + rect_size.y
	)
	
	if is_within:
		print("POI " + poi.poi_id + " jest wewnątrz prostokąta!")
	
	return is_within

# Ustaw stan aktywności POI
func set_poi_active(poi_id: String, active: bool):
	if all_pois.has(poi_id):
		if all_pois[poi_id].is_active != active:
			all_pois[poi_id].is_active = active
			emit_signal("poi_state_changed", poi_id, active)
			print("POI " + poi_id + " jest teraz " + ("aktywne" if active else "nieaktywne"))
