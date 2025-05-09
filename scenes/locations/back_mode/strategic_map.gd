extends Control
class_name StrategicMap

# Referencje
var coord_translator: CoordTranslator
var player
var poi_manager: POIManager
var npc_manager: NPCManager

# Elementy UI
var map_container: Panel
var location_rects = {}
var player_marker: ColorRect
var poi_markers = {}  # Słownik do przechowywania markerów POI według ID
var npc_markers = {}  # Dictionary to store NPC markers by ID

# Nawigacja po mapie
var map_drag_active = false
var map_drag_start_pos = Vector2.ZERO
var map_offset = Vector2(0, 0)  # Początkowy offset
var map_zoom = 1.0
var min_zoom = 0.5
var max_zoom = 3.0
var zoom_step = 0.1
var map_content: Control  # Kontener dla elementów mapy

func _ready():
	# Pobierz referencje do systemów
	coord_translator = get_node("/root/World/Systems/CoordTranslator")
	poi_manager = get_node("/root/World/Systems/POIManager")
	player = get_node_or_null("/root/World/Player")
	
	# Utwórz layout UI
	setup_ui()
	
	# Znajdź i zarejestruj wszystkie markery lokacji
	gather_location_markers()
	
	gather_location_connectors()
	
	# Utwórz granice lokacji na podstawie danych z CoordTranslator
	setup_locations()
	
	# Zarejestruj POI ze sceny
	register_and_correct_scene_pois()
	
	# Utwórz marker gracza
	setup_player_marker()
	
	await get_tree().create_timer(0.5).timeout
	npc_manager = get_node_or_null("/root/World/Systems/NPCManager")
	
	if npc_manager:
		print("StrategicMap: Connecting to NPC Manager")
		# Connect to signals
		if not npc_manager.is_connected("npc_position_changed", _on_npc_position_changed):
			npc_manager.npc_position_changed.connect(_on_npc_position_changed)
		if not npc_manager.is_connected("npc_state_changed", _on_npc_state_changed):
			npc_manager.npc_state_changed.connect(_on_npc_state_changed)
		
		await get_tree().create_timer(0.5).timeout
		# Display all NPCs
		display_all_npcs()
	else:
		push_error("StrategicMap: NPC Manager not found!")
		
		
func gather_location_connectors():
	# Find all connector markers
	var connector_markers = get_tree().get_nodes_in_group("location_connectors")
	
	print("Found " + str(connector_markers.size()) + " location connector markers")
	
	var connectors_data = []
	
	for marker in connector_markers:
		if marker is LocationConnectorMarker:
			var connector_data = marker.get_connector_data()
			connectors_data.append(connector_data)
			
			# Add line on map
			var line = Line2D.new()
			line.width = 2.0
			line.default_color = marker.color
			line.add_point(marker.position)
			# Will add second point when second location marker is registered
			map_content.add_child(line)
			
			print("Registered connector: " + connector_data["connector_id"])
			
			# Can remove marker from scene as data is saved
			marker.queue_free()
	
	# Get connector manager and register connectors
	var connector_manager = get_node_or_null("/root/World/Systems/ConnectorManager")
	if connector_manager:
		connector_manager.register_scene_connectors(connectors_data)
	else:
		push_error("ConnectorManager not found!")
		
# Display all NPCs
func display_all_npcs():
	print("StrategicMap: Displaying all NPCs")
	
	# Clear existing markers
	for marker in npc_markers.values():
		marker.queue_free()
	npc_markers.clear()
	
	# Add marker for each NPC
	for npc_id in npc_manager.all_npcs:
		var npc = npc_manager.all_npcs[npc_id]
		create_npc_marker(npc)
	
	print("StrategicMap: Added " + str(npc_markers.size()) + " NPC markers")
	
# Create a marker for an NPC
func create_npc_marker(npc: NPCResource):
	# Create marker scene
	var marker_scene = load("res://scenes/map/npc_marker.tscn")
	var marker = marker_scene.instantiate()
	marker.npc_id = npc.npc_id
	marker.color = npc.color
	marker.faction = npc.faction
	marker.position = npc.world_position
	
	# If NPC is moving, show path
	if npc.state == "moving" and not npc.target_poi_id.is_empty():
		var target_poi = poi_manager.get_poi(npc.target_poi_id)
		if target_poi:
			marker.update_path(true, target_poi.world_position)
	
	# Add to map
	map_content.add_child(marker)
	npc_markers[npc.npc_id] = marker
	
	print("StrategicMap: Created marker for " + npc.npc_id + " at " + str(npc.world_position))
	return marker
	
# Display a single NPC on the map
func display_npc(npc: NPCResource):
	print("StrategicMap: Displaying NPC " + npc.npc_id + " at position " + str(npc.world_position))
	
	# Create simple colored rectangle for NPC
	var npc_marker = ColorRect.new()
	npc_marker.color = npc.color
	npc_marker.size = Vector2(8, 8)
	npc_marker.position = npc.world_position - Vector2(4, 4)  # Center marker
	map_content.add_child(npc_marker)
	
	# Add label
	var label = Label.new()
	label.text = npc.npc_id
	label.position = Vector2(10, -10)
	label.add_theme_color_override("font_color", npc.color)
	npc_marker.add_child(label)
	
	# Add path line for moving NPCs with a delay to ensure it's created properly
	if npc.state == "moving" and not npc.target_poi_id.is_empty():
		var target_poi = poi_manager.get_poi(npc.target_poi_id)
		if target_poi:
			# Create path line
			var path_line = Line2D.new()
			path_line.name = "PathLine"
			path_line.width = 1.0
			path_line.default_color = npc.color
			path_line.default_color.a = 0.5  # Semi-transparent
			npc_marker.add_child(path_line)
			
			# Wait a frame to make sure everything is set up
			await get_tree().process_frame
			
			# Now add points
			path_line.add_point(Vector2(4, 4))  # Center of marker
			path_line.add_point(target_poi.world_position - npc.world_position + Vector2(4, 4))
	
	# Save reference
	npc_markers[npc.npc_id] = npc_marker
	
	print("StrategicMap: Created marker for " + npc.npc_id)

# Handle NPC position change
func _on_npc_position_changed(npc_id, new_position):
	if npc_markers.has(npc_id):
		var marker = npc_markers[npc_id]
		marker.position = new_position
		
		# Update path if moving
		var npc = npc_manager.get_npc(npc_id)
		if npc and npc.state == "moving" and not npc.target_poi_id.is_empty():
			var target_poi = poi_manager.get_poi(npc.target_poi_id)
			if target_poi:
				marker.update_path(true, target_poi.world_position)

# Handle NPC state change
func _on_npc_state_changed(npc_id, new_state):
	if npc_markers.has(npc_id):
		var marker = npc_markers[npc_id]
		var npc = npc_manager.get_npc(npc_id)
		
		if not npc:
			return
			
		if new_state == "moving" and not npc.target_poi_id.is_empty():
			var target_poi = poi_manager.get_poi(npc.target_poi_id)
			if target_poi:
				marker.update_path(true, target_poi.world_position)
		else:
			marker.update_path(false)

# Handle NPC registration
func _on_npc_registered(_npc_id):
	# Refresh all NPCs display
	display_all_npcs()
	
func gather_location_markers():
	# Znajdź wszystkie markery lokacji
	var location_markers = get_tree().get_nodes_in_group("location_markers")
	
	print("Znaleziono " + str(location_markers.size()) + " markery lokacji")
	
	for marker in location_markers:
		if marker is LocationMarker:
			var loc_data = marker.get_location_data()
			
			# Zarejestruj lokację w CoordTranslator
			var formatted_data = {
				"world_pos": loc_data["position"],
				"size": loc_data["size"],
				"scale_factor": loc_data["scale_factor"],
				"color": loc_data["color"]  # Dodajemy kolor
			}
			
			coord_translator.register_location(loc_data["location_id"], formatted_data)
			print("Zarejestrowano lokację: " + loc_data["location_id"] + " z markera")
			
			# Możemy usunąć marker, ponieważ nie jest już potrzebny
			marker.queue_free()
			
# Nowa funkcja rejestrująca POI ze sceny i korygująca ich pozycje
func register_and_correct_scene_pois():
	# Znajdź wszystkie markery POI
	var scene_markers = get_tree().get_nodes_in_group("poi_markers")
	var poi_resources = []
	
	print("Znaleziono " + str(scene_markers.size()) + " markery POI w scenie")
	
	for marker in scene_markers:
		if marker is POIMarker:
			# Zapisz aktualną pozycję markera przed przeniesieniem
			var original_position = marker.global_position
			
			# Przenieś marker pod map_content jeśli jeszcze tam nie jest
			if marker.get_parent() != map_content:
				marker.get_parent().remove_child(marker)
				map_content.add_child(marker)
				
				# WAŻNE: Ustaw właściwą pozycję, która powinna być w koordynatach mapy
				# To jest prawdziwa pozycja POI w świecie gry, a nie w UI
				marker.position = original_position
				print("Przeniesiono marker " + marker.name + " pod map_content, pozycja: " + str(marker.position))
			
			# Zapisz referencję w słowniku poi_markers
			poi_markers[marker.poi_id] = marker
			
			# Połącz sygnał kliknięcia
			if not marker.is_connected("clicked", _on_poi_marker_clicked):
				marker.clicked.connect(_on_poi_marker_clicked.bind(marker))
			
			# Utwórz zasób POI dla tego markera
			poi_resources.append(marker.to_poi_resource())
	
	# Zarejestruj POI w menedżerze POI
	poi_manager.register_scene_pois(poi_resources)
				
# Zaktualizuj funkcję register_scene_pois:
func register_scene_pois():
	# Znajdź wszystkie markery POI w scenie
	var poi_markers_nodes = []
	
	# Szukaj tylko bezpośrednich dzieci węzła map_content, które są w grupie "poi_markers"
	for child in map_content.get_children():
		if child.is_in_group("poi_markers"):
			poi_markers_nodes.append(child)
	
	# Jeśli nie znaleziono markerów, to szukaj w całym drzewie sceny
	if poi_markers_nodes.is_empty():
		poi_markers_nodes = get_tree().get_nodes_in_group("poi_markers")
		
		# Jeśli znaleziono markery, ale nie są one dziećmi map_content, przenieś je
		for marker in poi_markers_nodes:
			if marker.get_parent() != map_content:
				marker.get_parent().remove_child(marker)
				map_content.add_child(marker)
				print("Przeniesiono marker POI do map_content: " + marker.name)
	
	# Zarejestruj markery w menedżerze POI
	poi_manager.register_scene_pois(poi_markers_nodes)
	
	# Połącz sygnały z markerami
	for marker in poi_markers_nodes:
		if marker is POIMarker and not marker.is_connected("clicked", _on_poi_marker_clicked):
			marker.clicked.connect(_on_poi_marker_clicked.bind(marker))
	
	print("Zarejestrowano " + str(poi_markers_nodes.size()) + " markery POI ze sceny")

# Obsługa kliknięcia w marker POI
func _on_poi_marker_clicked(marker: POIMarker):
	# Przykładowa akcja - możesz tu dodać więcej, np. wyświetlanie informacji o POI
	print("Kliknięto marker POI: " + marker.poi_id)
	
	# Opcjonalnie: przełącz stan aktywności POI przy kliknięciu
	var poi = poi_manager.get_poi(marker.poi_id)
	if poi:
		poi_manager.set_poi_active(marker.poi_id, !poi.is_active)

# Obsługa zmiany stanu POI
func _on_poi_state_changed(poi_id: String, is_active: bool):
	# Zaktualizuj wygląd markera na mapie
	if poi_markers.has(poi_id):
		var marker = poi_markers[poi_id]
		marker.modulate.a = 1.0 if is_active else 0.3
		
func _process(_delta):
	# Aktualizuj pozycję gracza na mapie
	if player_marker != null:
		update_player_position()

# Obsługa wejścia dla nawigacji po mapie
func _input(event):
	if not visible:
		return
		
	# Kółko myszy do przybliżania/oddalania
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_map(zoom_step)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_map(-zoom_step)
			get_viewport().set_input_as_handled()
		# Rozpoczęcie przeciągania lewym przyciskiem myszy
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				map_drag_active = true
				map_drag_start_pos = event.position
			else:
				map_drag_active = false
	
	# Obsługa przeciągania mapy
	if event is InputEventMouseMotion and map_drag_active:
		var drag_delta = event.position - map_drag_start_pos
		map_offset += drag_delta
		map_drag_start_pos = event.position
		update_map_transform()
		get_viewport().set_input_as_handled()
		
	# Skróty klawiaturowe
	if event is InputEventKey and event.pressed:
		# Centruj na graczu klawiszem C
		if event.keycode == KEY_C:
			center_on_player()

# Przybliż mapę o określoną wartość
func zoom_map(amount):
	var old_zoom = map_zoom
	map_zoom = clamp(map_zoom + amount, min_zoom, max_zoom)
	
	if map_zoom != old_zoom:
		# Pobierz pozycję myszy
		var mouse_pos = get_viewport().get_mouse_position()
		
		# Oblicz środek przybliżenia (względem map_content)
		var zoom_center = mouse_pos - map_content.global_position
		
		# Dostosuj offset na podstawie środka przybliżenia
		var zoom_factor = map_zoom / old_zoom
		var new_offset = zoom_center - (zoom_center - map_offset) * zoom_factor
		map_offset = new_offset
		
		update_map_transform()

# Aktualizuj transformację mapy na podstawie offsetu i przybliżenia
func update_map_transform():
	map_content.position = map_offset
	map_content.scale = Vector2(map_zoom, map_zoom)

# Utwórz layout UI
func setup_ui():
	# Ustaw na pełny ekran
	anchor_right = 1.0
	anchor_bottom = 1.0
	
	# Utwórz kontener dla mapy
	map_container = Panel.new()
	map_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_container.anchor_right = 1.0
	map_container.anchor_bottom = 1.0
	
	# Ustaw półprzezroczyste ciemne tło
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.1, 0.15, 0.9)  # Ciemnoniebieskawe tło
	map_container.add_theme_stylebox_override("panel", style_box)
	
	add_child(map_container)
	
	# Utwórz kontener dla zawartości mapy
	map_content = Control.new()
	map_content.name = "MapContent"
	map_content.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Przekazuj zdarzenia myszy do rodzica
	map_content.position = map_offset
	map_container.add_child(map_content)
	
	# Dodaj tytuł
	var title = Label.new()
	title.text = "Mapa Strategiczna (M aby przełączyć)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 10
	title.offset_bottom = 40
	title.add_theme_font_size_override("font_size", 24)
	map_container.add_child(title)
	
	# Dodaj tekst pomocy
	var help_text = Label.new() 
	help_text.text = "Przeciąganie: Lewy przycisk myszy | Przybliżanie: Kółko myszy | Centruj na graczu: C"
	help_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help_text.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	help_text.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	help_text.offset_bottom = -10
	help_text.offset_top = -40
	map_container.add_child(help_text)

# Utwórz granice lokacji
func setup_locations():
	# Pobierz dane lokacji od tłumacza
	var locations = coord_translator.location_data
	
	# Utwórz prostokąt dla każdej lokacji
	for location_id in locations:
		var location = locations[location_id]
		var world_pos = location["world_pos"]
		var size = location["size"]
		
		# Utwórz prostokąt
		var rect = ColorRect.new()
		
		# Użyj koloru z danych lokacji (lub domyślnego, jeśli nie zdefiniowano)
		if location.has("color"):
			rect.color = location["color"]
		else:
			rect.color = Color(0.3, 0.3, 0.3, 0.5)  # Domyślny półprzezroczysty szary
		
		# Ustaw pozycję i rozmiar
		rect.position = world_pos
		rect.size = size
		
		map_content.add_child(rect)
		
		# Zapisz referencję
		location_rects[location_id] = rect
		
		# Dodaj etykietę dla lokacji
		var label = Label.new()
		label.text = location_id
		label.position = Vector2(10, 10)
		label.add_theme_color_override("font_color", Color(1, 1, 1))
		rect.add_child(label)

# Wyświetl wszystkie POI na mapie
func display_all_pois():
	# Wyczyść istniejące markery POI
	for marker in poi_markers.values():
		marker.queue_free()
	poi_markers.clear()
	
	# Pobierz wszystkie POI z menedżera POI
	var all_pois = poi_manager.get_all_pois()
	
	# Wyświetl każde POI
	for poi_id in all_pois:
		var poi = all_pois[poi_id]
		display_poi(poi)

# Wyświetl pojedyncze POI na mapie
func display_poi(poi: POIResource):
	# Utwórz marker dla POI
	var poi_marker = create_poi_marker(poi)
	poi_marker.position = poi.world_position - poi_marker.size / 2
	map_content.add_child(poi_marker)
	
	# Zapisz referencję do markera
	poi_markers[poi.poi_id] = poi_marker
	
	# Ustaw widoczność w zależności od stanu aktywności
	update_poi_visibility(poi)

# Utwórz wizualny marker dla POI
func create_poi_marker(poi: POIResource) -> Control:
	# Utwórz kontener dla markera POI
	var marker_container = Control.new()
	marker_container.size = Vector2(20, 20)
	marker_container.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Przekazuj zdarzenia myszy
	
	# Utwórz kolorowy marker na podstawie typu POI
	var marker = ColorRect.new()
	marker.color = poi.color
	marker.size = Vector2(12, 12)
	marker.position = Vector2(4, 4)  # Wyśrodkuj w kontenerze
	marker_container.add_child(marker)
	
	# Dodaj etykietę
	var label = Label.new()
	label.text = poi.poi_id
	label.position = Vector2(15, 0)
	label.add_theme_color_override("font_color", poi.color)
	label.add_theme_font_size_override("font_size", 14)
	marker_container.add_child(label)
	
	# Dodaj efekt pulsowania
	var animation = AnimationPlayer.new()
	marker_container.add_child(animation)
	
	var anim = Animation.new()
	var track_idx = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track_idx, "../ColorRect:scale")
	anim.track_insert_key(track_idx, 0.0, Vector2(1, 1))
	anim.track_insert_key(track_idx, 0.5, Vector2(1.2, 1.2))
	anim.track_insert_key(track_idx, 1.0, Vector2(1, 1))
	anim.loop_mode = Animation.LOOP_LINEAR
	
	var anim_lib = AnimationLibrary.new()
	anim_lib.add_animation("pulse", anim)
	animation.add_animation_library("poi_anims", anim_lib)
	animation.play("poi_anims/pulse")
	
	return marker_container

# Aktualizuj widoczność POI na podstawie jego stanu aktywności
func update_poi_visibility(poi: POIResource):
	if poi_markers.has(poi.poi_id):
		var marker = poi_markers[poi.poi_id]
		marker.modulate.a = 1.0 if poi.is_active else 0.3  # Nieaktywne POI są półprzezroczyste

# Utwórz marker gracza
func setup_player_marker():
	player_marker = ColorRect.new()
	player_marker.color = Color(0, 0.8, 0.2)  # Zielony dla gracza
	player_marker.size = Vector2(15, 15)
	player_marker.pivot_offset = player_marker.size / 2
	map_content.add_child(player_marker)
	
	# Dodaj etykietę gracza
	var label = Label.new()
	label.text = "Gracz"
	label.position = Vector2(player_marker.size.x + 5, -5)
	label.add_theme_color_override("font_color", Color(0, 1, 0.2))
	player_marker.add_child(label)
	
	# Aktualizuj początkową pozycję
	update_player_position()
	
# Dodaj funkcję do aktualizacji referencji do gracza
func set_player(player_node: Node3D):
	player = player_node
	print("StrategicMap: Zaktualizowano referencję do gracza")
	# Zaktualizuj pozycję markera, jeśli już istnieje
	if player_marker != null:
		update_player_position()
		
# Aktualizuj pozycję markera gracza na mapie
func update_player_position():
	if player_marker == null or player == null:
		return

	# Pobierz pozycję gracza w 3D
	var player_pos = player.global_position
	
	# Pobierz aktualną lokację
	var current_location = get_current_location()
	
	# Konwertuj na pozycję na mapie
	var back_pos = coord_translator.front_to_back(current_location, player_pos)
	
	# Aktualizuj pozycję markera
	player_marker.position = back_pos - player_marker.size / 2

# Centruj mapę na graczu
func center_on_player():
	if player_marker == null:
		return
		
	# Oblicz pozycję gracza w koordynatach mapy
	var player_pos = player.global_position
	var current_location = get_current_location()
	var back_pos = coord_translator.front_to_back(current_location, player_pos)
	
	# Oblicz offset do wycentrowania gracza w widoku
	var viewport_size = get_viewport_rect().size
	map_offset = viewport_size / 2 - back_pos * map_zoom
	
	# Aktualizuj transformację mapy
	update_map_transform()

# Pobierz aktualną lokację z menedżera świata
func get_current_location() -> String:
	var world = get_node("/root/World")
	return world.current_location_id
