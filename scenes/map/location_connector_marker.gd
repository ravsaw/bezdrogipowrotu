# scenes/map/location_connector_marker.gd
@tool
extends Node2D
class_name LocationConnectorMarker

@export var connector_id: String = "connector1":
	set(new_id):
		connector_id = new_id
		if is_inside_tree() and Engine.is_editor_hint() and label:
			label.text = new_id

@export var location_a: String = "location1":
	set(new_loc):
		location_a = new_loc
		update_visual()

@export var location_b: String = "location2":
	set(new_loc):
		location_b = new_loc
		update_visual()

@export var color: Color = Color(1, 0.5, 0, 0.8):
	set(new_color):
		color = new_color
		update_visual()

# Visual elements
var marker_shape: ColorRect
var label: Label
var connection_line: Line2D

func _ready():
	add_to_group("location_connectors")
	
	if Engine.is_editor_hint():
		setup_visual_elements()
		update_visual()
	else:
		# In runtime, this node will be used only for data gathering
		pass

func setup_visual_elements():
	# Remove existing elements if any
	for child in get_children():
		child.queue_free()
	
	# Create colored marker
	marker_shape = ColorRect.new()
	marker_shape.color = color
	marker_shape.size = Vector2(16, 16)
	marker_shape.position = Vector2(-8, -8)  # Center relative to node position
	add_child(marker_shape)
	
	# Add label
	label = Label.new()
	label.text = connector_id
	label.position = Vector2(10, -10)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	add_child(label)
	
	# Connection line (visual only in editor)
	connection_line = Line2D.new()
	connection_line.width = 2.0
	connection_line.default_color = color
	add_child(connection_line)

func update_visual():
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
		
	if marker_shape:
		marker_shape.color = color
		
	if label:
		label.text = connector_id + "\n" + location_a + " <-> " + location_b

func get_connector_data() -> Dictionary:
	return {
		"connector_id": connector_id,
		"location_a": location_a,
		"location_b": location_b,
		"position_a": global_position,  # Current position is in location A
		"position_b": Vector2.ZERO,     # Will be set by ConnectorManager
		"is_active": true
	}

func _get_configuration_warnings():
	return ["This node is used for visually defining location connections on the map."]
