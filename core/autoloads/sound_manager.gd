extends Node

var bgm_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer

# { section (int): Array[AudioStream] }
var bgm_library: Dictionary = {}
# Sorted list of section numbers found on disk
var section_order: Array = []

# Current position in section_order (loops back to 0)
var current_section_idx: int = 0
# Tracks the last AudioStream played per section to avoid immediate repeats
var _last_played: Dictionary = {}

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "BGMPlayer"
	bgm_player.bus = "Master"
	add_child(bgm_player)
	bgm_player.finished.connect(_on_bgm_finished)

	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "SFXPlayer"
	sfx_player.bus = "Master"
	add_child(sfx_player)

	_index_bgm_library()

	if section_order.size() > 0:
		_play_current_section()


# ─── Indexing ─────────────────────────────────────────────────────────────────

func _index_bgm_library() -> void:
	bgm_library.clear()
	section_order.clear()

	var dir := DirAccess.open("res://assets/sounds/")
	if not dir:
		push_error("SoundManager: 'res://assets/sounds/' dizini açılamadı.")
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() \
				and file_name.begins_with("bgmusic_") \
				and file_name.ends_with(".wav"):
			_try_register(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	# Sort sections numerically
	section_order = bgm_library.keys()
	section_order.sort()

	print("SoundManager: %d bölüm indexlendi → %s" % [section_order.size(), section_order])
	for sec in section_order:
		print("  Bölüm %d: %d varyant" % [sec, bgm_library[sec].size()])


func _try_register(file_name: String) -> void:
	# Expected format: bgmusic_<section>.<variant>.wav
	# e.g. bgmusic_1.3.wav  →  parts after "_": "1.3.wav"
	var after_prefix := file_name.trim_prefix("bgmusic_").trim_suffix(".wav")
	var dot_parts := after_prefix.split(".")
	if dot_parts.size() != 2:
		return
	if not dot_parts[0].is_valid_int() or not dot_parts[1].is_valid_int():
		return

	var section := dot_parts[0].to_int()
	var path := "res://assets/sounds/" + file_name
	var stream := load(path) as AudioStream
	if not stream:
		push_warning("SoundManager: '%s' yüklenemedi, atlanıyor." % path)
		return

	if not bgm_library.has(section):
		bgm_library[section] = []
	bgm_library[section].append(stream)


# ─── Playback ─────────────────────────────────────────────────────────────────

func _play_current_section() -> void:
	if section_order.is_empty():
		return

	var section: int = section_order[current_section_idx]
	var variants: Array = bgm_library[section]

	# Pick a random variant; avoid repeating the immediately previous one if possible
	var chosen: AudioStream
	if variants.size() == 1:
		chosen = variants[0]
	else:
		var last: AudioStream = _last_played.get(section, null)
		var candidates: Array = variants.filter(func(s: AudioStream) -> bool: return s != last)
		if candidates.is_empty():
			candidates = variants
		chosen = candidates[randi() % candidates.size()]

	_last_played[section] = chosen
	bgm_player.stream = chosen
	bgm_player.play()
	print("SoundManager: Bölüm %d oynuyor (idx %d/%d)" % [
		section, current_section_idx + 1, section_order.size()
	])


func _on_bgm_finished() -> void:
	# Advance to next section, wrap around
	current_section_idx = (current_section_idx + 1) % section_order.size()
	_play_current_section()


# ─── Utilities ────────────────────────────────────────────────────────────────

## Mevcut parçayı `amount` saniye geri sarar.
func rewind_bgm(amount: float = 1.0) -> void:
	if bgm_player and bgm_player.playing:
		var current_pos: float = bgm_player.get_playback_position()
		bgm_player.seek(max(0.0, current_pos - amount))


## Müziği durdurur.
func stop_bgm() -> void:
	if bgm_player:
		bgm_player.stop()

## Müziği duraklatır (pause).
func pause_bgm() -> void:
	if bgm_player:
		bgm_player.stream_paused = true

## Duraklatılan müziği devam ettirir (unpause).
func unpause_bgm() -> void:
	if bgm_player:
		bgm_player.stream_paused = false

## Müziği devam ettirir / başlatır (mevcut bölümden).
func resume_bgm() -> void:
	if bgm_player and not bgm_player.playing:
		bgm_player.play()

## Genel SFX ses çalma metodu
func play_sfx(path: String) -> void:
	var stream = load(path) as AudioStream
	if stream and sfx_player:
		sfx_player.stream = stream
		sfx_player.play()

## Ölüm anında ses-death, ses-death2, ses-death3 varyantlarından birini rastgele çalar
func play_random_death_sound() -> void:
	var death_sounds = [
		"res://assets/ses/ses-death.wav",
		"res://assets/ses/ses-death2.wav",
		"res://assets/ses/ses-death3.wav"
	]
	var chosen_path = death_sounds[randi() % death_sounds.size()]
	play_sfx(chosen_path)

