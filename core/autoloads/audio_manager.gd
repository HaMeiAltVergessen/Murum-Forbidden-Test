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
		player.bus = "SFX"  # Route to SFX bus for volume control
		add_child(player)
		sfx_pool.append(player)


func _create_music_player() -> void:
	"""Creates the music player"""
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = "Music"  # Route to Music bus for volume control
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

	# Music Library — values are AudioStream or Array[AudioStream] for random selection
	var m: String = "res://Music/"
	var w1: String = "res://Music/welt1/"
	var w2: String = "res://Music/welt2/"
	var w3: String = "res://Music/welt3/"

	music_library = {
		# === GLOBAL ===
		"main_theme": load(m + "MainTheme001.mp3"),
		"bossfight": [load(m + "bossfight_v1.mp3"), load(m + "bossfight_v2.mp3")],
		"lythrun": [load(m + "lythrun_v1.mp3"), load(m + "lythrun_v2.mp3"), load(m + "lythrun_boss_4_v2.mp3")],
		"lythrun_boss_4": [load(m + "lythrun_boss_4_v1.mp3"), load(m + "lythrun_boss_4_v2.mp3"), load(m + "lythrun_boss_4_v3.mp3"), load(m + "lythrun_boss_4_v4.mp3")],
		"lythrun_boss_5": [load(m + "lythrun_boss_5_v1.mp3"), load(m + "lythrun_boss_5_v2.mp3")],

		# === WELT 1 — DAS NIEMANDSLAND ===
		"w1_ruins": [load(m + "w1_ruins_v1.mp3"), load(m + "w1_ruins_v2.mp3")],
		"w1_temple": load(m + "w1_temple.mp3"),
		"w1_boss_buildup": [load(m + "w1_boss_buildup_v1.mp3"), load(m + "w1_boss_buildup_v2.mp3")],
		"w1_kampf": [load(w1 + "w1_kampf_v1.mp3"), load(w1 + "w1_kampf_v2.mp3")],
		"w1_elite": [load(w1 + "w1_elite_v1.mp3"), load(w1 + "w1_elite_v2.mp3")],
		"w1_event": [load(w1 + "w1_event_v1.mp3"), load(w1 + "w1_event_v2.mp3")],
		"w1_haendler": load(w1 + "w1_haendler.mp3"),
		"w1_schatz": load(w1 + "w1_schatz.mp3"),
		"w1_boss_oathbound_heroes": [load(w1 + "w1_boss_oathbound_heroes_v1.mp3"), load(w1 + "w1_boss_oathbound_heroes_v2.mp3")],
		"w1_boss_temple_prayers": [load(w1 + "w1_boss_temple_prayers_v1.mp3"), load(w1 + "w1_boss_temple_prayers_v2.mp3")],
		"w1_boss_broken_oaths": [load(w1 + "w1_boss_broken_oaths_v1.mp3"), load(w1 + "w1_boss_broken_oaths_v2.mp3"), load(w1 + "w1_boss_broken_oaths_v3.mp3")],

		# === WELT 2 — DAS KOLLEKTIV ===
		"w2_ambient": load(m + "w2_ambient.mp3"),
		"w2_rise": [load(m + "w2_rise_v1.mp3"), load(m + "w2_rise_v2.mp3")],
		"w2_kampf": load(w2 + "w2_kampf.mp3"),
		"w2_elite": load(w2 + "w2_elite.mp3"),
		"w2_event": load(w2 + "w2_event.mp3"),
		"w2_haendler": load(w2 + "w2_haendler.mp3"),
		"w2_schatz": [load(w2 + "w2_schatz_v1.mp3"), load(w2 + "w2_schatz_v2.mp3")],
		"w2_boss_one_voice": [load(w2 + "w2_boss_one_voice_v1.mp3"), load(w2 + "w2_boss_one_voice_v2.mp3")],
		"w2_boss_living_armada": [load(w2 + "w2_boss_living_armada_v1.mp3"), load(w2 + "w2_boss_living_armada_v2.mp3")],
		"w2_boss_judgment": load(w2 + "w2_boss_judgment.mp3"),

		# === WELT 3 — DER ABGRUND ===
		"w3_leere": [load(m + "w3_leere_v1.mp3"), load(m + "w3_leere_v2.mp3")],
		"w3_run": [load(m + "w3_run_v1.mp3"), load(m + "w3_run_v2.mp3")],
		"w3_spiegel": load(m + "w3_spiegel.mp3"),
		"w3_kampf": [load(w3 + "w3_kampf_v1.mp3"), load(w3 + "w3_kampf_v2.mp3"), load(w3 + "w3_kampf_v3.mp3")],
		"w3_elite": [load(w3 + "w3_elite_v1.mp3"), load(w3 + "w3_elite_v2.mp3")],
		"w3_event": [load(w3 + "w3_event_v1.mp3"), load(w3 + "w3_event_v2.mp3")],
		"w3_haendler": [load(w3 + "w3_haendler_v1.mp3"), load(w3 + "w3_haendler_v2.mp3")],
		"w3_schatz": [load(w3 + "w3_schatz_v1.mp3"), load(w3 + "w3_schatz_v2.mp3")],
		"w3_boss": [load(w3 + "w3_boss_v1.mp3"), load(w3 + "w3_boss_v2.mp3")],
		"w3_boss_endless_chase": [load(w3 + "w3_boss_endless_chase_v1.mp3"), load(w3 + "w3_boss_endless_chase_v2.mp3")],
		"w3_boss_finale": load(w3 + "w3_boss_finale.mp3"),

		# === LEGACY (Placeholder) ===
		"test_music": load("res://Assets/Placeholder/Legacy Collection/Assets/Packs/Meta data assets files/sounds/music/determination.ogg"),
		"combat_music": load("res://Assets/Placeholder/Legacy Collection/Assets/Packs/Meta data assets files/sounds/music/ghost-town.ogg"),
	}

	var track_count: int = 0
	for key in music_library:
		var val = music_library[key]
		if val is Array:
			track_count += val.size()
		else:
			track_count += 1
	print("[AudioManager] Audio library loaded with ", sfx_library.size(), " SFX and ", track_count, " music tracks (", music_library.size(), " keys)")


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
	# Volume is controlled by the SFX audio bus via SettingsManager
	player.volume_db = 0.0

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


func play_sfx_stream(stream: AudioStream, volume_db: float = 0.0, pitch_variation: float = 0.0) -> void:
	"""Plays a direct AudioStream (used for Inspector-exposed @export sounds)"""
	if stream == null:
		return

	var player: AudioStreamPlayer = sfx_pool[next_pool_index]
	next_pool_index = (next_pool_index + 1) % SFX_POOL_SIZE

	player.stream = stream
	player.volume_db = volume_db

	var base_pitch = 0.75
	if pitch_variation > 0.0:
		player.pitch_scale = base_pitch * randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
	else:
		player.pitch_scale = base_pitch

	player.play()


# ============ MUSIC PLAYBACK ============
func play_music(track_name: String, fade_in: bool = true) -> void:
	"""Plays a music track with optional fade-in. If multiple variants exist, picks one randomly."""
	if current_music == track_name and music_player.playing:
		return  # Already playing this track

	if not music_library.has(track_name):
		push_warning("[AudioManager] Music track not found: ", track_name)
		return

	var entry = music_library[track_name]
	var audio_stream: AudioStream = null

	if entry is Array:
		var tracks: Array = entry
		if tracks.is_empty():
			return
		audio_stream = tracks[randi() % tracks.size()]
	else:
		audio_stream = entry

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
	# Volume is controlled by the Music audio bus via SettingsManager
	music_player.volume_db = 0.0

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
	# Fade to 0 dB (full volume) - actual volume is controlled by Music bus
	tween.tween_property(
		music_player,
		"volume_db",
		0.0,
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
# Note: Volume is now controlled via SettingsManager and audio buses (Master, Music, SFX)
# These methods are kept for backwards compatibility but delegate to SettingsManager

func set_master_volume(volume: float) -> void:
	"""Sets master volume (0.0 to 1.0) - delegates to SettingsManager"""
	if SettingsManager:
		SettingsManager.set_master_volume(volume)


func set_music_volume(volume: float) -> void:
	"""Sets music volume (0.0 to 1.0) - delegates to SettingsManager"""
	if SettingsManager:
		SettingsManager.set_music_volume(volume)


func set_sfx_volume(volume: float) -> void:
	"""Sets SFX volume (0.0 to 1.0) - delegates to SettingsManager"""
	if SettingsManager:
		SettingsManager.set_sfx_volume(volume)
