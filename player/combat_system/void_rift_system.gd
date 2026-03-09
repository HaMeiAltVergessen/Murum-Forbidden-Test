extends Node
## Void Rift ability system extracted from lythrun_player.gd
## Creates a growing void rift that explodes after a duration
class_name VoidRiftSystem

# ============ VOID RIFT (COMMIT 019.5) ============
const VOID_RIFT_MANA_COST: int = 40  # COMMIT 024: Reduced from 50 (more affordable)
const VOID_RIFT_DURATION: float = 3.0
const VOID_RIFT_MIN_RADIUS: float = 220.0
const VOID_RIFT_MAX_RADIUS: float = 650.0
const VOID_RIFT_DAMAGE: float = 80.0

var void_rift_active: bool = false

# Player reference (set in _ready)
var player = null

func _ready() -> void:
	player = get_parent()

# ============ PUBLIC API ============

func activate() -> void:
	"""Activate the void rift ability"""
	void_rift()

# ============ CORE FUNCTIONS ============

func void_rift() -> void:
	"""Create growing void rift that explodes"""
	if player.current_mana < VOID_RIFT_MANA_COST:
		print("[Void Rift] Not enough mana!")
		return

	if void_rift_active:
		print("[Void Rift] Already active!")
		return

	# Consume mana
	player.consume_mana(VOID_RIFT_MANA_COST)

	void_rift_active = true

	print("[Void Rift] Creating rift...")

	# Try to load rift scene
	var rift_path = "res://abilities/void_rift.tscn"
	if ResourceLoader.exists(rift_path):
		var rift_scene = load(rift_path)
		if rift_scene:
			var rift = rift_scene.instantiate()
			# CRITICAL FIX: Use get_parent() instead of get_tree().current_scene (more reliable)
			if player.get_parent():
				player.get_parent().add_child(rift)
			else:
				print("[Void Rift ERROR] No parent node!")
				void_rift_active = false
				return

			rift.global_position = player.global_position
			var rift_damage = VOID_RIFT_DAMAGE
			if UpgradeManager and UpgradeManager.get_ability_damage_multiplier() > 1.0:
				rift_damage = rift_damage * UpgradeManager.get_ability_damage_multiplier()
			if rift.has_method("setup"):
				rift.setup(VOID_RIFT_MIN_RADIUS, VOID_RIFT_MAX_RADIUS, VOID_RIFT_DURATION, rift_damage)

			rift.tree_exiting.connect(func(): void_rift_active = false)
		else:
			print("[Void Rift] Failed to load scene, using placeholder")
			create_placeholder_rift()
	else:
		# Placeholder rift
		print("[Void Rift] Scene not found, using placeholder")
		create_placeholder_rift()

	# Audio
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("void_rift_cast")

func create_placeholder_rift() -> void:
	"""Create placeholder rift"""
	# Simple growing circle
	var rift = Area2D.new()
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = VOID_RIFT_MIN_RADIUS

	collision.shape = shape
	rift.add_child(collision)
	player.get_parent().add_child(rift)

	rift.global_position = player.global_position

	# Collision setup
	rift.collision_layer = 0
	rift.set_collision_layer_value(6, true)  # P2 Projectiles
	rift.collision_mask = 0
	rift.set_collision_mask_value(4, true)  # Enemies

	# CRITICAL: Enable monitoring
	rift.monitoring = true
	rift.monitorable = true

	print("[Void Rift Placeholder] Created - Damage: %.1f, Duration: %.1fs" % [VOID_RIFT_DAMAGE, VOID_RIFT_DURATION])

	# Grow over time - FIXED: Use proper delta tracking
	var elapsed = 0.0
	var start_time = Time.get_ticks_msec() / 1000.0
	while elapsed < VOID_RIFT_DURATION:
		await get_tree().process_frame
		elapsed = (Time.get_ticks_msec() / 1000.0) - start_time
		var growth_factor = min(elapsed / VOID_RIFT_DURATION, 1.0)
		shape.radius = lerp(VOID_RIFT_MIN_RADIUS, VOID_RIFT_MAX_RADIUS, growth_factor)

	# Apply Urgathons Erbe ability damage bonus
	var final_damage = VOID_RIFT_DAMAGE
	if UpgradeManager and UpgradeManager.get_ability_damage_multiplier() > 1.0:
		final_damage = final_damage * UpgradeManager.get_ability_damage_multiplier()

	# Explode
	var enemies = rift.get_overlapping_bodies()
	for enemy in enemies:
		if enemy.has_method("take_damage"):
			enemy.take_damage(final_damage)
			print("[Void Rift] Damage to %s" % enemy.name)
		elif enemy.has_node("HealthComponent"):
			var health = enemy.get_node("HealthComponent")
			if health.has_method("take_damage"):
				health.take_damage(int(final_damage))
				print("[Void Rift] Damage (HealthComponent) to %s" % enemy.name)

	if is_instance_valid(rift):
		rift.queue_free()
	void_rift_active = false
