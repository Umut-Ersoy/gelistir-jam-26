extends Node

var bgm_player: AudioStreamPlayer

func _ready() -> void:
	# Initialize AudioStreamPlayer for background music if needed
	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "BGMPlayer"
	add_child(bgm_player)

func rewind_bgm(amount: float = 1.0) -> void:
	if bgm_player and bgm_player.playing:
		var current_pos: float = bgm_player.get_playback_position()
		bgm_player.seek(max(0.0, current_pos - amount))
