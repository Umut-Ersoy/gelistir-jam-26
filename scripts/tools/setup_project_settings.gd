@tool
extends SceneTree

func _init() -> void:
	print("--- Running Godot CLI: Setting up Project Settings & Input Map ---")

	# Autoloads
	ProjectSettings.set_setting("autoload/GameManager", "*res://core/autoloads/game_manager.gd")
	ProjectSettings.set_setting("autoload/SoundManager", "*res://core/autoloads/sound_manager.gd")

	# Input Actions Configuration
	setup_input_action("move_forward", KEY_W)
	setup_input_action("move_backward", KEY_S)
	setup_input_action("move_left", KEY_A)
	setup_input_action("move_right", KEY_D)
	setup_input_action("jump", KEY_SPACE)
	setup_input_action("slide", KEY_CTRL)
	setup_input_mouse_action("attack", MOUSE_BUTTON_LEFT)

	# Save settings to project.godot
	var err = ProjectSettings.save()
	if err == OK:
		print("Successfully saved project settings & InputMap to project.godot!")
	else:
		print("Error saving project settings: ", err)

	quit()

func setup_input_action(action_name: String, key_code: Key) -> void:
	var setting_path = "input/" + action_name
	var key_event = InputEventKey.new()
	key_event.physical_keycode = key_code

	var action_dict = {
		"deadzone": 0.5,
		"events": [key_event]
	}
	ProjectSettings.set_setting(setting_path, action_dict)

func setup_input_mouse_action(action_name: String, button_index: MouseButton) -> void:
	var setting_path = "input/" + action_name
	var mouse_event = InputEventMouseButton.new()
	mouse_event.button_index = button_index

	var action_dict = {
		"deadzone": 0.5,
		"events": [mouse_event]
	}
	ProjectSettings.set_setting(setting_path, action_dict)
