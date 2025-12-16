extends Node
## AudioManager handles all music and sound effect playback
## Uses a pool of AudioStreamPlayer nodes for efficient SFX playback

# ============ CONFIGURATION ============
const SFX_POOL_SIZE: int = 16
const MUSIC_FADE_DURATION: float = 1.0

# ============ VOLUME SETTINGS ============
var master_volume: float = 1.0
var music_volume: float = 0.7
var sfx_volume: float = 0.8

# ============ AUDIO PLAYERS ============
var sfx_pool: Array[AudioStreamPlayer] = []
var music_player: AudioStreamPlayer = null
var next_pool_index: int = 0

# ============ AUDIO LIBRARY ============
var sfx_library: Dictionary = {}
var music_library: Dictionary = {}

# ============ CURRENT STATE ============
var current_music: String = ""
var is_fading: bool = false


func _ready() -> void:
	# Create SFX pool
	_create_sfx_pool()

	# Create music player
	_create_music_player()

	# Load audio resources (placeholders for now)
	_load_audio_library()

	print("[AudioManager] Initialized with ", SFX_POOL_SIZE, " SFX players")


# ============ INITIALIZATION ============
func _create_sfx_pool() -> void:
	"""Creates a pool of AudioStreamPlayer nodes for SFX"""
	for i in range(SFX_POOL_SIZE):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "SFXPlayer_" + str(i)
		player.bus = "Master"
		add_child(player)
		sfx_pool.append(player)


func _create_music_player() -> void:
	"""Creates the music player"""
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = "Master"
	add_child(music_player)


func _load_audio_library() -> void:
	"""Loads audio resources into libraries"""
	# Note: These would load actual audio files in production
	# For now, this is a placeholder structure

	# SFX Library
	sfx_library = {
		"attack_1": null,
		"attack_2": null,
		"attack_3": null,
		"player_hurt": null,
		"player_dash": null,
		"enemy_hurt": null,
		"enemy_death": null,
		"spike_extend": null,
		"lever_pull": null,
		"door_open": null,
	}

	# Music Library
	music_library = {
		"test_music": null,
		"combat_music": null,
	}

	print("[AudioManager] Audio library structure loaded")


# ============ SFX PLAYBACK ============
func play_sfx(sfx_name: String, pitch_variation: float = 0.0) -> void:
	"""Plays a sound effect with optional pitch variation"""
	if not sfx_library.has(sfx_name):
		push_warning("[AudioManager] SFX not found: ", sfx_name)
		return

	var audio_stream: AudioStream = sfx_library[sfx_name]

	# Skip if no audio loaded (placeholder mode)
	if audio_stream == null:
		# print("[AudioManager] SFX placeholder: ", sfx_name)
		return

	# Get next available player from pool
	var player: AudioStreamPlayer = sfx_pool[next_pool_index]
	next_pool_index = (next_pool_index + 1) % SFX_POOL_SIZE

	# Configure and play
	player.stream = audio_stream
	player.volume_db = linear_to_db(sfx_volume * master_volume)

	# Apply pitch variation
	if pitch_variation > 0.0:
		player.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
	else:
		player.pitch_scale = 1.0

	player.play()


func play_sfx_at_position(sfx_name: String, _position: Vector2, pitch_variation: float = 0.0) -> void:
	"""Plays a positioned sound effect (uses same pool for now)"""
	# In a full implementation, this would use AudioStreamPlayer2D for spatial audio
	# Position parameter reserved for future spatial audio implementation
	play_sfx(sfx_name, pitch_variation)


# ============ MUSIC PLAYBACK ============
func play_music(track_name: String, fade_in: bool = true) -> void:
	"""Plays a music track with optional fade-in"""
	if current_music == track_name and music_player.playing:
		return  # Already playing this track

	if not music_library.has(track_name):
		push_warning("[AudioManager] Music track not found: ", track_name)
		return

	var audio_stream: AudioStream = music_library[track_name]

	# Skip if no audio loaded (placeholder mode)
	if audio_stream == null:
		print("[AudioManager] Music placeholder: ", track_name)
		current_music = track_name
		return

	# Stop current music
	if music_player.playing:
		if fade_in:
			await fade_out_music()
		else:
			music_player.stop()

	# Play new music
	music_player.stream = audio_stream
	music_player.volume_db = linear_to_db(music_volume * master_volume)

	if fade_in:
		await fade_in_music()
	else:
		music_player.play()

	current_music = track_name
	print("[AudioManager] Playing music: ", track_name)


func stop_music(fade_out: bool = true) -> void:
	"""Stops the current music"""
	if not music_player.playing:
		return

	if fade_out:
		await fade_out_music()
	else:
		music_player.stop()

	current_music = ""


func fade_in_music() -> void:
	"""Fades in the music player"""
	if is_fading:
		return

	is_fading = true
	music_player.volume_db = -80.0
	music_player.play()

	var tween: Tween = create_tween()
	tween.tween_property(
		music_player,
		"volume_db",
		linear_to_db(music_volume * master_volume),
		MUSIC_FADE_DURATION
	)
	await tween.finished

	is_fading = false


func fade_out_music() -> void:
	"""Fades out the music player"""
	if is_fading:
		return

	is_fading = true

	var tween: Tween = create_tween()
	tween.tween_property(music_player, "volume_db", -80.0, MUSIC_FADE_DURATION)
	await tween.finished

	music_player.stop()
	is_fading = false


# ============ VOLUME CONTROL ============
func set_master_volume(volume: float) -> void:
	"""Sets master volume (0.0 to 1.0)"""
	master_volume = clamp(volume, 0.0, 1.0)
	_update_volumes()


func set_music_volume(volume: float) -> void:
	"""Sets music volume (0.0 to 1.0)"""
	music_volume = clamp(volume, 0.0, 1.0)
	_update_volumes()


func set_sfx_volume(volume: float) -> void:
	"""Sets SFX volume (0.0 to 1.0)"""
	sfx_volume = clamp(volume, 0.0, 1.0)


func _update_volumes() -> void:
	"""Updates all active audio players with new volume settings"""
	if music_player and music_player.playing:
		music_player.volume_db = linear_to_db(music_volume * master_volume)
