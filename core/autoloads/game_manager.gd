extends Node

var current_hp: int = 3
var max_hp: int = 3
var score: int = 0
var accumulated_time: float = 0.0
var is_game_over: bool = false

func reset_game() -> void:
	current_hp = max_hp
	score = 0
	accumulated_time = 0.0
	is_game_over = false

func trigger_game_over() -> void:
	is_game_over = true
	reset_game()
	if get_tree():
		get_tree().reload_current_scene()

func update_score(delta: float) -> void:
	if is_game_over:
		return
	accumulated_time += delta
	if accumulated_time >= 1.0:
		accumulated_time -= 1.0
		score += 1
