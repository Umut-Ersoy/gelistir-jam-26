extends CharacterBody3D
class_name Player

@export_group("Health & Controls")
@export var max_hp: int = 3
@export var mouse_sensitivity: float = 0.003

@export_group("Movement Settings")
@export var move_speed: float = 10.0
@export var jump_velocity: float = 6.0
@export var slide_speed: float = 10.0
@export var slide_duration: float = 0.8
@export var wall_run_speed: float = 10.0
@export var wall_run_max_time: float = 1.2 # Maximum wall-run duration in seconds
@export var fast_fall_speed: float = 18.0
@export var jump_buffer_time: float = 0.05 # Input buffering window for jump in seconds

@export_group("Attack Settings")
@export var attack_damage: int = 1
@export var attack_windup_time: float = 0.2 # Windup time in seconds before dealing damage
@export var attack_success_cooldown: float = 0.3 # Cooldown time in seconds after successful attack
@export var attack_fail_cooldown: float = 5.0 # Cooldown time in seconds after missed attack

@export_group("Kill & Death Settings")
@export var kapak_chance: float = 0.10 # 10% chance on kill to play "kapak" animation
@export var cleaning_chance: float = 0.20 # 20% chance on kill to play "cleaning" animation
@export var death_sound_delay: float = 1.0 # Delay in seconds before playing random death sound

@export_group("Camera Physics Effects")
@export var max_camera_tilt_deg: float = 2.5 # Maximum camera tilt angle in degrees when strafing
@export var camera_tilt_speed: float = 8.0 # Smoothing factor (lerp speed) for camera tilt
@export var wall_run_tilt_deg: float = 6.0 # Additional camera tilt during wall-run
@export var slide_camera_speed: float = 12.0 # Smoothing lerp speed for camera Y height during slide

@export_group("UI Drag Settings")
@export var idle_drag_max_up: float = 15.0 # Max pixels shift UP when moving backward (horizontal)
@export var idle_drag_max_down: float = 15.0 # Max pixels shift DOWN when moving forward (horizontal)
@export var idle_drag_max_left: float = 20.0 # Max pixels shift LEFT when moving right
@export var idle_drag_max_right: float = 20.0 # Max pixels shift RIGHT when moving left
@export var idle_drag_max_jump_down: float = 20.0 # Max pixels shift DOWN when jumping/rising (Y velocity > 0)
@export var idle_drag_max_fall_up: float = 20.0 # Max pixels shift UP when falling/descending (Y velocity < 0)
@export var idle_slide_offset_y: float = -60.0 # Max pixels shift UP when sliding
@export var idle_drag_speed: float = 8.0 # Smoothing lerp speed for UI drag

var current_hp: int = 3
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

# Node references
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var hurtbox_collision_shape: CollisionShape3D = get_node_or_null("Hurtbox/CollisionShape3D") as CollisionShape3D
@onready var camera: Camera3D = $Camera3D
@onready var hand_weapon: Node3D = $Camera3D/HandWeapon
@onready var attack_raycast: RayCast3D = $Camera3D/HandWeapon/AttackRayCast
@onready var shapecast_left: ShapeCast3D = $ShapeCastLeft
@onready var shapecast_right: ShapeCast3D = $ShapeCastRight
@onready var state_machine: PlayerStateMachine = $PlayerStateMachine
@onready var get_hit_timer: Timer = $GetHitTimer
@onready var attack_timer: Timer = $AttackTimer
@onready var hp_rect: TextureRect = $CanvasShader/Hp
@onready var timer_label: Label = $CanvasNoShader/Label
@onready var idle_sprite: AnimatedSprite2D = get_node_or_null("CanvasShader/Idle") as AnimatedSprite2D
@onready var attack_sprite: AnimatedSprite2D = get_node_or_null("CanvasShader/Attack") as AnimatedSprite2D

# Attack & Kill animation state variables
var is_attacking: bool = false
var is_attack_on_cooldown: bool = false
var attack_windup_timer: float = 0.0
var attack_cooldown_timer: float = 0.0
var current_attack_targets: Array[StandingEnemy] = []
var current_attack_is_success: bool = false
var idle_tween: Tween = null
var post_kill_anim_queue: Array[String] = []
var is_playing_post_kill_anim: bool = false
var current_post_kill_anim: String = ""

# Internal variables
var total_game_time: float = 0.0
var default_capsule_height: float = 2.0
var default_capsule_position_y: float = 1.0
var default_camera_position_y: float = 1.5
var camera_height_diff: float = 0.3
var slide_timer: float = 0.0
var wall_run_timer: float = 0.0
var wall_run_side: int = 0 # -1 left, 1 right
var wall_run_count: int = 1 # Wall-run charges: reset to 1 on GROUNDED, 0 after WALL_RUN
var camera_pitch: float = 0.0
var jump_buffer_timer: float = 0.0 # Timer for buffered jump input
var default_idle_position_x: float = 0.0
var default_idle_position_y: float = 0.0
var current_drag_offset: Vector2 = Vector2.ZERO
var current_attack_offset_y: float = 0.0
var current_slide_offset_y: float = 0.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	current_hp = max_hp
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.current_hp = current_hp
		gm.max_hp = max_hp
	update_hp_ui()
	total_game_time = 0.0
	update_timer_ui()

	if idle_sprite:
		default_idle_position_x = idle_sprite.position.x
		default_idle_position_y = idle_sprite.position.y
		idle_sprite.visible = true
	if attack_sprite:
		attack_sprite.visible = false
		if not attack_sprite.animation_finished.is_connected(_on_attack_animation_finished):
			attack_sprite.animation_finished.connect(_on_attack_animation_finished)

	if camera:
		default_camera_position_y = camera.position.y

	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var capsule = collision_shape.shape as CapsuleShape3D
		default_capsule_height = capsule.height
		default_capsule_position_y = collision_shape.position.y
		if camera:
			camera_height_diff = default_capsule_height - camera.position.y

	if state_machine:
		state_machine.init(self)
		state_machine.state_changed.connect(_on_state_changed)

	# Connect area entered for hurtbox
	var hurtbox = get_node_or_null("Hurtbox")
	if hurtbox and hurtbox is Area3D:
		(hurtbox as Area3D).position = Vector3.ZERO
		(hurtbox as Area3D).area_entered.connect(_on_area_entered)
	if hurtbox_collision_shape:
		hurtbox_collision_shape.position.y = default_capsule_position_y

func _on_state_changed(old_state: PlayerStateMachine.StateType, new_state: PlayerStateMachine.StateType) -> void:
	if old_state == PlayerStateMachine.StateType.SLIDE:
		restore_hitbox()

	if new_state == PlayerStateMachine.StateType.GROUNDED:
		wall_run_count = 1
	elif new_state == PlayerStateMachine.StateType.WALL_RUN:
		wall_run_count -= 1

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
	elif event.is_action_pressed("jump"):
		if state_machine and state_machine.current_state_type != PlayerStateMachine.StateType.GROUNDED:
			jump_buffer_timer = jump_buffer_time

func _physics_process(delta: float) -> void:
	if state_machine and state_machine.current_state_type == PlayerStateMachine.StateType.DEAD:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	update_state_logic(delta)
	update_attack_logic(delta)
	apply_movement(delta)
	move_and_slide()
	update_camera_tilt(delta)
	update_camera_height(delta)
	update_idle_transform(delta)

func _process(delta: float) -> void:
	if state_machine and state_machine.current_state_type != PlayerStateMachine.StateType.DEAD:
		var gm = get_node_or_null("/root/GameManager")
		if gm:
			gm.update_score(delta)
		total_game_time += delta
		update_timer_ui()

func update_state_logic(delta: float) -> void:
	if jump_buffer_timer > 0.0:
		jump_buffer_timer -= delta

	var current_state = state_machine.current_state_type

	match current_state:
		PlayerStateMachine.StateType.GROUNDED:
			if not is_on_floor():
				state_machine.transition_to(PlayerStateMachine.StateType.FALL)
			elif Input.is_action_just_pressed("jump") or jump_buffer_timer > 0.0:
				jump_buffer_timer = 0.0
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
				velocity.y = - fast_fall_speed
				enter_slide_state()
			elif velocity.y < 0.0:
				state_machine.transition_to(PlayerStateMachine.StateType.FALL)

		PlayerStateMachine.StateType.FALL:
			if is_on_floor():
				restore_hitbox()
				state_machine.transition_to(PlayerStateMachine.StateType.GROUNDED)
			elif Input.is_action_just_pressed("slide"):
				velocity.y = - fast_fall_speed
				enter_slide_state()
			elif wall_run_count > 0 and check_wall_run_available():
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
					state_machine.transition_to(PlayerStateMachine.StateType.FALL)

		PlayerStateMachine.StateType.WALL_RUN:
			wall_run_timer -= delta
			if is_on_floor():
				state_machine.transition_to(PlayerStateMachine.StateType.GROUNDED)
			elif Input.is_action_just_pressed("jump"):
				velocity.y = jump_velocity
				var push_direction = transform.basis.x * (-wall_run_side) * 4.0
				velocity += push_direction
				state_machine.transition_to(PlayerStateMachine.StateType.JUMP)
			elif wall_run_timer <= 0.0 or not is_wall_run_still_valid():
				state_machine.transition_to(PlayerStateMachine.StateType.FALL)

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
		var slide_dir = - transform.basis.z
		velocity.x = slide_dir.x * speed
		velocity.z = slide_dir.z * speed
	elif direction != Vector3.ZERO:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

func update_camera_tilt(delta: float) -> void:
	if not camera:
		return

	# Calculate local velocity along character's axes
	var local_vel = global_transform.basis.inverse() * velocity
	var lateral_speed = local_vel.x
	var norm_lateral = clamp(lateral_speed / max(move_speed, 1.0), -1.0, 1.0)
	var target_tilt_deg = - norm_lateral * max_camera_tilt_deg

	# Add extra tilt during wall-run
	if state_machine and state_machine.current_state_type == PlayerStateMachine.StateType.WALL_RUN:
		target_tilt_deg += wall_run_side * wall_run_tilt_deg

	var target_tilt_rad = deg_to_rad(target_tilt_deg)
	camera.rotation.z = lerp(camera.rotation.z, target_tilt_rad, delta * camera_tilt_speed)

func update_camera_height(delta: float) -> void:
	if not camera:
		return

	var target_y = default_camera_position_y
	if state_machine and state_machine.current_state_type == PlayerStateMachine.StateType.SLIDE:
		if collision_shape and collision_shape.shape is CapsuleShape3D:
			var capsule = collision_shape.shape as CapsuleShape3D
			target_y = capsule.height - camera_height_diff

	camera.position.y = lerp(camera.position.y, target_y, delta * slide_camera_speed)


func update_idle_transform(delta: float) -> void:
	if not idle_sprite:
		return

	# 1. Smoothly return attack offset (300.0 -> 0.0 over 0.5s after cooldown finishes)
	if not is_attacking and not is_attack_on_cooldown and current_attack_offset_y > 0.0:
		current_attack_offset_y = move_toward(current_attack_offset_y, 0.0, delta * (300.0 / 0.5))

	# 2. Smoothly update slide offset (-60px UP when sliding)
	var target_slide_y: float = 0.0
	if state_machine and state_machine.current_state_type == PlayerStateMachine.StateType.SLIDE:
		target_slide_y = idle_slide_offset_y
	current_slide_offset_y = lerp(current_slide_offset_y, target_slide_y, delta * 10.0)

	# 3. Calculate WASD drag & Y velocity sway offset
	var local_vel = global_transform.basis.inverse() * velocity
	var max_spd = max(move_speed, 1.0)
	var norm_x = clamp(local_vel.x / max_spd, -1.0, 1.0)
	var norm_z = clamp(local_vel.z / max_spd, -1.0, 1.0)

	var max_jump_spd = max(jump_velocity, 1.0)
	var norm_y = clamp(velocity.y / max_jump_spd, -1.0, 1.0)

	var target_drag_x: float = 0.0
	if norm_x > 0.0:
		target_drag_x = - norm_x * idle_drag_max_left
	elif norm_x < 0.0:
		target_drag_x = - norm_x * idle_drag_max_right

	var target_drag_y: float = 0.0
	if norm_z < 0.0:
		target_drag_y += -norm_z * idle_drag_max_down
	elif norm_z > 0.0:
		target_drag_y += -norm_z * idle_drag_max_up

	if norm_y > 0.0:
		target_drag_y += norm_y * idle_drag_max_jump_down
	elif norm_y < 0.0:
		target_drag_y += norm_y * idle_drag_max_fall_up

	var target_drag = Vector2(target_drag_x, target_drag_y)
	current_drag_offset = current_drag_offset.lerp(target_drag, delta * idle_drag_speed)

	# 4. Compute consolidated target_pos
	var target_x = default_idle_position_x + current_drag_offset.x
	var target_y = default_idle_position_y + current_attack_offset_y + current_slide_offset_y + current_drag_offset.y
	var target_pos = Vector2(target_x, target_y)

	# 5. Apply target_pos to idle_sprite
	idle_sprite.position = target_pos


func enter_slide_state() -> void:
	slide_timer = slide_duration
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var capsule = collision_shape.shape as CapsuleShape3D
		var capsule_width: float = capsule.radius * 2.0
		capsule.height = capsule_width
		collision_shape.position.y = capsule_width * 0.5

		if hurtbox_collision_shape:
			if hurtbox_collision_shape.shape is CapsuleShape3D:
				var hb_capsule = hurtbox_collision_shape.shape as CapsuleShape3D
				hb_capsule.height = capsule_width
			hurtbox_collision_shape.position.y = capsule_width * 0.5
	state_machine.transition_to(PlayerStateMachine.StateType.SLIDE)

func restore_hitbox() -> void:
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var capsule = collision_shape.shape as CapsuleShape3D
		capsule.height = default_capsule_height
		collision_shape.position.y = default_capsule_position_y

		if hurtbox_collision_shape:
			if hurtbox_collision_shape.shape is CapsuleShape3D:
				var hb_capsule = hurtbox_collision_shape.shape as CapsuleShape3D
				hb_capsule.height = default_capsule_height
			hurtbox_collision_shape.position.y = default_capsule_position_y


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
	var active_shapecast = shapecast_left if wall_run_side == -1 else shapecast_right
	if active_shapecast and active_shapecast.is_colliding():
		for i in range(active_shapecast.get_collision_count()):
			var collider = active_shapecast.get_collider(i)
			if is_wall_run_surface(collider):
				return true
	return false

func is_wall_run_surface(object: Object) -> bool:
	if not object:
		return false

	# Exclude player, enemies, and trigger areas
	if object is Player or object is StandingEnemy or object is Area3D:
		return false
	if object.get_parent() and (object.get_parent() is Player or object.get_parent() is StandingEnemy):
		return false

	# Explicit WallRunSurface or wall groups
	if object is WallRunSurface or object.is_in_group("wall") or object.is_in_group("walls"):
		return true

	# Check name / script for wall keyword
	var node_name = object.name.to_lower()
	var parent_name = object.get_parent().name.to_lower() if object.get_parent() else ""
	var script_path = str(object.get_script().resource_path).to_lower() if object.get_script() else ""

	if node_name.contains("wall") or parent_name.contains("wall") or script_path.contains("wall"):
		return true

	# StaticBody3D wall geometry (excluding floors, stairs, and traps)
	if object is StaticBody3D or object is CSGShape3D:
		if node_name.contains("floor") or parent_name.contains("floor") or node_name.contains("stair") or parent_name.contains("stair") or node_name.contains("trap") or parent_name.contains("trap"):
			return false
		return true

	return false

func attack() -> void:
	if is_attacking:
		return # Cannot attack while windup or attack animation is active
	if state_machine and state_machine.current_state_type == PlayerStateMachine.StateType.DEAD:
		return

	# If playing post-kill animation, user attack cancels it immediately
	if is_playing_post_kill_anim:
		cancel_post_kill_anim()
	elif is_attack_on_cooldown:
		return

	# Stop any running idle return tween
	if idle_tween and idle_tween.is_running():
		idle_tween.kill()

	# 1. Pause BGM and rewind 1 second
	var sm = get_node_or_null("/root/SoundManager")
	if sm:
		if sm.has_method("rewind_bgm"):
			sm.rewind_bgm(1.0)
		if sm.has_method("pause_bgm"):
			sm.pause_bgm()

	# 2. Collect StandingEnemy targets hit by AttackRayCast
	current_attack_targets.clear()
	if attack_raycast and attack_raycast.is_colliding():
		var col = attack_raycast.get_collider()
		if col is StandingEnemy:
			current_attack_targets.append(col as StandingEnemy)
		elif col and col.get_parent() is StandingEnemy:
			current_attack_targets.append(col.get_parent() as StandingEnemy)

	# 3. Determine if attack is successful (targets array is not empty)
	current_attack_is_success = not current_attack_targets.is_empty()

	# 4. Start windup timer
	is_attacking = true
	attack_windup_timer = attack_windup_time

	# 5. Shift Idle 300px down and switch UI visibility to Attack
	current_attack_offset_y = 300.0
	if idle_sprite:
		idle_sprite.visible = false
	if attack_sprite:
		attack_sprite.visible = true
		if current_attack_is_success:
			attack_sprite.play("success")
		else:
			attack_sprite.play("fail")

func cancel_post_kill_anim() -> void:
	post_kill_anim_queue.clear()
	is_playing_post_kill_anim = false
	current_post_kill_anim = ""
	if attack_sprite:
		if attack_sprite.is_playing() and (attack_sprite.animation == "kapak" or attack_sprite.animation == "cleaning"):
			attack_sprite.stop()
		attack_sprite.visible = false
	if idle_sprite:
		idle_sprite.visible = true

func try_play_next_post_kill_anim() -> void:
	if post_kill_anim_queue.is_empty():
		is_playing_post_kill_anim = false
		current_post_kill_anim = ""
		if attack_sprite:
			attack_sprite.visible = false
		if idle_sprite:
			idle_sprite.visible = true
		return

	var anim_name = post_kill_anim_queue.pop_front()
	is_playing_post_kill_anim = true
	current_post_kill_anim = anim_name

	if idle_sprite:
		idle_sprite.visible = false
	if attack_sprite:
		attack_sprite.visible = true
		if attack_sprite.sprite_frames and attack_sprite.sprite_frames.has_animation(anim_name):
			attack_sprite.play(anim_name)
		else:
			# Fallback if animation is not added to sprite frames yet
			_on_attack_animation_finished()

func _on_attack_animation_finished() -> void:
	if is_attacking:
		is_attacking = false

		# 1. Unpause BGM when attack animation finishes
		var sm = get_node_or_null("/root/SoundManager")
		if sm and sm.has_method("unpause_bgm"):
			sm.unpause_bgm()

		# 2. Deal damage if attack succeeded and check if any enemy was killed
		var killed_any_enemy: bool = false
		if current_attack_is_success:
			for enemy in current_attack_targets:
				if is_instance_valid(enemy) and enemy.has_method("take_damage"):
					if enemy.current_hp <= attack_damage:
						killed_any_enemy = true
					enemy.take_damage(attack_damage)
			is_attack_on_cooldown = true
			attack_cooldown_timer = attack_success_cooldown
		else:
			is_attack_on_cooldown = true
			attack_cooldown_timer = attack_fail_cooldown

		# 3. Roll post-kill animation probabilities if an enemy was killed
		if killed_any_enemy:
			if randf() < kapak_chance:
				post_kill_anim_queue.append("kapak")
			if randf() < cleaning_chance:
				post_kill_anim_queue.append("cleaning")

		# 4. Play next post-kill anim if queue has items, otherwise return UI to Idle
		if not post_kill_anim_queue.is_empty():
			try_play_next_post_kill_anim()
		else:
			if attack_sprite:
				attack_sprite.visible = false
			if idle_sprite:
				idle_sprite.visible = true

	elif is_playing_post_kill_anim:
		is_playing_post_kill_anim = false
		current_post_kill_anim = ""
		if not post_kill_anim_queue.is_empty():
			try_play_next_post_kill_anim()
		else:
			if attack_sprite:
				attack_sprite.visible = false
			if idle_sprite:
				idle_sprite.visible = true

func update_attack_logic(delta: float) -> void:
	if is_attack_on_cooldown:
		attack_cooldown_timer -= delta
		if attack_cooldown_timer <= 0.0:
			is_attack_on_cooldown = false
			current_attack_targets.clear()


func take_damage(amount: int, slow_duration: float = 0.2) -> void:
	if state_machine and state_machine.current_state_type == PlayerStateMachine.StateType.DEAD:
		return

	current_hp -= amount
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.current_hp = current_hp
	update_hp_ui()

	if current_hp <= 0:
		instant_death()
	else:
		get_hit_timer.start(slow_duration)
		state_machine.transition_to(PlayerStateMachine.StateType.GET_HIT)

func heal(amount: int) -> void:
	current_hp = min(max_hp, current_hp + amount)
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.current_hp = current_hp
	update_hp_ui()

func instant_death() -> void:
	if state_machine and state_machine.current_state_type == PlayerStateMachine.StateType.DEAD:
		return

	cancel_post_kill_anim()
	current_hp = 0
	update_hp_ui()
	state_machine.transition_to(PlayerStateMachine.StateType.DEAD)
	velocity = Vector3.ZERO

	# Play random death sound with configured delay
	play_delayed_death_sound()

	# 1. Animate camera falling face-down to the floor over 0.6 seconds
	if camera:
		var death_tween = create_tween().set_parallel(true)
		death_tween.tween_property(camera, "position:y", 0.2, 0.6) \
			.set_trans(Tween.TRANS_QUAD) \
			.set_ease(Tween.EASE_IN)
		death_tween.tween_property(camera, "rotation:x", deg_to_rad(-85.0), 0.6) \
			.set_trans(Tween.TRANS_QUAD) \
			.set_ease(Tween.EASE_IN)

	# 2. Hide CanvasShader/Idle, show CanvasShader/Attack & play "death"
	if idle_sprite:
		idle_sprite.visible = false
	if attack_sprite:
		attack_sprite.visible = true
		if attack_sprite.sprite_frames and attack_sprite.sprite_frames.has_animation("death"):
			attack_sprite.play("death")

	# 3. Wait 3 seconds for death animation to finish before reloading scene
	await get_tree().create_timer(3.0).timeout

	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.current_hp = 0
		gm.trigger_game_over()

func play_delayed_death_sound() -> void:
	if death_sound_delay > 0.0:
		await get_tree().create_timer(death_sound_delay).timeout

	var sm = get_node_or_null("/root/SoundManager")
	if sm and sm.has_method("play_random_death_sound"):
		sm.play_random_death_sound()


func update_hp_ui() -> void:
	if not hp_rect:
		return
	if current_hp > 0:
		var path = "res://assets/ui/ui_hp.%d.png" % current_hp
		if ResourceLoader.exists(path):
			hp_rect.texture = load(path)
		else:
			hp_rect.texture = null
	else:
		hp_rect.texture = null

func update_timer_ui() -> void:
	if not timer_label:
		return
	var total_seconds: int = int(total_game_time)
	var minutes: int = int(float(total_seconds) / 60)
	var seconds: int = total_seconds % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]

func _on_area_entered(area: Area3D) -> void:
	if not area:
		return

	var script_name = ""
	if area.get_script():
		script_name = str(area.get_script().get_global_name())

	if script_name == "FrontGuard" or area.name.contains("FrontGuard"):
		take_damage(1, 0.2)
	elif script_name == "CobwebTrap" or area.name.contains("Cobweb") or area.get("is_cobweb") == true:
		take_damage(0, 1.0)
	elif script_name == "TrapArea" or area.name.contains("TrapArea") or area.name.contains("Trap"):
		if area.get("is_cobweb") == true:
			take_damage(0, 1.0)
		elif area.get("is_instakill") == true:
			instant_death()
		else:
			take_damage(1, 0.2)
	elif script_name == "KillZone" or area.name.contains("KillZone") or area.name.contains("ChasingHorde"):
		instant_death()
