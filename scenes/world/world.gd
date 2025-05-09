extends Node3D
class_name WorldManager

# Sceny lokacji
var location_scenes = {
	"location1": preload("res://scenes/locations/front_mode/location1.tscn"),
	"location2": preload("res://scenes/locations/front_mode/location2.tscn"),
}

# Referencje
var coord_translator: CoordTranslator
var poi_manager: POIManager
var player
var strategic_map

# Aktualny stan
var current_location_id: String = "location1"
var current_location: Node3D

# Węzły
var locations_container: Node3D
var systems_container: Node
var ui_container: Control

signal location_changed(location_id)

func _ready():
	# Utwórz kontenery do organizacji
	locations_container = Node3D.new()
	locations_container.name = "Locations"
	add_child(locations_container)
	
	systems_container = Node.new()
	systems_container.name = "Systems"
	add_child(systems_container)
	
	ui_container = Control.new()
	ui_container.name = "UI"
	add_child(ui_container)
	
	# ETAP 1: Inicjalizuj wszystkie systemy
	initialize_systems()
	
	# ETAP 2: Skonfiguruj mapę strategiczną (zarejestruje POI)
	setup_strategic_map()
	
	# ETAP 3: Załaduj lokacje
	load_location(current_location_id)
	
	# ETAP 4: Skonfiguruj gracza
	setup_player()
	
	# ETAP 5: Połącz wszystkie systemy
	connect_systems()
	
# Nowa funkcja do łączenia systemów
func connect_systems():
	# Przekaż referencję do gracza do mapy strategicznej
	if strategic_map and player:
		strategic_map.set_player(player)
	
	# Connect NPCManager to other systems
	var npc_manager = get_node_or_null("Systems/NPCManager")
	if npc_manager:
		npc_manager.world_manager = self
		npc_manager.coord_translator = coord_translator
		npc_manager.poi_manager = poi_manager
		npc_manager.player = player
		
		# Connect to location_changed signal
		location_changed.connect(npc_manager._on_location_changed)
		
		print("Connected NPCManager to other systems")
		
	# Możesz dodać więcej połączeń między systemami tutaj
	print("Systemy połączone")
	
func initialize_systems():
	# Utwórz translator koordynatów
	coord_translator = CoordTranslator.new()
	coord_translator.name = "CoordTranslator"
	systems_container.add_child(coord_translator)
	
	# Utwórz menedżera POI
	poi_manager = POIManager.new()
	poi_manager.name = "POIManager"
	systems_container.add_child(poi_manager)
	
	# Create NPC manager
	var npc_manager = NPCManager.new()
	npc_manager.name = "NPCManager"
	systems_container.add_child(npc_manager)
	
	# Create connector manager 
	var connector_manager = ConnectorManager.new()
	connector_manager.name = "ConnectorManager"
	systems_container.add_child(connector_manager)
	
	
	# Czekaj jedną klatkę na inicjalizację systemów
	await get_tree().process_frame
	
	print("Systemy zainicjalizowane")
	
	# Create test NPCs immediately after systems are initialized
	create_test_npcs()

# Create some test NPCs
func create_test_npcs():
	var npc_manager = get_node("Systems/NPCManager")
	if not npc_manager:
		push_error("NPC Manager not found! Cannot create test NPCs.")
		return
		
	print("Creating test NPCs...")
	
	# Create an array of NPCs
	var npcs = []
	
	# Create 5 stalkers
	for i in range(1, 6):
		var npc = NPCResource.new()
		npc.npc_id = "stalker" + str(i)
		npc.npc_type = "stalker"
		npc.faction = "loner"
		npc.world_position = Vector2(100 + i * 20, 150)  # Place around location1
		npc.color = Color(0.2, 0.6, 1.0)  # Blue for loners
		npcs.append(npc)
		print("Created stalker" + str(i) + " at position " + str(npc.world_position))
	
	# Create 3 bandits
	for i in range(1, 4):
		var npc = NPCResource.new()
		npc.npc_id = "bandit" + str(i)
		npc.npc_type = "bandit"
		npc.faction = "bandit"
		npc.world_position = Vector2(700 + i * 20, 250)  # Place around location2
		npc.color = Color(0.1, 0.1, 0.1)  # Black for bandits
		npcs.append(npc)
		print("Created bandit" + str(i) + " at position " + str(npc.world_position))
	
	# Register all NPCs
	npc_manager.register_npcs(npcs)
	
	# Start their movement after short delay
	get_tree().create_timer(2.0).timeout.connect(func():
		# Set each NPC to start moving to a POI
		for npc in npcs:
			npc_manager._on_npc_choose_new_target(npc.npc_id)
		print("NPCs started moving to POIs")
	)
	
	print("Created test NPCs")
	
# Skonfiguruj gracza
func setup_player():
	# Zinstancjonuj scenę gracza
	var player_scene = preload("res://scenes/player/player.tscn")
	player = player_scene.instantiate()
	player.name = "Player"
	add_child(player)
	
	# Ustaw początkową pozycję
	var spawn_pos = coord_translator.back_to_front(current_location_id, Vector2(150, 150))
	player.global_position = spawn_pos
	
	# DODAJ TĘ LINIĘ: Przekaż referencję do gracza do mapy strategicznej
	if strategic_map:
		strategic_map.set_player(player)

# Załaduj lokację
func load_location(location_id: String):
	# Usuń aktualną lokację, jeśli istnieje
	if current_location:
		current_location.queue_free()
	
	# Utwórz nową lokację
	var location_scene = location_scenes[location_id]
	current_location = location_scene.instantiate()
	current_location.name = location_id
	locations_container.add_child(current_location)
	
	# Zaktualizuj śledzenie aktualnej lokacji
	current_location_id = location_id

# Skonfiguruj mapę strategiczną
func setup_strategic_map():
	var map_scene = preload("res://scenes/locations/back_mode/strategic_map.tscn")
	strategic_map = map_scene.instantiate()
	strategic_map.name = "StrategicMap"
	ui_container.add_child(strategic_map)
	
	# Ukryj domyślnie, można przełączać klawiszem
	strategic_map.visible = false

# Przełącz widoczność mapy strategicznej
func toggle_strategic_map():
	strategic_map.visible = !strategic_map.visible

# Zmień lokację
func change_location(location_id: String, spawn_position: Vector2 = Vector2.ZERO):
	# Sprawdź czy lokacja istnieje
	if not location_scenes.has(location_id):
		push_error("Location ID '" + location_id + "' not found in location_scenes")
		return
	
	# Załaduj nową lokację
	load_location(location_id)
	
	# Zmień pozycję gracza
	if spawn_position != Vector2.ZERO:
		var front_pos = coord_translator.back_to_front(location_id, spawn_position)
		player.global_position = front_pos
	else:
		# Użyj domyślnej pozycji spawnu
		player.global_position = coord_translator.back_to_front(location_id, Vector2(150, 150))
	
	# Emit location changed signal
	emit_signal("location_changed", location_id)

# Ustaw stan aktywności POI
func set_poi_active(poi_id: String, active: bool):
	poi_manager.set_poi_active(poi_id, active)

# Przetwarzaj wejście dla kontroli świata
func _input(event):
	# Przełącz mapę strategiczną klawiszem M
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_M:
			toggle_strategic_map()
		# Przełącz na location1 klawiszem 1
		elif event.keycode == KEY_1:
			change_location("location1")
		# Przełącz na location2 klawiszem 2
		elif event.keycode == KEY_2:
			change_location("location2")
		# Przetestuj przełączenie stanu aktywności POI (dla przykładu)
		elif event.keycode == KEY_P:
			# Toggle stan pierwszego POI
			var poi_ids = poi_manager.all_pois.keys()
			if not poi_ids.is_empty():
				var first_poi = poi_manager.get_poi(poi_ids[0])
				set_poi_active(poi_ids[0], !first_poi.is_active)
