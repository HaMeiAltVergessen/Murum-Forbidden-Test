extends Node2D
## Pre-Boss-Raum: Wahl zwischen Lythrun und Mirror Boss
## Dient auch als Arena fuer den Lythrun-Bosskampf

# ============ CONSTANTS ============
const FALL_OFF_Y: float = 1400.0
const RESPAWN_POS: Vector2 = Vector2(480, 760)

# ============ STATE ============
var _player: Node2D = null
var _lythrun_boss: Node = null
var _is_fighting: bool = false
var _player_in_lythrun_door: bool = false
var _player_in_mirror_door: bool = false


func _ready() -> void:
	call_deferred("_activate")


func _activate() -> void:
	# Vorherige Musik stoppen (kein Auto-Match fuer diesen Raum)
	if MusicScenePlayer:
		MusicScenePlayer.stop_music()
	_spawn_player()
	_connect_doors()


func _spawn_player() -> void:
	var spawn: Marker2D = get_node_or_null("SpawnPoints/Default")
	var spawn_pos: Vector2 = spawn.global_position if spawn else RESPAWN_POS

	if GameManager and GameManager.player and is_instance_valid(GameManager.player):
		var player = GameManager.player
		if player.get_parent() != self:
			if player.get_parent():
				player.get_parent().remove_child(player)
			add_child(player)

		player.global_position = spawn_pos
		player.z_index = 100
		player.z_as_relative = false
		if player is CharacterBody2D:
			player.velocity = Vector2.ZERO

		if player.has_node("HealthComponent"):
			player.get_node("HealthComponent").reset_health()
		if player.has_node("ManaComponent"):
			player.get_node("ManaComponent").reset_mana()
		if player.has_method("respawn"):
			player.respawn(spawn_pos)

		_player = player
	else:
		var player_scene: PackedScene = load("res://player/murum.tscn")
		if player_scene:
			_player = player_scene.instantiate()
			add_child(_player)
			_player.global_position = spawn_pos
			if GameManager:
				GameManager.player = _player


func _connect_doors() -> void:
	var lythrun_door: Area2D = get_node_or_null("Doors/LythrunDoor")
	var mirror_door: Area2D = get_node_or_null("Doors/MirrorDoor")
	if lythrun_door:
		lythrun_door.body_entered.connect(func(_b): _player_in_lythrun_door = true)
		lythrun_door.body_exited.connect(func(_b): _player_in_lythrun_door = false)
	if mirror_door:
		mirror_door.body_entered.connect(func(_b): _player_in_mirror_door = true)
		mirror_door.body_exited.connect(func(_b): _player_in_mirror_door = false)


func _process(_delta: float) -> void:
	# Door interact (only when not fighting)
	if not _is_fighting:
		var interact: bool = false
		if InputManager:
			interact = InputManager.is_p1_action_just_pressed("interact")
		else:
			interact = Input.is_action_just_pressed("interact")

		if interact:
			if _player_in_lythrun_door:
				start_lythrun_fight()
			elif _player_in_mirror_door:
				start_mirror_fight()

	# Out-of-bounce respawn waehrend Lythrun-Kampf
	if _is_fighting and _player and is_instance_valid(_player):
		if _player.global_position.y > FALL_OFF_Y:
			_respawn_player()


func _respawn_player() -> void:
	if not _player or not is_instance_valid(_player):
		return
	_player.global_position = RESPAWN_POS
	if _player is CharacterBody2D:
		_player.velocity = Vector2.ZERO
	print("[PreBossRoom] Spieler respawnt nach Fall")


# ============ DOOR INTERACTIONS ============
func start_lythrun_fight() -> void:
	if _is_fighting:
		return
	_is_fighting = true

	# Tuer-UI ausblenden
	var doors_node = get_node_or_null("Doors")
	if doors_node:
		doors_node.visible = false

	var boss_scene: PackedScene = load("res://bosses/lythrun/lythrun_boss.tscn")
	if not boss_scene:
		push_warning("[PreBossRoom] lythrun_boss.tscn nicht gefunden!")
		return

	_lythrun_boss = boss_scene.instantiate()

	var boss_spawn: Marker2D = get_node_or_null("EnemySpawnPoints/BossSpawn")
	if boss_spawn:
		_lythrun_boss.global_position = boss_spawn.global_position
	else:
		_lythrun_boss.global_position = Vector2(960, 760)

	add_child(_lythrun_boss)

	# Lythrun Boss-Musik starten
	if MusicScenePlayer:
		MusicScenePlayer.force_play_scene("LythrunBossP1")

	get_tree().create_timer(1.0).timeout.connect(func():
		if _lythrun_boss and is_instance_valid(_lythrun_boss) and _lythrun_boss.has_method("start_fight"):
			_lythrun_boss.start_fight()
	)


func start_mirror_fight() -> void:
	if _is_fighting:
		return

	# Boons sichern, da run_started sie loescht
	var saved_boons: Dictionary = BoonManager.get_save_data() if BoonManager else {}

	if RunManager:
		RunManager.start_run(RunMapData.WorldId.ABGRUND)

	# Boons wiederherstellen
	if BoonManager and not saved_boons.get("active_boons", {}).is_empty():
		BoonManager.load_from_save(saved_boons)
		print("[PreBossRoom] %d Boons wiederhergestellt" % BoonManager.get_active_boon_count())
