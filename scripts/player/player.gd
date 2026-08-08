extends CharacterBody3D
class_name Player

@export var max_hp: int = 3
@export var move_speed: float = 7.0
@export var jump_velocity: float = 6.0
@export var slide_speed: float = 10.0
@export var slide_duration: float = 0.8
@export var wall_run_speed: float = 8.0
@export var wall_run_max_time: float = 1.5
@export var miss_cooldown: float = 5.0
@export var hit_cooldown: float = 0.3
@export var mouse_sensitivity: float = 0.003
@export var fast_fall_speed: float = 18.0

var current_hp: int = 3
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

# Node references
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var camera: Camera3D = $Camera3D
@onready var hand_weapon: Node3D = $Camera3D/HandWeapon
@onready var animated_sprite: AnimatedSprite3D = $Camera3D/HandWeapon/AnimatedSprite3D
@onready var attack_raycast: RayCast3D = $Camera3D/HandWeapon/AttackRayCast
@onready var shapecast_left: ShapeCast3D = $ShapeCastLeft
@onready var shapecast_right: ShapeCast3D = $ShapeCastRight
@onready var state_machine: PlayerStateMachine = $PlayerStateMachine
@onready var get_hit_timer: Timer = $GetHitTimer
@onready var attack_timer: Timer = $AttackTimer

# Internal variables
var default_capsule_height: float = 2.0
var default_capsule_position_y: float = 1.0
var slide_timer: float = 0.0
var wall_run_timer: float = 0.0
var wall_run_side: int = 0 # -1 left, 1 right
var camera_pitch: float = 0.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	current_hp = max_hp
	if GameManager:
		GameManager.current_hp = current_hp
		GameManager.max_hp = max_hp

	if collision_shape and collision_shape.shape is CapsuleShape3D:
		default_capsule_height = (collision_shape.shape as CapsuleShape3D).height
		default_capsule_position_y = collision_shape.position.y

	if state_machine:
		state_machine.init(self)

	# Connect area entered for hurtbox
	var hurtbox = get_node_or_null("Hurtbox")
	if hurtbox and hurtbox is Area3D:
		(hurtbox as Area3D).area_entered.connect(_on_area_entered)

func _unhandled_input(event: InputEvent) -> void:
	if state_machine and state_machine.current_state_type == PlayerStateMachine.StateType.DEAD:
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Mouse Yaw (rotate Player body)
		rotate_y(-event.relative.x * mouse_sensitivity)

		# Mouse Pitch (rotate Camera3D)
		camera_pitch -= event.relative.y * mouse_sensitivity
		camera_pitch = clamp(camera_pitch, deg_to_rad(-89.0), deg_to_rad(89.0))
		if camera:
			camera.rotation.x = camera_pitch

	if event.is_action_pressed("attack"):
		attack()

func _physics_process(delta: float) -> void:
	if state_machine and state_machine.current_state_type == PlayerStateMachine.StateType.DEAD:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	update_state_logic(delta)
	apply_movement(delta)
	move_and_slide()

func _process(delta: float) -> void:
	if GameManager and state_machine.current_state_type != PlayerStateMachine.StateType.DEAD:
		GameManager.update_score(delta)

func update_state_logic(delta: float) -> void:
	var current_state = state_machine.current_state_type

	match current_state:
		PlayerStateMachine.StateType.GROUNDED:
			if not is_on_floor():
				state_machine.transition_to(PlayerStateMachine.StateType.JUMP)
			elif Input.is_action_just_pressed("jump"):
				velocity.y = jump_velocity
				state_machine.transition_to(PlayerStateMachine.StateType.JUMP)
			elif Input.is_action_just_pressed("slide"):
				enter_slide_state()

		PlayerStateMachine.StateType.JUMP:
			if is_on_floor():
				restore_hitbox()
				state_machine.transition_to(PlayerStateMachine.StateType.GROUNDED)
			elif Input.is_action_just_pressed("slide"):
				# Aerial fast fall / ground pound slide
				velocity.y = -fast_fall_speed
				enter_slide_state()
			elif check_wall_run_available():
				state_machine.transition_to(PlayerStateMachine.StateType.WALL_RUN)
				wall_run_timer = wall_run_max_time

		PlayerStateMachine.StateType.SLIDE:
			slide_timer -= delta
			if Input.is_action_just_pressed("jump"):
				restore_hitbox()
				velocity.y = jump_velocity
				state_machine.transition_to(PlayerStateMachine.StateType.JUMP)
			elif slide_timer <= 0.0 or not Input.is_action_pressed("slide") or velocity.length() < 1.0:
				restore_hitbox()
				if is_on_floor():
					state_machine.transition_to(PlayerStateMachine.StateType.GROUNDED)
				else:
					state_machine.transition_to(PlayerStateMachine.StateType.JUMP)

		PlayerStateMachine.StateType.WALL_RUN:
			wall_run_timer -= delta
			if Input.is_action_just_pressed("jump") or wall_run_timer <= 0.0 or not is_wall_run_still_valid():
				# Push off wall on jump or exit
				if Input.is_action_just_pressed("jump"):
					velocity.y = jump_velocity
					var push_direction = transform.basis.x * (-wall_run_side) * 4.0
					velocity += push_direction
				state_machine.transition_to(PlayerStateMachine.StateType.JUMP)

		PlayerStateMachine.StateType.GET_HIT:
			if get_hit_timer.is_stopped():
				state_machine.transition_to(PlayerStateMachine.StateType.GROUNDED)

func apply_movement(delta: float) -> void:
	var current_state = state_machine.current_state_type

	# Apply gravity if not on floor and not wall running
	if not is_on_floor() and current_state != PlayerStateMachine.StateType.WALL_RUN:
		velocity.y -= gravity * delta

	# Calculate current movement speed (accounting for GET_HIT debuff)
	var speed: float = move_speed
	if current_state == PlayerStateMachine.StateType.SLIDE:
		speed = slide_speed
	elif current_state == PlayerStateMachine.StateType.WALL_RUN:
		speed = wall_run_speed
		velocity.y = 0.0 # Maintain vertical stability during wall run

	# GET_HIT debuff: speed reduced to 20% while get_hit_timer is active
	if not get_hit_timer.is_stopped():
		speed *= 0.2

	# Input directional movement
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if current_state == PlayerStateMachine.StateType.SLIDE:
		# Maintain forward sliding direction
		var slide_dir = -transform.basis.z
		velocity.x = slide_dir.x * speed
		velocity.z = slide_dir.z * speed
	elif direction != Vector3.ZERO:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

func enter_slide_state() -> void:
	slide_timer = slide_duration
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var capsule = collision_shape.shape as CapsuleShape3D
		capsule.height = default_capsule_height * 0.5
		collision_shape.position.y = default_capsule_position_y * 0.5
	state_machine.transition_to(PlayerStateMachine.StateType.SLIDE)

func restore_hitbox() -> void:
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var capsule = collision_shape.shape as CapsuleShape3D
		capsule.height = default_capsule_height
		collision_shape.position.y = default_capsule_position_y

func check_wall_run_available() -> bool:
	if shapecast_left and shapecast_left.is_colliding():
		for i in range(shapecast_left.get_collision_count()):
			var collider = shapecast_left.get_collider(i)
			if is_wall_run_surface(collider):
				wall_run_side = -1
				return true

	if shapecast_right and shapecast_right.is_colliding():
		for i in range(shapecast_right.get_collision_count()):
			var collider = shapecast_right.get_collider(i)
			if is_wall_run_surface(collider):
				wall_run_side = 1
				return true

	return false

func is_wall_run_still_valid() -> bool:
	if wall_run_side == -1 and shapecast_left and shapecast_left.is_colliding():
		return true
	if wall_run_side == 1 and shapecast_right and shapecast_right.is_colliding():
		return true
	return false

func is_wall_run_surface(object: Object) -> bool:
	if not object:
		return false
	return object is WallRunSurface

func attack() -> void:
	if not attack_timer.is_stopped():
		return # On attack cooldown

	# Rewind BGM 1 second as specified in technical document
	if SoundManager:
		SoundManager.rewind_bgm(1.0)

	if attack_raycast and attack_raycast.is_colliding():
		var collider = attack_raycast.get_collider()
		# Successful hit: 0.3s cooldown
		attack_timer.start(hit_cooldown)
		if collider and collider.has_method("take_damage"):
			collider.take_damage(1)
	else:
		# Miss hit: 5.0s miss cooldown
		attack_timer.start(miss_cooldown)

func take_damage(amount: int) -> void:
	if state_machine and state_machine.current_state_type == PlayerStateMachine.StateType.DEAD:
		return

	current_hp -= amount
	if GameManager:
		GameManager.current_hp = current_hp

	if current_hp <= 0:
		instant_death()
	else:
		get_hit_timer.start(0.2)
		state_machine.transition_to(PlayerStateMachine.StateType.GET_HIT)

func instant_death() -> void:
	current_hp = 0
	if GameManager:
		GameManager.current_hp = 0
	state_machine.transition_to(PlayerStateMachine.StateType.DEAD)
	velocity = Vector3.ZERO
	if GameManager:
		GameManager.trigger_game_over()

func _on_area_entered(area: Area3D) -> void:
	if not area:
		return

	var script_name = ""
	if area.get_script():
		script_name = str(area.get_script().get_global_name())

	if script_name == "FrontGuard" or area.name.contains("FrontGuard"):
		take_damage(1)
	elif script_name == "TrapArea" or area.name.contains("TrapArea") or area.name.contains("Trap"):
		if area.get("is_instakill") == true:
			instant_death()
		else:
			take_damage(1)
	elif script_name == "KillZone" or area.name.contains("KillZone") or area.name.contains("ChasingHorde"):
		instant_death()
