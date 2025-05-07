extends CharacterBody3D
class_name Player

# Movement settings
@export var walk_speed: float = 25.0
@export var run_speed: float = 100.0
@export var jump_velocity: float = 54.5
@export var mouse_sensitivity: float = 0.002

# Camera
var camera: Camera3D
var camera_pivot: Node3D

# Physics
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	# Set up camera
	setup_camera()
	
	# Capture mouse
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event):
	# Mouse look
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Rotate camera pivot (look up/down)
		camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, -PI/2, PI/2)
		
		# Rotate player (look left/right)
		rotate_y(-event.relative.x * mouse_sensitivity)
	
	# Toggle mouse capture
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta):
	# Add gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Handle Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
	
	# Get movement input
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	
	# Transform direction based on camera orientation
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Determine speed (walk or run)
	var speed = run_speed if Input.is_action_pressed("run") else walk_speed
	
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	
	move_and_slide()

func setup_camera():
	# Create a pivot for camera (allows looking up/down)
	camera_pivot = Node3D.new()
	camera_pivot.name = "CameraPivot"
	camera_pivot.transform.origin = Vector3(0, 10.7, 0)  # Head height
	add_child(camera_pivot)
	
	# Create camera
	camera = Camera3D.new()
	camera.name = "Camera"
	camera_pivot.add_child(camera)
	
	# Set up collision shape
	var collision = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = 0.5
	shape.height = 1.8
	collision.shape = shape
	add_child(collision)
