extends Node

## MusicScenePlayer - Persistenter Musik-Manager
## Spielt Musik pro Szene (Gruppe von Levels). Beim Wechsel innerhalb
## einer Szene laeuft die Musik weiter. Bei Szenenwechsel: Crossfade.
## Tracks werden zufaellig abgespielt. Volume ueber den Music-Bus.
## Unterstuetzt force_play_scene() fuer Run-Raeume (blockiert auto-detection).

# ============================================================================
# INSPECTOR
# ============================================================================

## Alle Musik-Szenen (im Inspektor konfigurierbar)
@export var music_scenes: Array[MusicScene] = []

## Crossfade-Dauer in Sekunden beim Szenenwechsel
@export var crossfade_duration: float = 2.0

# ============================================================================
# STATE
# ============================================================================

var current_scene: MusicScene = null
var current_track_index: int = -1
var _last_scene_path: String = ""
var _crossfading: bool = false
var _forced: bool = false  # Blockiert auto-detection wenn force_play_scene aktiv

# ============================================================================
# RUN MUSIC MAPPING (world_id + node_type -> scene_name)
# ============================================================================

const RUN_MUSIC_MAP: Dictionary = {
	# Welt 1: Niemandsland
	"w0_combat": "W1Combat",
	"w0_elite": "W1Elite",
	"w0_treasure": "W1Calm",
	"w0_rest": "W1Calm",
	"w0_shop": "W1Calm",
	"w0_event": "W1Event",
	"w0_boss": "W1BossP1",
	# Welt 2: Kollektiv
	"w1_combat": "W2Combat",
	"w1_elite": "W2Elite",
	"w1_treasure": "W2Calm",
	"w1_rest": "W2Calm",
	"w1_shop": "W2Calm",
	"w1_event": "W2Event",
	"w1_boss": "W2BossP1",
	# Welt 3: Abgrund
	"w2_combat": "W3Combat",
	"w2_elite": "W3Elite",
	"w2_treasure": "W3Calm",
	"w2_rest": "W3Calm",
	"w2_shop": "W3Calm",
	"w2_event": "W3Event",
	"w2_boss": "W3BossP1",
}

const NODE_TYPE_KEYS: Dictionary = {
	0: "combat",   # COMBAT
	1: "elite",    # ELITE
	2: "treasure", # TREASURE
	3: "rest",     # REST
	4: "event",    # EVENT
	5: "boss",     # BOSS
	6: "shop",     # SHOP
	7: "arena",    # ARENA -> combat
}

# ============================================================================
# AUDIO PLAYERS (zwei fuer Crossfade)
# ============================================================================

var player_a: AudioStreamPlayer
var player_b: AudioStreamPlayer
var active_player: AudioStreamPlayer  # Der gerade spielende

# ============================================================================
# INIT
# ============================================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	player_a = AudioStreamPlayer.new()
	player_a.name = "MusicPlayerA"
	player_a.bus = "Music"
	player_a.volume_db = 0.0
	add_child(player_a)

	player_b = AudioStreamPlayer.new()
	player_b.name = "MusicPlayerB"
	player_b.bus = "Music"
	player_b.volume_db = -80.0
	add_child(player_b)

	active_player = player_a

	# Track endet -> naechsten zufaelligen Track spielen
	player_a.finished.connect(_on_track_finished.bind(player_a))
	player_b.finished.connect(_on_track_finished.bind(player_b))

	print("[MusicScenePlayer] Initialized with %d scenes" % music_scenes.size())


# ============================================================================
# SCENE DETECTION (prueft jedes Frame ob sich die Szene geaendert hat)
# ============================================================================

func _process(_delta: float) -> void:
	var tree := get_tree()
	if not tree or not tree.current_scene:
		return

	var scene_path: String = tree.current_scene.scene_file_path
	if scene_path == _last_scene_path:
		return

	_last_scene_path = scene_path

	# Wenn force aktiv: nur bei level_paths-Match aufheben, sonst ignorieren
	if _forced:
		var match_scene := _find_scene_for_level(scene_path)
		if match_scene != null:
			# Szene mit level_paths gefunden -> force aufheben, normal wechseln
			_forced = false
			_on_level_changed(scene_path)
		# Sonst: force bleibt aktiv, auto-detection wird uebersprungen
		return

	_on_level_changed(scene_path)


func _on_level_changed(level_path: String) -> void:
	var new_scene := _find_scene_for_level(level_path)

	if new_scene == current_scene:
		# Gleiche Szene - Musik laeuft weiter
		print("[MusicScenePlayer] Same scene '%s' - music continues" % (current_scene.scene_name if current_scene else "none"))
		return

	if new_scene == null:
		# Kein Match - Musik ausfaden
		print("[MusicScenePlayer] No scene for '%s' - fading out" % level_path)
		_fade_out_current()
		current_scene = null
		return

	# Neue Szene - Crossfade zu neuem Track
	print("[MusicScenePlayer] Scene change: '%s' -> '%s'" % [
		current_scene.scene_name if current_scene else "none",
		new_scene.scene_name
	])
	current_scene = new_scene
	_play_random_track_crossfade()


# ============================================================================
# PLAYBACK
# ============================================================================

func _play_random_track_crossfade() -> void:
	if current_scene == null or current_scene.tracks.is_empty():
		return

	# Zufaelligen Track waehlen (nicht den gleichen wie vorher)
	var new_index := _pick_random_track()
	current_track_index = new_index
	var track: AudioStream = current_scene.tracks[new_index]

	print("[MusicScenePlayer] Playing track %d from '%s'" % [new_index, current_scene.scene_name])

	# Crossfade
	var old_player := active_player
	var new_player := player_b if active_player == player_a else player_a
	active_player = new_player

	new_player.stream = track
	new_player.volume_db = -80.0
	new_player.play()

	if _crossfading:
		# Vorheriger Crossfade noch aktiv - direkt uebernehmen
		pass

	_crossfading = true
	var tween := create_tween().set_parallel(true)

	# Neuer Player: fade in
	tween.tween_property(new_player, "volume_db", 0.0, crossfade_duration)

	# Alter Player: fade out und stoppen
	if old_player.playing:
		tween.tween_property(old_player, "volume_db", -80.0, crossfade_duration)
		tween.chain().tween_callback(old_player.stop)

	tween.chain().tween_callback(func(): _crossfading = false)


func _fade_out_current() -> void:
	if not active_player.playing:
		return

	var tween := create_tween()
	var player_to_stop := active_player
	tween.tween_property(player_to_stop, "volume_db", -80.0, crossfade_duration)
	tween.tween_callback(player_to_stop.stop)


func _on_track_finished(player: AudioStreamPlayer) -> void:
	# Nur reagieren wenn es der aktive Player ist
	if player != active_player:
		return

	if current_scene == null or current_scene.tracks.is_empty():
		return

	# Naechsten zufaelligen Track spielen (kein Crossfade, direkt)
	var new_index := _pick_random_track()
	current_track_index = new_index
	var track: AudioStream = current_scene.tracks[new_index]

	print("[MusicScenePlayer] Next track %d from '%s'" % [new_index, current_scene.scene_name])
	active_player.stream = track
	active_player.volume_db = 0.0
	active_player.play()


# ============================================================================
# HELPERS
# ============================================================================

func _find_scene_for_level(level_path: String) -> MusicScene:
	for scene in music_scenes:
		for path in scene.level_paths:
			if level_path == path:
				return scene
	return null


func _pick_random_track() -> int:
	if current_scene == null or current_scene.tracks.is_empty():
		return 0

	var count := current_scene.tracks.size()
	if count == 1:
		return 0

	# Nicht den gleichen Track nochmal
	var new_index := randi() % count
	while new_index == current_track_index and count > 1:
		new_index = randi() % count
	return new_index


# ============================================================================
# PUBLIC API
# ============================================================================

func stop_music(fade: bool = true) -> void:
	"""Stoppt die aktuelle Musik"""
	current_scene = null
	_forced = false
	if fade:
		_fade_out_current()
	else:
		active_player.stop()


func force_play_scene(scene_name: String) -> void:
	"""Erzwingt eine bestimmte Musik-Szene (blockiert auto-detection bis level_paths-Match)"""
	for scene in music_scenes:
		if scene.scene_name == scene_name:
			if current_scene == scene:
				# Gleiche Szene - Musik laeuft weiter
				return
			_forced = true
			current_scene = scene
			_play_random_track_crossfade()
			print("[MusicScenePlayer] Force play: %s" % scene_name)
			return
	push_warning("[MusicScenePlayer] Scene not found: %s" % scene_name)


func play_for_run_room(world_id: int, node_type: int) -> void:
	"""Spielt die passende Musik fuer einen Run-Raum (world_id + node_type)"""
	var type_key: String = NODE_TYPE_KEYS.get(node_type, "combat")
	var lookup: String = "w%d_%s" % [world_id, type_key]
	var scene_name: String = RUN_MUSIC_MAP.get(lookup, "")

	if scene_name.is_empty():
		push_warning("[MusicScenePlayer] No run music for: %s" % lookup)
		return

	force_play_scene(scene_name)


func play_event_battle_music() -> void:
	"""Wechselt zu Event-Kampfmusik (fuer Events mit Kampf)"""
	force_play_scene("EventBattle")
