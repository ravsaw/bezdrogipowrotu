extends CharacterBody3D
class_name NPC

# NPC properties
var is_leader: bool = false
var health: int = 100
var stamina: float = 100.0
var state: String = "idle"  # idle, walk, run, combat

# Visual components
var model: Node3D
var animation_player: AnimationPlayer

# References
var alife_system

func _ready():
	# Add to NPC group for collision detection
	add_to_group("npc")
	
	# Set up collision
	var collision_shape = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = 0.5
	shape.height = 1.8
	collision_shape.shape = shape
	add_child(collision_shape)
	
	# Set up visual representation
	setup_visuals()
	
	# Get system references
	alife_system = get_node("/root/World/Systems/ALifeSystem")

# Setup visual representation
func setup_visuals():
	# Create placeholder model
	model = Node3D.new()
	model.name = "Model"
	add_child(model)
	
	# Body
	var body = MeshInstance3D.new()
	var capsule_mesh = CapsuleMesh.new()
	capsule_mesh.radius = 0.5
	capsule_mesh.height = 1.0
	body.mesh = capsule_mesh
	model.add_child(body)
	
	# Head
	var head = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.3
	head.mesh = sphere_mesh
	head.position = Vector3(0, 0.8, 0)
	model.add_child(head)
	
	# Add animation player
	animation_player = AnimationPlayer.new()
	add_child(animation_player)
	
	# Create basic animations
	create_basic_animations()

# Create basic animations for the NPC
func create_basic_animations():
	# Idle animation
	var idle_anim = Animation.new()
	var idle_track = idle_anim.add_track(Animation.TYPE_VALUE)
	idle_anim.track_set_path(idle_track, "Model:position")
	idle_anim.track_insert_key(idle_track, 0.0, Vector3(0, 0, 0))
	idle_anim.track_insert_key(idle_track, 1.0, Vector3(0, 0.05, 0))
	idle_anim.track_insert_key(idle_track, 2.0, Vector3(0, 0, 0))
	idle_anim.loop_mode = Animation.LOOP_LINEAR
	animation_player.add_animation_library("idle", idle_anim)
	
	# Walk animation
	var walk_anim = Animation.new()
	var walk_track = walk_anim.add_track(Animation.TYPE_VALUE)
	walk_anim.track_set_path(walk_track, "Model:rotation")
	walk_anim.track_insert_key(walk_track, 0.0, Vector3(0, 0, 0))
	walk_anim.track_insert_key(walk_track, 0.5, Vector3(0, 0, 0.05))
	walk_anim.track_insert_key(walk_track, 1.0, Vector3(0, 0, 0))
	walk_anim.track_insert_key(walk_track, 1.5, Vector3(0, 0, -0.05))
	walk_anim.track_insert_key(walk_track, 2.0, Vector3(0, 0, 0))
	walk_anim.loop_mode = Animation.LOOP_LINEAR
	animation_player.add_animation_library("walk", walk_anim)

# Setup as a leader with distinct appearance
func setup_as_leader():
	# Change color to red to indicate leader
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.8, 0.2, 0.2)  # Red for leader
	
	var body = model.get_child(0)
	body.material_override = material
	
	# Make slightly larger
	transform = transform.scaled(Vector3(1.2, 1.2, 1.2))

# Setup as a follower
func setup_as_follower():
	# Change color to blue for followers
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.2, 0.8)  # Blue for followers
	
	var body = model.get_child(0)
	body.material_override = material

# Move in a direction
func move_in_direction(direction: Vector3, speed: float, delta: float):
	# Set velocity
	velocity = direction * speed
	
	# Update model orientation (look in the direction of movement)
	if direction.length_squared() > 0.01:
		# Calculate target rotation
		var target_rotation = atan2(direction.x, direction.z)
		
		# Current rotation
		var current_rotation = rotation.y
		
		# Smoothly interpolate rotation
		var rotation_speed = 5.0
		rotation.y = lerp_angle(current_rotation, target_rotation, rotation_speed * delta)
		
		# Update state to walking
		if state != "walk":
			state = "walk"
			animation_player.play("walk")
	else:
		# Update state to idle
		if state != "idle":
			state = "idle"
			animation_player.play("idle")
	
	# Apply movement using CharacterBody3D
	move_and_slide()

# Process AI behavior
func _process(_delta):
	# This would be filled with individual NPC behavior
	# For now, it's controlled by the parent group
	pass

# Handle being hit or damaged
func take_damage(amount: int):
	health -= amount
	
	if health <= 0:
		die()

# Handle death
func die():
	# Play death animation if we had one
	
	# Notify parent group
	get_parent().member_died(self)
	
	# Remove after delay
	var timer = get_tree().create_timer(2.0)
	await timer.timeout
	
	# Remove from scene
	queue_free()
