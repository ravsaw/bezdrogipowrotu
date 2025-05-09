# scripts/systems/npc_marker.gd
extends Node2D
class_name NPCMarker

var npc_id: String = ""
var color: Color = Color.WHITE
var faction: String = ""
var path_target: Vector2 = Vector2.ZERO
var has_path: bool = false

# Visual elements
var marker: ColorRect
var label: Label
var path_line: Line2D

func _ready():
	create_visual_elements()

func create_visual_elements():
	# Create marker shape
	marker = ColorRect.new()
	marker.color = color
	marker.size = Vector2(8, 8)
	marker.position = Vector2(-4, -4)  # Center relative to node position
	add_child(marker)
	
	# Create label
	label = Label.new()
	label.text = npc_id
	label.position = Vector2(6, -10)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	
	# Create path line
	path_line = Line2D.new()
	path_line.width = 1.0
	path_line.default_color = color.lightened(0.3)
	path_line.visible = false
	add_child(path_line)
	
	# Signal that visual elements are ready
	#call_deferred("emit_signal", "visual_elements_ready")

# Add null check to update_path
func update_path(has_target: bool, target_pos: Vector2 = Vector2.ZERO):
	has_path = has_target
	path_target = target_pos
	
	# Check if path_line exists
	if not path_line:
		return
	
	if has_path:
		path_line.clear_points()
		path_line.add_point(Vector2.ZERO)
		path_line.add_point(target_pos - global_position)
		path_line.visible = true
	else:
		path_line.visible = false
