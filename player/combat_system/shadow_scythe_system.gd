extends Node
## Shadow Scythe ability system extracted from lythrun_player.gd
## Boomerang scythe projectile that can be thrown and recalled
class_name ShadowScytheSystem

# ============ SHADOW SCYTHE (COMMIT 019.5) ============
const SCYTHE_SPEED: float = 300.0  # COMMIT 024: Increased from 250.0 (faster travel)
const SCYTHE_MANA_COST: int = 15  # COMMIT 024: Reduced from 30 (more affordable)
const SCYTHE_RECALL_COOLDOWN: float = 0.5  # Prevent accidental immediate recalls

var scythe_instance = null
var scythe_thrown: bool = false
var scythe_throw_time: float = 0.0  # Time when scythe was thrown

# Player reference (set in _ready)
var player = null

func _ready() -> void:
	player = get_parent()

# ============ PUBLIC API ============

func toggle_scythe() -> void:
	"""Throw or recall the scythe"""
	if scythe_thrown:
		# Check recall cooldown
		var time_since_throw = (Time.get_ticks_msec() / 1000.0) - scythe_throw_time
		if time_since_throw < SCYTHE_RECALL_COOLDOWN:
			print("[Shadow Scythe] Recall cooldown (%.1fs remaining)" % (SCYTHE_RECALL_COOLDOWN - time_since_throw))
			return
		recall_scythe()
	else:
		shadow_scythe()

func is_scythe_thrown() -> bool:
	return scythe_thrown

# ============ CORE FUNCTIONS ============

func shadow_scythe() -> void:
	"""Throw boomerang scythe projectile"""
	if player.current_mana < SCYTHE_MANA_COST:
		print("[Shadow Scythe] Not enough mana!")
		return

	# REMOVED: Don't block by is_attacking - Shadow Scythe should be castable anytime
	if player.is_dashing:
		return

	# Consume mana
	player.consume_mana(SCYTHE_MANA_COST)

	# Check if scythe scene exists and can be loaded
	var scythe_path = "res://projectiles/shadow_scythe.tscn"
	if not ResourceLoader.exists(scythe_path):
		print("[Shadow Scythe] Scene not found, using placeholder")
		create_placeholder_scythe()
		return

	# Try to load scythe scene - CRITICAL: check for null!
	var scythe_scene = load(scythe_path)
	if not scythe_scene:
		print("[Shadow Scythe ERROR] Failed to load scene (corrupted?), using placeholder")
		create_placeholder_scythe()
		return

	# Try to instantiate - CRITICAL: check for null!
	scythe_instance = scythe_scene.instantiate()
	if not scythe_instance:
		print("[Shadow Scythe ERROR] Failed to instantiate scene, using placeholder")
		create_placeholder_scythe()
		return

	# Add to scene tree - CRITICAL: use get_parent() not current_scene
	if player.get_parent():
		player.get_parent().add_child(scythe_instance)
	else:
		print("[Shadow Scythe ERROR] No parent node!")
		scythe_instance.queue_free()
		create_placeholder_scythe()
		return

	scythe_instance.global_position = player.global_position + Vector2(0, -20)
	if "direction" in scythe_instance:
		scythe_instance.direction = Vector2.RIGHT if not player.sprite.flip_h else Vector2.LEFT
	if "damage" in scythe_instance:
		scythe_instance.damage = player.base_damage * 3.0
	if "owner_player" in scythe_instance:
		scythe_instance.owner_player = player
	if "can_pierce" in scythe_instance:
		scythe_instance.can_pierce = true

	scythe_thrown = true
	scythe_throw_time = Time.get_ticks_msec() / 1000.0  # Record throw time
	scythe_instance.tree_exiting.connect(_on_scythe_destroyed)

	if player.sense_sprite:
		player.sense_sprite.visible = false

	print("[Shadow Scythe] Thrown!")

func create_placeholder_scythe() -> void:
	"""Create placeholder scythe if scene doesn't exist"""
	print("[Shadow Scythe] Creating placeholder scythe")

	# Create simple projectile as placeholder
	var scythe = Area2D.new()
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 20.0

	collision.shape = shape
	scythe.add_child(collision)

	# Add visual with rotating animation - use lythrunSense asset
	var visual = Sprite2D.new()
	visual.texture = load("res://Assets/AIPlaceholder/lythrunSense.png")
	visual.modulate = Color(0.8, 0.4, 1.0)  # Brighter purple (matches shadow_scythe.gd)
	scythe.add_child(visual)

	# Rotate sprite for scythe effect
	var rotation_tween = visual.create_tween()
	rotation_tween.set_loops()
	rotation_tween.tween_property(visual, "rotation", TAU, 0.5)  # Full rotation every 0.5s

	if player.get_parent():
		player.get_parent().add_child(scythe)
	else:
		print("[Shadow Scythe ERROR] No parent!")
		scythe.queue_free()
		scythe_thrown = false
		return

	scythe.global_position = player.global_position + Vector2(0, -20)

	# Collision setup (COMMIT 023.9.9: Check BOTH Layer 9 (PVP) AND Layer 11 (Enemies)!)
	scythe.collision_layer = 0
	scythe.set_collision_layer_value(6, true)  # P2 Projectiles (Layer 6)
	scythe.collision_mask = 0
	scythe.set_collision_mask_value(9, true)   # EnemyHurtbox (PVP - Layer 9)
	scythe.set_collision_mask_value(11, true)  # PlayerHurtbox/EnemyHurtbox (Normal - Layer 11)

	# CRITICAL: Enable monitoring
	scythe.monitoring = true
	scythe.monitorable = true

	# Direction
	var direction = Vector2.RIGHT if not player.sprite.flip_h else Vector2.LEFT
	var velocity = direction * SCYTHE_SPEED
	var damage = player.base_damage * 3.0

	print("[Shadow Scythe Placeholder] Created - Damage: %.1f, Layer: %d, Mask: %d" % [
		damage,
		scythe.collision_layer,
		scythe.collision_mask
	])

	# Hit detection with hurtboxes (COMMIT 021: area_entered instead of body_entered)
	scythe.area_entered.connect(func(area):
		# Get enemy from hurtbox
		var enemy = area.get_parent()
		if not enemy or not is_instance_valid(enemy):
			return

		# CRITICAL: Only hit enemies, NOT players, NOT self (COMMIT 023.8)
		if not enemy.is_in_group("enemies"):
			return

		# CRITICAL: Don't hit yourself!
		if enemy == player:
			print("[Shadow Scythe] Blocked self-hit")
			return

		print("[Shadow Scythe] Hit %s" % enemy.name)

		# Deal damage through HealthComponent
		if enemy.has_node("HealthComponent"):
			var health = enemy.get_node("HealthComponent")
			if health.has_method("take_damage"):
				health.take_damage(int(damage))
				print("[Shadow Scythe] Dealt %.1f damage to %s" % [damage, enemy.name])
	)

	# Store reference
	scythe_instance = scythe
	scythe_thrown = true
	scythe_throw_time = Time.get_ticks_msec() / 1000.0  # Record throw time
	scythe_instance.tree_exiting.connect(_on_scythe_destroyed)

	if player.sense_sprite:
		player.sense_sprite.visible = false

	# Move scythe
	_move_placeholder_scythe(scythe, velocity)

func _move_placeholder_scythe(scythe: Area2D, velocity: Vector2) -> void:
	"""Move placeholder scythe"""
	var start_time = Time.get_ticks_msec() / 1000.0
	var max_distance = 800.0  # Max travel distance
	var distance_traveled = 0.0
	var last_frame_time = start_time

	while distance_traveled < max_distance:
		if not is_instance_valid(scythe):
			break
		await get_tree().process_frame
		if not is_instance_valid(scythe):
			break

		var current_time = Time.get_ticks_msec() / 1000.0
		var delta = current_time - last_frame_time
		last_frame_time = current_time

		var movement = velocity * delta
		scythe.global_position += movement
		distance_traveled += movement.length()

	if is_instance_valid(scythe):
		scythe.queue_free()

func recall_scythe() -> void:
	"""Recall thrown scythe"""
	if not scythe_instance or not is_instance_valid(scythe_instance):
		scythe_thrown = false  # Reset flag if instance is invalid
		return

	print("[Shadow Scythe] Recalling...")

	# If scythe has recall method, use it
	if scythe_instance.has_method("start_return_to_player"):
		scythe_instance.start_return_to_player(player)
	else:
		# Placeholder doesn't have recall - just destroy it and reset flags
		print("[Shadow Scythe] Placeholder recall - destroying")
		scythe_instance.queue_free()
		scythe_instance = null
		scythe_thrown = false
		return

	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("scythe_recall")

func _on_scythe_destroyed() -> void:
	"""Handle scythe destruction"""
	scythe_instance = null
	scythe_thrown = false  # CRITICAL: Reset flag when scythe is destroyed
	if player.sense_sprite:
		player.sense_sprite.visible = true

func on_scythe_returned() -> void:
	"""Called when scythe returns to player"""
	print("[Shadow Scythe] Returned!")
	scythe_thrown = false
	if player.sense_sprite:
		player.sense_sprite.visible = true
