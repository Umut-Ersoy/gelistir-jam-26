extends CharacterBody3D
class_name StandingEnemy

@export_group("Enemy Stats")
@export var max_hp: int = 2
@export var damage: int = 1

@export_group("Attack Settings")
@export var attack_windup_time: float = 0.5 # Preparation time before dealing damage (seconds)
@export var attack_cooldown: float = 1.2    # Delay between consecutive attacks (seconds)

@onready var visual: Node3D = get_node_or_null("Visual")
@onready var trigger_area: Area3D = get_node_or_null("TriggerArea")

var current_hp: int = 2
var target_player: Player = null
var is_player_in_trigger: bool = false
var is_attacking: bool = false
var is_on_cooldown: bool = false

var windup_timer: float = 0.0
var cooldown_timer: float = 0.0

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	current_hp = max_hp
	_find_player()
	_setup_trigger_signals()

func _setup_trigger_signals() -> void:
	if trigger_area:
		if not trigger_area.body_entered.is_connected(_on_trigger_body_entered):
			trigger_area.body_entered.connect(_on_trigger_body_entered)
		if not trigger_area.body_exited.is_connected(_on_trigger_body_exited):
			trigger_area.body_exited.connect(_on_trigger_body_exited)

		if not trigger_area.area_entered.is_connected(_on_trigger_area_entered):
			trigger_area.area_entered.connect(_on_trigger_area_entered)
		if not trigger_area.area_exited.is_connected(_on_trigger_area_exited):
			trigger_area.area_exited.connect(_on_trigger_area_exited)

func _find_player() -> void:
	if not get_tree() or not get_tree().current_scene:
		return
	target_player = get_node_or_null("../Player") as Player
	if not target_player:
		for child in get_tree().current_scene.get_children():
			if child is Player:
				target_player = child as Player
				break

func _physics_process(delta: float) -> void:
	if not target_player:
		_find_player()

	# Keep visual plane continuously facing the player
	if visual and target_player:
		var look_target = target_player.global_position
		look_target.y = visual.global_position.y
		if visual.global_position.distance_squared_to(look_target) > 0.01:
			visual.look_at(look_target, Vector3.UP)

	# Handle attack windup timer
	if is_attacking:
		windup_timer -= delta
		if windup_timer <= 0.0:
			_execute_attack()

	# Handle attack cooldown timer
	if is_on_cooldown:
		cooldown_timer -= delta
		if cooldown_timer <= 0.0:
			is_on_cooldown = false
			if is_player_in_trigger:
				_try_start_attack()

# ─── Trigger Detection ────────────────────────────────────────────────────────

func _on_trigger_body_entered(body: Node) -> void:
	if body is Player:
		target_player = body as Player
		is_player_in_trigger = true
		_try_start_attack()

func _on_trigger_body_exited(body: Node) -> void:
	if body is Player:
		is_player_in_trigger = false

func _on_trigger_area_entered(area: Area3D) -> void:
	if area and area.get_parent() is Player:
		target_player = area.get_parent() as Player
		is_player_in_trigger = true
		_try_start_attack()

func _on_trigger_area_exited(area: Area3D) -> void:
	if area and area.get_parent() is Player:
		is_player_in_trigger = false

# ─── Attack Logic ─────────────────────────────────────────────────────────────

func _try_start_attack() -> void:
	if is_attacking or is_on_cooldown or current_hp <= 0:
		return

	is_attacking = true
	windup_timer = attack_windup_time
	_on_attack_windup_started()

## Called when attack windup begins (can be overridden for sprite/sound feedback)
func _on_attack_windup_started() -> void:
	pass

func _execute_attack() -> void:
	is_attacking = false
	is_on_cooldown = true
	cooldown_timer = attack_cooldown

	if current_hp <= 0:
		return

	# Deal damage if player is still inside the trigger area and alive
	if is_player_in_trigger and target_player and is_instance_valid(target_player):
		if target_player.has_method("take_damage"):
			target_player.take_damage(damage)

# ─── Damage & Health Management ───────────────────────────────────────────────

## Called when player attacks this enemy
func take_damage(amount: int) -> void:
	if current_hp <= 0:
		return

	current_hp -= amount
	_on_hit_received(amount)

	if current_hp <= 0:
		die()

## Extensible callback when hit is received
func _on_hit_received(_amount: int) -> void:
	pass

## Called when health reaches 0
func die() -> void:
	current_hp = 0
	queue_free()
