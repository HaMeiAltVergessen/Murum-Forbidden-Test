extends Node
## Handles the victory sequence after a boss is defeated
class_name VictorySequence

signal sequence_started
signal sequence_completed

@export var boss: CharacterBody2D
@export var gold_reward: int = 500
@export var unlock_flag: String = ""  # e.g., "world1_boss_defeated"

# Loot drops (configured per boss)
var loot_items: Array[String] = []  # Item IDs from ItemDatabase


func start() -> void:
	"""Starts the victory sequence"""
	sequence_started.emit()
	print("[VictorySequence] Starting victory sequence for boss: ", boss.name if boss else "Unknown")

	# CRITICAL: Null safety - boss might be freed already
	if not boss or not is_instance_valid(boss):
		print("[VictorySequence] ERROR: Boss is null or invalid, skipping victory sequence")
		sequence_completed.emit()
		return

	# 1. Play death animation
	await play_death_animation()

	# 2. Focus camera on boss
	if boss and is_instance_valid(boss) and boss.has_node("Components/BossCameraController"):
		var camera_ctrl = boss.get_node("Components/BossCameraController")
		camera_ctrl.focus_on_boss(0.5)

	await get_tree().create_timer(0.5).timeout

	# 3. Spawn death VFX
	spawn_death_vfx()

	# Camera shake
	if boss and is_instance_valid(boss) and boss.has_node("Components/BossCameraController"):
		var camera_ctrl = boss.get_node("Components/BossCameraController")
		camera_ctrl.shake(10.0, 1.0)

	await get_tree().create_timer(1.0).timeout

	# 4. Spawn loot
	spawn_loot()

	# 5. Set unlock flag
	if not unlock_flag.is_empty():
		GameManager.set_flag(unlock_flag, true)
		print("[VictorySequence] Unlock flag set: ", unlock_flag)

	# 6. Show victory screen (TODO: implement UI)
	show_victory_screen()

	# 7. Deactivate boss camera
	await get_tree().create_timer(2.0).timeout

	if boss and is_instance_valid(boss) and boss.has_node("Components/BossCameraController"):
		var camera_ctrl = boss.get_node("Components/BossCameraController")
		camera_ctrl.deactivate()

	sequence_completed.emit()
	print("[VictorySequence] Victory sequence completed")


func play_death_animation() -> void:
	"""Plays the boss death animation"""
	if boss and is_instance_valid(boss) and boss.has_method("play_death_animation"):
		await boss.play_death_animation()
	else:
		# Fallback: just wait a bit
		await get_tree().create_timer(1.0).timeout


func spawn_death_vfx() -> void:
	"""Spawns death visual effects"""
	if not boss or not is_instance_valid(boss):
		return

	# TODO: Load actual VFX scene when created
	# For now, just print
	print("[VictorySequence] Death VFX spawned at: ", boss.global_position)

	# Example:
	# var explosion = preload("res://vfx/boss/boss_death_explosion.tscn").instantiate()
	# get_tree().current_scene.add_child(explosion)
	# explosion.global_position = boss.global_position


func spawn_loot() -> void:
	"""Spawns gold and item loot"""
	if not boss or not is_instance_valid(boss):
		return

	var spawn_position = boss.global_position

	# Spawn gold coins
	spawn_gold_coins(spawn_position)

	# Spawn items (if any configured)
	for item_id in loot_items:
		spawn_item(item_id, spawn_position)


func spawn_gold_coins(spawn_pos: Vector2) -> void:
	"""Spawns gold coins around the boss"""
	var coins_to_spawn = int(gold_reward / 10)  # 10 gold per coin

	for i in range(coins_to_spawn):
		# Check if gold_coin scene exists
		var coin_path = "res://environment/pickups/gold_coin.tscn"
		if ResourceLoader.exists(coin_path):
			var coin_scene = load(coin_path)
			var coin = coin_scene.instantiate()
			get_tree().current_scene.add_child(coin)

			# Random offset
			var offset = Vector2(randf_range(-50, 50), randf_range(-50, 50))
			coin.global_position = spawn_pos + offset

			# Set value if method exists
			if coin.has_method("set_value"):
				coin.set_value(10)
		else:
			# Fallback: just add coins directly to GameManager
			GameManager.add_coins(gold_reward)
			break


func spawn_item(item_id: String, spawn_pos: Vector2) -> void:
	"""Spawns an item pickup"""
	print("[VictorySequence] Spawning item: ", item_id, " at ", spawn_pos)

	# TODO: Implement item spawning when item system is ready
	# var item_pickup = preload("res://environment/pickups/item_pickup.tscn").instantiate()
	# get_tree().current_scene.add_child(item_pickup)
	# var offset = Vector2(randf_range(-80, 80), randf_range(-80, 80))
	# item_pickup.global_position = spawn_pos + offset
	# item_pickup.setup(ItemDatabase.get_item(item_id))


func show_victory_screen() -> void:
	"""Shows the victory UI screen"""
	print("[VictorySequence] Victory! Boss defeated. Gold reward: ", gold_reward)

	# TODO: Implement victory screen UI
	# var victory_ui = preload("res://ui/boss_victory_screen.tscn").instantiate()
	# get_tree().current_scene.add_child(victory_ui)
	# victory_ui.setup(boss.boss_name, gold_reward, loot_items)


func set_loot_items(items: Array[String]) -> void:
	"""Sets the items to drop"""
	loot_items = items
