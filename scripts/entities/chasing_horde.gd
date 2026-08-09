extends Area3D
class_name ChasingHorde

@export var speed: float = 6.5
@export var start_delay: float = 3.0
@export var path_recalc_interval: float = 0.15 # Recalculate A* path 6-7 times per sec

@onready var visual: Node3D = get_node_or_null("Visual")

var target_player: Node3D = null
var dungeon_gen: DungeonGenerator = null
var delay_timer: float = 0.0
var is_active: bool = false

var current_path: PackedVector3Array = []
var path_recalc_timer: float = 0.0

func _ready() -> void:
	delay_timer = start_delay
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_find_player()
	_find_dungeon_gen()

func _find_player() -> void:
	target_player = get_node_or_null("../Player")
	if not target_player and get_tree() and get_tree().current_scene:
		for child in get_tree().current_scene.get_children():
			if child is Player:
				target_player = child
				break

func _find_dungeon_gen() -> void:
	dungeon_gen = get_node_or_null("../DungeonGenerator") as DungeonGenerator
	if not dungeon_gen and get_tree() and get_tree().current_scene:
		for child in get_tree().current_scene.get_children():
			if child is DungeonGenerator:
				dungeon_gen = child as DungeonGenerator
				break

func _physics_process(delta: float) -> void:
	if not target_player:
		_find_player()
	if not dungeon_gen:
		_find_dungeon_gen()

	if delay_timer > 0.0:
		delay_timer -= delta
		if delay_timer <= 0.0:
			is_active = true

	if not is_active or not target_player:
		return

	# Stop movement if player is dead
	if target_player.get("state_machine"):
		var sm = target_player.get("state_machine")
		if sm and sm.get("current_state_type") == 4: # PlayerStateMachine.StateType.DEAD
			return

	# Recalculate shortest A* path periodically
	path_recalc_timer -= delta
	if path_recalc_timer <= 0.0 or current_path.is_empty():
		path_recalc_timer = path_recalc_interval
		_recalculate_path()

	# Move along current A* path
	_move_along_path(delta)


func _recalculate_path() -> void:
	if dungeon_gen and dungeon_gen.has_method("get_astar_path") and target_player:
		var new_path = dungeon_gen.get_astar_path(global_position, target_player.global_position)
		if new_path.size() > 0:
			current_path = new_path

func _move_along_path(delta: float) -> void:
	if current_path.is_empty():
		# Fallback if path is empty: direct movement towards player
		var target_pos = target_player.global_position
		target_pos.y = global_position.y
		var dir = (target_pos - global_position)
		if dir.length() > 0.1:
			global_position += dir.normalized() * speed * delta
		return

	var target_pt = current_path[0]
	var to_pt = target_pt - global_position
	var dist = to_pt.length()

	if dist < 0.4:
		current_path.remove_at(0)
		if current_path.is_empty():
			return
		target_pt = current_path[0]
		to_pt = target_pt - global_position
		dist = to_pt.length()

	if dist > 0.01:
		var dir = to_pt.normalized()
		global_position += dir * min(speed * delta, dist)

func _on_body_entered(body: Node) -> void:
	_check_and_kill(body)

func _on_area_entered(area: Area3D) -> void:
	if area and area.get_parent():
		_check_and_kill(area.get_parent())

func _check_and_kill(node: Node) -> void:
	if not node:
		return
	if node is Player or node.has_method("instant_death"):
		if node.has_method("instant_death"):
			node.instant_death()
