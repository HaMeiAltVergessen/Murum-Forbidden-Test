extends Node
## AudioManager handles all music and sound effect playback
## Uses a pool of AudioStreamPlayer nodes for efficient SFX playback

# ============ CONFIGURATION ============
const SFX_POOL_SIZE: int = 16
const MUSIC_FADE_DURATION: float = 1.0

# ============ VOLUME SETTINGS ============
var master_volume: float = 1.0
var music_volume: float = 0.4
var sfx_volume: float = 0.3

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
	# Base path for Gothicvania sounds (best thematic fit)
	var sfx_base = "res://Assets/Placeholder/Legacy Collection/Assets/Packs/Gothicvania Church/Stomper Asset Files/fx/"
	var sewers_sfx = "res://Assets/Placeholder/Legacy Collection/Assets/Packs/Sewers pack files/Sounds/"
	var space_sfx = "res://Assets/Placeholder/Legacy Collection/Assets/Packs/SpaceShooter/Space Shooter files/Sound FX/"
	var meta_sfx = "res://Assets/Placeholder/Legacy Collection/Assets/Packs/Meta data assets files/sounds/fx/"

	# SFX Library
	sfx_library = {
		# Player combat
		"attack_1": load(sfx_base + "attack.wav"),
		"attack_2": load(sfx_base + "attack.wav"),
		"attack_3": load(sfx_base + "stomp.wav"),  # Heavier sound for 3rd attack
		"player_hurt": load(sfx_base + "hurt.wav"),
		"player_dash": load(sfx_base + "stomp.wav"),
		"player_death": load(sewers_sfx + "player-death.wav"),

		# Combat impacts
		"hit_impact": load(sfx_base + "hit.wav"),
		"block": load(sfx_base + "hit.wav"),
		"parry": load(space_sfx + "hit.wav"),

		# Enemy
		"enemy_hurt": load(sfx_base + "hurt.wav"),
		"enemy_death": load(sfx_base + "enemy_death.wav"),
		"enemy_attack": load(sfx_base + "attack.wav"),

		# Abilities
		"ability_machtstoss": load(space_sfx + "shot 1.wav"),
		"ability_machtbruch": load(sfx_base + "stomp.wav"),
		"ability_urteil": load(sewers_sfx + "explosion.wav"),
		"ability_wolkenbruch": load(sewers_sfx + "explosion.wav"),
		"ability_echo": load(meta_sfx + "shooter.wav"),

		# Environment
		"spike_extend": load(meta_sfx + "thorn.wav"),
		"lever_pull": load(meta_sfx + "select.wav"),
		"door_open": load(sfx_base + "door.wav"),
		"checkpoint": load(meta_sfx + "complete.ogg"),
		"pickup_coin": load(sfx_base + "pick.wav"),

		# Projectiles
		"projectile_fire": load(sewers_sfx + "shot.wav"),
	}

	# Music Library
	music_library = {
		"test_music": load("res://Assets/Placeholder/Legacy Collection/Assets/Packs/Meta data assets files/sounds/music/determination.ogg"),
		"combat_music": load("res://Assets/Placeholder/Legacy Collection/Assets/Packs/Meta data assets files/sounds/music/ghost-town.ogg"),
	}

	print("[AudioManager] Audio library loaded with ", sfx_library.size(), " SFX and ", music_library.size(), " music tracks")


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

	# Dark Fantasy/Sci-Fi base pitch (0.75 = darker, more ominous)
	var base_pitch = 0.75

	# Apply pitch variation on top of base pitch
	if pitch_variation > 0.0:
		player.pitch_scale = base_pitch * randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
	else:
		player.pitch_scale = base_pitch

	player.play()


func play_sfx_at_position(sfx_name: String, _position: Vector2, pitch_variation: float = 0.0) -> void:
	"""Plays a positioned sound effect (uses same pool for now)"""
	# In a full implementation, this would use AudioStreamPlayer2D for spatial audio
	# Position parameter reserved for future spatial audio implementation
	# Dark fantasy pitch is applied in play_sfx
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
