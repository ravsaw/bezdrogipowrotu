extends Node3D
class_name POI

@export var poi_id: String = "poi1"
@export var poi_type: String = "generic" # Different POI types for visualization
@export var marker_color: Color = Color(1, 0.8, 0, 0.8) # Default yellow
@export var description: String = "" # Optional description of the POI

func _ready():
	# Add to POI group for easy finding
	add_to_group("poi")
	
	print("POI " + poi_id + " added to 'poi' group")
	
	# Add a visual indicator in the 3D world
	create_visual_indicator()

# Create a simple visual indicator for the POI in the 3D world
func create_visual_indicator():
	# Create a mesh for visualization
	var mesh_instance = $Mesh if has_node("Mesh") else MeshInstance3D.new()
	
	if not has_node("Mesh"):
		var cylinder = CylinderMesh.new()
		cylinder.top_radius = 1.0
		cylinder.bottom_radius = 1.0
		cylinder.height = 2.0
		mesh_instance.mesh = cylinder
		add_child(mesh_instance)
	
	# Add material with the marker color
	var material = StandardMaterial3D.new()
	material.albedo_color = marker_color
	material.emission_enabled = true
	material.emission = marker_color
	material.emission_energy = 0.5
	mesh_instance.material_override = material
	
	# Add label if it doesn't exist
	if not has_node("Label3D"):
		var label = Label3D.new()
		label.text = poi_id + "\n" + poi_type
		label.position = Vector3(0, 2.0, 0)
		label.font_size = 125
		label.outline_size = 25
		add_child(label)
