extends Node
class_name PlayerStateMachine

enum StateType {
	GROUNDED,
	JUMP,
	FALL,
	SLIDE,
	WALL_RUN,
	GET_HIT,
	DEAD
}

signal state_changed(old_state_type: StateType, new_state_type: StateType)

var current_state_type: StateType = StateType.GROUNDED
var previous_state_type: StateType = StateType.GROUNDED

var player: CharacterBody3D

func init(p_player: CharacterBody3D) -> void:
	player = p_player

func transition_to(new_state_type: StateType) -> void:
	if current_state_type == StateType.DEAD and new_state_type != StateType.DEAD:
		# Cannot transition out of DEAD state
		return

	if current_state_type == new_state_type:
		return

	previous_state_type = current_state_type
	current_state_type = new_state_type
	state_changed.emit(previous_state_type, current_state_type)

func get_state_name(state_type: StateType) -> String:
	match state_type:
		StateType.GROUNDED: return "GROUNDED"
		StateType.JUMP: return "JUMP"
		StateType.FALL: return "FALL"
		StateType.SLIDE: return "SLIDE"
		StateType.WALL_RUN: return "WALL_RUN"
		StateType.GET_HIT: return "GET_HIT"
		StateType.DEAD: return "DEAD"
		_: return "UNKNOWN"
