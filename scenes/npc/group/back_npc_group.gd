extends Node2D
class_name BackNPCGroup

# Settings
var group_id: String
var current_location: String
var is_active = false
var leader_sprite: Sprite2D
var path_line: Line2D
var indicator_color = Color(0.2, 0.7, 0.3)  # Green for friendly groups

# References
var npc_group_data  # Reference to the base group data
var coord_translator: CoordTranslator

func initialize(base_group):
	group_id = base_group.group_id
	current_location = base_group.current_location
	npc_group_data = base_group
	
	# Create visuals
	setup_visuals()
	
	is_active = true

func _ready():
	coord_translator = get_node_or_null("/root/World/Systems/CoordTranslator")
	if not coord_translator:
		push_error("CoordTranslator not found in BackNPCGroup")

func _process(delta):
	if is_active:
		# Update position from the base group data
		global_position = npc_group_data.back_position
		
		# Update path visualization
		update_path_visualization()

# Setup visual representation of the group
func setup_visuals():
	# Create leader sprite
	leader_sprite = Sprite2D.new()
	add_child(leader_sprite)
	
	# Try to load the icon texture, but use a fallback if not found
	var texture = null
	if FileAccess.file_exists("res://assets/textures/group_icon.png"):
		texture = load("res://assets/textures/group_icon.png")
	
	if texture:
		leader_sprite.texture = texture
	else:
		# Texture not found, create a placeholder ColorRect instead
		var placeholder = ColorRect.new()
		placeholder.color = indicator_color
		placeholder.size = Vector2(10, 10)
		placeholder.position = Vector2(-5, -5)  # Center at origin
		add_child(placeholder)
		print("Created placeholder for missing group icon texture")
	
	# Setup path visualization
	path_line = Line2D.new()
	path_line.width = 2.0
	path_line.default_color = indicator_color
	add_child(path_line)
	
	# Set initial position
	global_position = npc_group_data.back_position

# Update the visualization of the path this group is following
func update_path_visualization():
	path_line.clear_points()
	
	# Add current position as first point
	path_line.add_point(Vector2.ZERO)  # Local origin
	
	# Add remaining path points
	for point in npc_group_data.path_to_target:
		var relative_point = point - global_position
		path_line.add_point(relative_point)

# Switch to front mode - will be handled by parent
func activate():
	is_active = false
	queue_free()
