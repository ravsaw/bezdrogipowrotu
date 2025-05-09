extends Node3D
class_name Location

@export var location_id: String = "location1"

# Referencje systemowe
var coord_translator: CoordTranslator
var poi_manager: POIManager
var world_manager: WorldManager

# Kontenery
var poi_container: Node3D
var poi_instances = {} # Słownik instancji POI w tej lokacji

func _ready():
		# Pobierz referencje systemowe
	coord_translator = get_node("/root/World/Systems/CoordTranslator")
	poi_manager = get_node("/root/World/Systems/POIManager")
	world_manager = get_node("/root/World")
	
	# Utwórz kontener na POI
	poi_container = Node3D.new()
	poi_container.name = "POIs"
	add_child(poi_container)
	
	# Poczekaj, aż POI Manager będzie gotowy
	if poi_manager:
		# Połącz z sygnałami
		poi_manager.poi_state_changed.connect(_on_poi_state_changed)
		
		# Nowa logika: Sprawdź czy są POI i połącz z nowym sygnałem
		if not poi_manager.all_pois.is_empty():
			print("POI Manager już ma zarejestrowane POI - ładuję...")
			load_pois_from_manager()
		else:
			# Czekaj na sygnał zarejestrowania POI
			print("Czekam na zarejestrowanie POI...")
			poi_manager.pois_registered.connect(_on_pois_registered, CONNECT_ONE_SHOT)
	else:
		push_error("Nie można załadować POI - brak POI Managera!")

# Nowa funkcja do obsługi sygnału rejestracji POI
func _on_pois_registered():
	print("Sygnał rejestracji POI odebrany przez lokację " + location_id)
	load_pois_from_manager()
	
# Obsługa sygnału gotowości POI Managera
func _on_poi_manager_ready():
	print("Sygnał gotowości POI Managera odebrany przez lokację " + location_id)
	load_pois_from_manager()

# Załaduj POI z menedżera POI
func load_pois_from_manager():
	if not poi_manager:
		push_error("POIManager not found - nie można załadować POI dla lokacji " + location_id)
		return
	
	# Pobierz dane lokacji z CoordTranslator
	var location_data = coord_translator.location_data[location_id]
	var strategic_map_position = location_data["world_pos"]
	var strategic_map_size = location_data["size"]
	
	print("Ładowanie POI dla lokacji " + location_id + " o granicach " + 
		str(strategic_map_position) + " do " + str(strategic_map_position + strategic_map_size))
	
	# Pobierz wszystkie POI w granicach tej lokacji
	var location_pois = poi_manager.get_pois_in_rect(strategic_map_position, strategic_map_size)
	
	for poi in location_pois:
		create_poi_instance(poi)
	
	print("Załadowano " + str(location_pois.size()) + " POI dla lokacji " + location_id)

# Utwórz instancję POI w świecie 3D
func create_poi_instance(poi: POIResource):
	# Konwertuj pozycję mapy strategicznej na pozycję 3D
	var pos_3d = coord_translator.back_to_front(location_id, poi.world_position)
	
	# Utwórz sferę dla POI
	var poi_node = create_poi_sphere(poi)
	poi_node.position = pos_3d
	poi_container.add_child(poi_node)
	
	# Zapisz referencję
	poi_instances[poi.poi_id] = poi_node
	
	# Ustaw widoczność na podstawie stanu aktywności
	update_poi_visibility(poi)
	
	print("Utworzono instancję POI: " + poi.poi_id + " na pozycji 3D: " + str(pos_3d) + 
		  " (z pozycji na mapie: " + str(poi.world_position) + ")")
	
	return poi_node


# Utwórz sferę reprezentującą POI
func create_poi_sphere(poi: POIResource) -> Node3D:
	var poi_node = Node3D.new()
	poi_node.name = poi.poi_id
	
	# Utwórz meshInstance dla sfery
	var mesh_instance = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	
	# Większy promień dla lepszej widoczności
	var bigger_radius = poi.radius * 1.0  # 10x większy promień
	sphere_mesh.radius = bigger_radius
	sphere_mesh.height = bigger_radius * 2.0
	
	mesh_instance.mesh = sphere_mesh
	poi_node.add_child(mesh_instance)
	
	# Dodaj materiał z kolorem POI
	var material = StandardMaterial3D.new()
	material.albedo_color = poi.color
	material.emission_enabled = true
	material.emission = poi.color
	material.emission_energy = 1.0  # Zwiększ emisję dla lepszej widoczności
	mesh_instance.material_override = material
	
	# Dodaj etykietę
	var label = Label3D.new()
	label.text = poi.poi_id + "\n" + poi.poi_type
	label.position = Vector3(0, bigger_radius + 5.0, 0)
	label.font_size = 200  # Większa czcionka
	label.outline_size = 10
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	poi_node.add_child(label)
	
	return poi_node

# Aktualizuj widoczność POI na podstawie jego stanu aktywności
func update_poi_visibility(poi: POIResource):
	if poi_instances.has(poi.poi_id):
		var poi_node = poi_instances[poi.poi_id]
		
		# Można ustawić widoczność całego węzła
		# poi_node.visible = poi.is_active
		
		# Lub ustawić przezroczystość materiału (subtelniejszy efekt)
		var mesh_instance = poi_node.get_child(0) as MeshInstance3D
		if mesh_instance and mesh_instance.material_override:
			var material = mesh_instance.material_override as StandardMaterial3D
			material.albedo_color.a = 1.0 if poi.is_active else 0.3

# Obsługa zmiany stanu POI
func _on_poi_state_changed(poi_id: String, is_active: bool):
	# Jeśli mamy takie POI w tej lokacji, zaktualizuj jego widoczność
	if poi_instances.has(poi_id):
		var poi = poi_manager.get_poi(poi_id)
		if poi:
			update_poi_visibility(poi)

# Zwolnij zasoby przy usunięciu lokacji
func _exit_tree():
	# Usuń śledzenie POI
	poi_instances.clear()
	
	# Odłącz sygnały
	if poi_manager:
		if poi_manager.is_connected("poi_state_changed", _on_poi_state_changed):
			poi_manager.poi_state_changed.disconnect(_on_poi_state_changed)
		if poi_manager.is_connected("poi_manager_ready", _on_poi_manager_ready):
			poi_manager.poi_manager_ready.disconnect(_on_poi_manager_ready)
		if poi_manager.is_connected("pois_registered", _on_pois_registered):
			poi_manager.pois_registered.disconnect(_on_pois_registered)
		
