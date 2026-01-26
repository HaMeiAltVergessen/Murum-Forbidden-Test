extends Node

## SettingsManager - Zentrale Verwaltung für alle Spiel-Einstellungen
## Godot 4.4 kompatibel
## COMMIT 017: Options Menu Foundation

# ============================================================================
# CONSTANTS
# ============================================================================

const SETTINGS_FILE = "user://settings.cfg"
const CONFIG_SECTION_AUDIO = "audio"
const CONFIG_SECTION_VIDEO = "video"
const CONFIG_SECTION_INPUT = "input"
const CONFIG_SECTION_GAMEPLAY = "gameplay"
const CONFIG_SECTION_CUTSCENE = "cutscene"

# ============================================================================
# SIGNALS
# ============================================================================

signal settings_loaded()
signal settings_saved()
signal audio_settings_changed(master: float, music: float, sfx: float)
signal video_settings_changed()
signal input_settings_changed()
signal cutscene_settings_changed()

# ============================================================================
# AUDIO SETTINGS
# ============================================================================

var master_volume: float = 0.8  ## 0.0 - 1.0
var music_volume: float = 0.7
var sfx_volume: float = 0.8

# Audio Bus Indices (cached)
var master_bus_index: int = 0
var music_bus_index: int = 1
var sfx_bus_index: int = 2

# ============================================================================
# VIDEO SETTINGS
# ============================================================================

var window_mode: int = 0  ## 0=Windowed, 1=Fullscreen, 2=Borderless
var resolution_index: int = 2  ## Index into resolution_options
var brightness: float = 1.0  ## 0.5 - 1.5
var vsync_enabled: bool = true

# Available resolutions
var resolution_options: Array[Vector2i] = [
	Vector2i(1280, 720),   # 0: 720p
	Vector2i(1600, 900),   # 1: 900p
	Vector2i(1920, 1080),  # 2: 1080p (default)
	Vector2i(2560, 1440),  # 3: 1440p
	Vector2i(3840, 2160)   # 4: 4K
]

# ============================================================================
# INPUT SETTINGS
# ============================================================================

var preferred_input_device: int = 0  ## 0=Auto, 1=Keyboard, 2=Gamepad

# ============================================================================
# CUTSCENE / SUBTITLE SETTINGS
# ============================================================================

var subtitles_enabled: bool = true  ## Untertitel ein/aus
var subtitle_size: int = 1  ## 0=Klein, 1=Mittel, 2=Groß
var subtitle_fade_speed: float = 0.3  ## Fade-Dauer in Sekunden (0.1 - 1.0)

# Subtitle size enum values for reference
enum SubtitleSize { SMALL = 0, MEDIUM = 1, LARGE = 2 }

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Cache audio bus indices
	_cache_audio_bus_indices()

	# Load settings from file (or create defaults)
	load_settings()

	# Apply loaded settings
	apply_all_settings()

	print("[SettingsManager] Initialized")
	print("[SettingsManager] Audio: Master=%.2f, Music=%.2f, SFX=%.2f" % [master_volume, music_volume, sfx_volume])
	print("[SettingsManager] Video: Window=%d, Resolution=%s, Brightness=%.2f" % [window_mode, str(resolution_options[resolution_index]), brightness])

func _cache_audio_bus_indices() -> void:
	"""Caches audio bus indices for faster access"""
	print("[SettingsManager] Audio bus count: %d" % AudioServer.bus_count)
	for i in range(AudioServer.bus_count):
		print("[SettingsManager] Bus %d: %s" % [i, AudioServer.get_bus_name(i)])

	master_bus_index = AudioServer.get_bus_index("Master")
	music_bus_index = AudioServer.get_bus_index("Music")
	sfx_bus_index = AudioServer.get_bus_index("SFX")

	print("[SettingsManager] Bus indices - Master: %d, Music: %d, SFX: %d" % [master_bus_index, music_bus_index, sfx_bus_index])

	# Master should always exist at index 0
	if master_bus_index == -1:
		push_warning("[SettingsManager] Master bus not found, using index 0")
		master_bus_index = 0

	# If Music bus doesn't exist, fall back to Master
	if music_bus_index == -1:
		push_warning("[SettingsManager] Music bus not found, falling back to Master")
		music_bus_index = master_bus_index

	# If SFX bus doesn't exist, fall back to Master
	if sfx_bus_index == -1:
		push_warning("[SettingsManager] SFX bus not found, falling back to Master")
		sfx_bus_index = master_bus_index

# ============================================================================
# AUDIO METHODS
# ============================================================================

func set_master_volume(volume: float) -> void:
	"""Sets master volume (0.0 - 1.0)"""
	master_volume = clamp(volume, 0.0, 1.0)
	print("[SettingsManager] Setting master volume: %.2f (bus %d)" % [master_volume, master_bus_index])
	_apply_audio_volume(master_bus_index, master_volume)
	audio_settings_changed.emit(master_volume, music_volume, sfx_volume)

func set_music_volume(volume: float) -> void:
	"""Sets music volume (0.0 - 1.0)"""
	music_volume = clamp(volume, 0.0, 1.0)
	print("[SettingsManager] Setting music volume: %.2f (bus %d)" % [music_volume, music_bus_index])
	_apply_audio_volume(music_bus_index, music_volume)
	audio_settings_changed.emit(master_volume, music_volume, sfx_volume)

func set_sfx_volume(volume: float) -> void:
	"""Sets SFX volume (0.0 - 1.0)"""
	sfx_volume = clamp(volume, 0.0, 1.0)
	print("[SettingsManager] Setting SFX volume: %.2f (bus %d)" % [sfx_volume, sfx_bus_index])
	_apply_audio_volume(sfx_bus_index, sfx_volume)
	audio_settings_changed.emit(master_volume, music_volume, sfx_volume)

func _apply_audio_volume(bus_index: int, volume: float) -> void:
	"""Applies volume to audio bus (converts linear to dB)"""
	# Safety check: ensure bus index is valid
	if bus_index < 0 or bus_index >= AudioServer.bus_count:
		push_warning("[SettingsManager] Invalid bus index %d, skipping volume change" % bus_index)
		return

	if volume <= 0.0:
		# Mute the bus
		AudioServer.set_bus_mute(bus_index, true)
	else:
		# Unmute and set volume
		AudioServer.set_bus_mute(bus_index, false)
		# Convert linear (0.0-1.0) to dB (-80 to 0)
		var db = linear_to_db(volume)
		AudioServer.set_bus_volume_db(bus_index, db)

# ============================================================================
# VIDEO METHODS
# ============================================================================

func set_window_mode(mode: int) -> void:
	"""Sets window mode (0=Windowed, 1=Fullscreen, 2=Borderless)"""
	window_mode = clamp(mode, 0, 2)
	_apply_window_mode()
	video_settings_changed.emit()

func set_resolution(index: int) -> void:
	"""Sets resolution by index"""
	resolution_index = clamp(index, 0, resolution_options.size() - 1)
	_apply_resolution()
	video_settings_changed.emit()

func set_brightness(value: float) -> void:
	"""Sets brightness (0.5 - 1.5)"""
	brightness = clamp(value, 0.5, 1.5)
	_apply_brightness()
	video_settings_changed.emit()

func set_vsync(enabled: bool) -> void:
	"""Enables/disables VSync"""
	vsync_enabled = enabled
	_apply_vsync()
	video_settings_changed.emit()

func _apply_window_mode() -> void:
	"""Applies window mode setting"""
	var window = get_window()

	match window_mode:
		0:  # Windowed
			window.mode = Window.MODE_WINDOWED
		1:  # Fullscreen
			window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		2:  # Borderless
			window.mode = Window.MODE_FULLSCREEN

func _apply_resolution() -> void:
	"""Applies resolution setting"""
	var window = get_window()
	var resolution = resolution_options[resolution_index]

	# Only apply if windowed (fullscreen uses native resolution)
	if window.mode == Window.MODE_WINDOWED:
		window.size = resolution
		# Center window
		var screen_size = DisplayServer.screen_get_size()
		var window_pos = (screen_size - resolution) / 2
		window.position = window_pos

func _apply_brightness() -> void:
	"""Applies brightness setting via CanvasModulate"""
	# Find or create CanvasModulate for brightness
	var brightness_modulate = get_tree().root.get_node_or_null("BrightnessModulate")

	if not brightness_modulate:
		brightness_modulate = CanvasModulate.new()
		brightness_modulate.name = "BrightnessModulate"
		# Use call_deferred to avoid "Parent node is busy setting up children" error
		get_tree().root.call_deferred("add_child", brightness_modulate)
		# Also defer the color setting to ensure the node is added first
		brightness_modulate.set_deferred("color", Color(brightness, brightness, brightness, 1.0))
		return

	brightness_modulate.color = Color(brightness, brightness, brightness, 1.0)

func _apply_vsync() -> void:
	"""Applies VSync setting"""
	if vsync_enabled:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

# ============================================================================
# INPUT METHODS
# ============================================================================

func set_preferred_input_device(device: int) -> void:
	"""Sets preferred input device (0=Auto, 1=Keyboard, 2=Gamepad)"""
	preferred_input_device = clamp(device, 0, 2)
	input_settings_changed.emit()

# ============================================================================
# CUTSCENE / SUBTITLE METHODS
# ============================================================================

func set_subtitles_enabled(enabled: bool) -> void:
	"""Enables/disables subtitles"""
	subtitles_enabled = enabled
	cutscene_settings_changed.emit()

func set_subtitle_size(size: int) -> void:
	"""Sets subtitle size (0=Small, 1=Medium, 2=Large)"""
	subtitle_size = clamp(size, 0, 2)
	cutscene_settings_changed.emit()

func set_subtitle_fade_speed(speed: float) -> void:
	"""Sets subtitle fade duration (0.1 - 1.0 seconds)"""
	subtitle_fade_speed = clamp(speed, 0.1, 1.0)
	cutscene_settings_changed.emit()

func get_setting(setting_name: String, default_value: Variant = null) -> Variant:
	"""Generic getter for any setting by name"""
	match setting_name:
		"subtitles_enabled":
			return subtitles_enabled
		"subtitle_size":
			return subtitle_size
		"subtitle_fade_speed":
			return subtitle_fade_speed
		"master_volume":
			return master_volume
		"music_volume":
			return music_volume
		"sfx_volume":
			return sfx_volume
		"window_mode":
			return window_mode
		"resolution_index":
			return resolution_index
		"brightness":
			return brightness
		"vsync_enabled":
			return vsync_enabled
		"preferred_input_device":
			return preferred_input_device
		_:
			return default_value

# ============================================================================
# APPLY ALL
# ============================================================================

func apply_all_settings() -> void:
	"""Applies all current settings"""
	# Audio
	_apply_audio_volume(master_bus_index, master_volume)
	_apply_audio_volume(music_bus_index, music_volume)
	_apply_audio_volume(sfx_bus_index, sfx_volume)

	# Video
	_apply_window_mode()
	_apply_resolution()
	_apply_brightness()
	_apply_vsync()

	print("[SettingsManager] All settings applied")

# ============================================================================
# SAVE/LOAD
# ============================================================================

func save_settings() -> bool:
	"""Saves all settings to config file"""
	var config = ConfigFile.new()

	# Audio section
	config.set_value(CONFIG_SECTION_AUDIO, "master_volume", master_volume)
	config.set_value(CONFIG_SECTION_AUDIO, "music_volume", music_volume)
	config.set_value(CONFIG_SECTION_AUDIO, "sfx_volume", sfx_volume)

	# Video section
	config.set_value(CONFIG_SECTION_VIDEO, "window_mode", window_mode)
	config.set_value(CONFIG_SECTION_VIDEO, "resolution_index", resolution_index)
	config.set_value(CONFIG_SECTION_VIDEO, "brightness", brightness)
	config.set_value(CONFIG_SECTION_VIDEO, "vsync_enabled", vsync_enabled)

	# Input section
	config.set_value(CONFIG_SECTION_INPUT, "preferred_input_device", preferred_input_device)

	# Cutscene section
	config.set_value(CONFIG_SECTION_CUTSCENE, "subtitles_enabled", subtitles_enabled)
	config.set_value(CONFIG_SECTION_CUTSCENE, "subtitle_size", subtitle_size)
	config.set_value(CONFIG_SECTION_CUTSCENE, "subtitle_fade_speed", subtitle_fade_speed)

	# Save to file
	var error = config.save(SETTINGS_FILE)

	if error != OK:
		push_error("[SettingsManager] Failed to save settings: %d" % error)
		return false

	print("[SettingsManager] Settings saved to: %s" % SETTINGS_FILE)
	settings_saved.emit()
	return true

func load_settings() -> bool:
	"""Loads settings from config file (or creates defaults)"""
	var config = ConfigFile.new()
	var error = config.load(SETTINGS_FILE)

	if error != OK:
		print("[SettingsManager] No settings file found, using defaults")
		return false

	# Load Audio
	master_volume = config.get_value(CONFIG_SECTION_AUDIO, "master_volume", 0.8)
	music_volume = config.get_value(CONFIG_SECTION_AUDIO, "music_volume", 0.7)
	sfx_volume = config.get_value(CONFIG_SECTION_AUDIO, "sfx_volume", 0.8)

	# Load Video
	window_mode = config.get_value(CONFIG_SECTION_VIDEO, "window_mode", 0)
	resolution_index = config.get_value(CONFIG_SECTION_VIDEO, "resolution_index", 2)
	brightness = config.get_value(CONFIG_SECTION_VIDEO, "brightness", 1.0)
	vsync_enabled = config.get_value(CONFIG_SECTION_VIDEO, "vsync_enabled", true)

	# Load Input
	preferred_input_device = config.get_value(CONFIG_SECTION_INPUT, "preferred_input_device", 0)

	# Load Cutscene
	subtitles_enabled = config.get_value(CONFIG_SECTION_CUTSCENE, "subtitles_enabled", true)
	subtitle_size = config.get_value(CONFIG_SECTION_CUTSCENE, "subtitle_size", 1)
	subtitle_fade_speed = config.get_value(CONFIG_SECTION_CUTSCENE, "subtitle_fade_speed", 0.3)

	print("[SettingsManager] Settings loaded from: %s" % SETTINGS_FILE)
	settings_loaded.emit()
	return true

# ============================================================================
# RESET TO DEFAULTS
# ============================================================================

func reset_to_defaults() -> void:
	"""Resets all settings to default values"""
	# Audio defaults
	master_volume = 0.8
	music_volume = 0.7
	sfx_volume = 0.8

	# Video defaults
	window_mode = 0
	resolution_index = 2
	brightness = 1.0
	vsync_enabled = true

	# Input defaults
	preferred_input_device = 0

	# Cutscene defaults
	subtitles_enabled = true
	subtitle_size = 1  # Medium
	subtitle_fade_speed = 0.3

	# Apply and save
	apply_all_settings()
	save_settings()

	print("[SettingsManager] Settings reset to defaults")
