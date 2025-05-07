extends Node3D
class_name Location

@export var location_id: String = "location1"

# References
var coord_translator
var world_manager

func _ready():
	# Get system references
	coord_translator = get_node("/root/World/Systems/CoordTranslator")
	world_manager = get_node("/root/World")
	
	# Setup environment
	create_environment()
	
	# Setup POIs
	setup_pois()
	
	# Setup portals
	setup_portals()

# Create basic environment
func create_environment():
	# Create floor
	var floor_mesh = PlaneMesh.new()
	floor_mesh.size = Vector2(1000, 1000)  # Match our location size
	
	var floor_t = MeshInstance3D.new()
	floor_t.mesh = floor_mesh
	floor_t.name = "Floor"
	
	# Add material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.5, 0.3)  # Grass-like color
	floor_t.material_override = material
	
	add_child(floor_t)
	
	# Add collision
	var static_body = StaticBody3D.new()
	floor_t.add_child(static_body)
	
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(10000, 1, 10000)
	collision.shape = shape
	collision.transform.origin.y = -0.5  # Center the collision shape
	static_body.add_child(collision)
	
	# Add some basic lighting
	var dir_light = DirectionalLight3D.new()
	dir_light.transform.basis = Basis(Vector3(0.5, -1, 0.3).normalized(), Vector3.UP, Vector3.ZERO)
	add_child(dir_light)

# Setup Points of Interest
func setup_pois():
	# Get POI data from the coordinate translator
	var pois = coord_translator.get_poi_positions(location_id)
	
	# Create a visual marker for each POI
	for poi_id in pois:
		var poi_pos = coord_translator.get_front_poi_position(location_id, poi_id)
		
		# Create marker
		var marker = Node3D.new()
		marker.name = "POI_" + poi_id
		marker.transform.origin = poi_pos
		add_child(marker)
		
		# Add visual representation
		var mesh = MeshInstance3D.new()
		var cylinder = CylinderMesh.new()
		cylinder.top_radius = 1.0
		cylinder.bottom_radius = 1.0
		cylinder.height = 0.2
		mesh.mesh = cylinder
		marker.add_child(mesh)
		
		# Add material
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(1, 0.8, 0)  # Yellow for POIs
		material.emission_enabled = true
		material.emission = material.albedo_color
		material.emission_energy = 0.5
		mesh.material_override = material
		
		# Add label
		var label_3d = Label3D.new()
		label_3d.text = poi_id
		label_3d.transform.origin.y = 2.0
		label_3d.font_size = 64
		marker.add_child(label_3d)

# Setup location portals
func setup_portals():
	# Get portal data from the coordinate translator
	var portals = coord_translator.location_data[location_id].get("portals", {})
	
	# Create a portal for each defined connection
	for portal_id in portals:
		var portal_data = portals[portal_id]
		var portal_pos = portal_data["front_pos"]
		
		# Instantiate portal scene
		var portal_scene = preload("res://scenes/portals/location_portal.tscn")
		var portal = portal_scene.instantiate()
		portal.name = "Portal_" + portal_id
		portal.portal_id = portal_id
		portal.transform.origin = portal_pos
		add_child(portal)
