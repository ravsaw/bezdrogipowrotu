extends Area3D
class_name LocationPortal

@export var portal_id: String = "portal1"
@export var visual_radius: float = 2.0
@export var visual_height: float = 4.0
@export var portal_color: Color = Color(0.2, 0.4, 1.0, 0.6)

# References
var coord_translator: CoordTranslator
var alife_system
var world_manager

var current_location: String
var portal_mesh: MeshInstance3D
var portal_particles: GPUParticles3D

func _ready():
	# Get system references
	coord_translator = get_node("/root/World/Systems/CoordTranslator")
	alife_system = get_node("/root/World/Systems/ALifeSystem")
	world_manager = get_node("/root/World")
	
	# Get current location from parent
	current_location = get_parent().name
	
	# Set up collision
	var collision_shape = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = visual_radius
	shape.height = visual_height
	collision_shape.shape = shape
	add_child(collision_shape)
	
	# Set up visual representation
	setup_visuals()
	
	# Connect signals
	body_entered.connect(_on_body_entered)

# Setup visual representation of the portal
func setup_visuals():
	# Create mesh for portal
	portal_mesh = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = visual_radius
	cylinder.bottom_radius = visual_radius
	cylinder.height = visual_height
	portal_mesh.mesh = cylinder
	add_child(portal_mesh)
	
	# Create material for portal
	var material = StandardMaterial3D.new()
	material.albedo_color = portal_color
	material.emission_enabled = true
	material.emission = portal_color
	material.emission_energy = 1.5
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	portal_mesh.material_override = material
	
	# Add particles for effect
	setup_particles()

# Setup particle effects
func setup_particles():
	portal_particles = GPUParticles3D.new()
	add_child(portal_particles)
	
	# Create a simple particle material
	var particle_material = ParticleProcessMaterial.new()
	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	particle_material.emission_ring_radius = visual_radius
	particle_material.emission_ring_height = visual_height
	particle_material.direction = Vector3(0, 1, 0)
	particle_material.spread = 15.0
	particle_material.gravity = Vector3(0, 0.5, 0)
	particle_material.initial_velocity_min = 1.0
	particle_material.initial_velocity_max = 2.0
	particle_material.color = portal_color
	
	# Assign to particles
	portal_particles.process_material = particle_material
	
	# Create a simple mesh for the particles
	var particle_mesh = SphereMesh.new()
	particle_mesh.radius = 0.1
	particle_mesh.height = 0.2
	portal_particles.draw_pass_1 = particle_mesh
	
	# Set particles parameters
	portal_particles.amount = 50
	portal_particles.lifetime = 2.0
	portal_particles.explosiveness = 0.0
	portal_particles.randomness = 0.5
	portal_particles.local_coords = false

# Handle body entering portal
func _on_body_entered(body):
	if body.name == "Player":
		# Player entered portal
		handle_player_teleport()
	elif body.is_in_group("npc"):
		# NPC entered portal
		handle_npc_teleport(body)

# Handle player teleportation
func handle_player_teleport():
	# Get target location and position
	var target_data = coord_translator.get_portal_target_position(
		current_location, portal_id
	)
	
	# Tell the world manager to change location
	world_manager.change_location(
		target_data["location"], 
		target_data["position"]
	)

# Handle NPC teleportation
func handle_npc_teleport(npc_body):
	# Get the group this NPC belongs to
	var group_id = npc_body.get_parent().group_id
	
	# Tell the A-Life system to handle the portal traversal
	alife_system.handle_group_portal_traversal(group_id, portal_id)
