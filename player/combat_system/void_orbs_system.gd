extends Node
## Void Orbs ability system extracted from lythrun_player.gd
## Scaling AoE attack that charges over time for more damage and radius
class_name VoidOrbsSystem

# ============ VOID ORBS (COMMIT 021 - Scaling AoE) ============
const VOID_ORB_CHARGE_TIME: float = 9.0  # Max charge time (9 seconds)
const VOID_ORB_MANA_COST: int = 20
const VOID_ORB_BASE_DAMAGE: float = 30.0  # Base damage at 0s
const VOID_ORB_DAMAGE_PER_SECOND: float = 15.0  # Additional damage per second charged
const VOID_ORB_BASE_RADIUS: float = 30.0  # Starting radius at 0s
const VOID_ORB_RADIUS_PER_SECOND: float = 30.0  # +30px per second (30-300px range)

var is_charging_orb: bool = false
var orb_charge_time: float = 0.0
var movement_disabled_by_orb: bool = false
var charging_orb_vfx = null

# Player reference (set in _ready)
var player = null

func _ready() -> void:
	player = get_parent()

# ============ PUBLIC API ============

func start_charging() -> void:
	"""Start charging void orb (public entry point)"""
	start_charging_orb()

func release() -> void:
	"""Release charged void orb (public entry point)"""
	release_orb()

func is_charging() -> bool:
	return is_charging_orb

# ============ CORE FUNCTIONS ============

func start_charging_orb() -> void:
	"""Start charging void orb"""
	if player.current_mana < VOID_ORB_MANA_COST:
		print("[Void Orb] Not enough mana!")
		return

	if is_charging_orb or player.is_attacking or player.is_dashing:
		return

	is_charging_orb = true
	orb_charge_time = 0.0
	movement_disabled_by_orb = true

	# Restrict player movement during charge
	player.movement_disabled_by_orb = true

	print("[Void Orb] Charging...")

	# VFX
	spawn_charging_orb_vfx()

	# Audio
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("void_orb_charge_start")

func release_orb() -> void:
	"""Release charged void orb"""
	if not is_charging_orb:
		return

	# Consume mana
	player.consume_mana(VOID_ORB_MANA_COST)

	is_charging_orb = false
	movement_disabled_by_orb = false

	# Restore player movement
	player.movement_disabled_by_orb = false

	# Calculate damage: Base + (seconds charged * damage per second)
	var orb_damage = VOID_ORB_BASE_DAMAGE + (orb_charge_time * VOID_ORB_DAMAGE_PER_SECOND)
	var charge_factor = orb_charge_time / VOID_ORB_CHARGE_TIME  # For logging

	print("[Void Orb] Released! Charge: %.1fs (%.0f%%) | Damage: %.1f" % [
		orb_charge_time,
		charge_factor * 100,
		orb_damage
	])

	# Spawn orb (simplified projectile)
	spawn_void_orb_projectile(orb_damage, charge_factor)

	# Clear VFX
	clear_charging_orb_vfx()

	# Audio
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("void_orb_release")

func spawn_void_orb_projectile(damage: float, charge_factor: float) -> void:
	"""Scaling AoE attack (COMMIT 021: Radius grows with charge time)"""

	# Calculate radius: 30px base + 30px per second (30-300px range)
	var orb_radius = VOID_ORB_BASE_RADIUS + (orb_charge_time * VOID_ORB_RADIUS_PER_SECOND)
	orb_radius = min(orb_radius, 300.0)  # Cap at 300px (9 seconds)

	# Create visual expanding circle sprite
	var visual = Sprite2D.new()
	var circle_texture = load("res://Assets/Placeholder/Legacy Collection/Assets/Packs/Meta data assets files/Visuals/OBJECTS/items/orb-blue/orb-blue1.png")
	if circle_texture:
		visual.texture = circle_texture
		visual.modulate = Color(0.5, 0.2, 0.8, 0.6)  # Dark purple, semi-transparent
		# Scale based on actual radius (orb sprite is ~16px, so scale = radius / 8)
		var visual_scale = orb_radius / 8.0
		visual.scale = Vector2(visual_scale, visual_scale)
		player.get_parent().add_child(visual)
		visual.global_position = player.global_position
		visual.z_index = 10

		# Expand animation
		var tween = player.create_tween()
		tween.tween_property(visual, "scale", visual.scale * 1.3, 0.3)
		tween.parallel().tween_property(visual, "modulate:a", 0.0, 0.3)
		tween.tween_callback(visual.queue_free)

	# Create scaling AoE
	var aoe = Area2D.new()
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = orb_radius  # Scales with charge time

	collision.shape = shape
	aoe.add_child(collision)
	player.get_parent().add_child(aoe)

	aoe.global_position = player.global_position

	# Collision setup (COMMIT 023.9.9: Check BOTH Layer 9 (PVP) AND Layer 11 (Enemies)!)
	aoe.collision_layer = 0
	aoe.set_collision_layer_value(6, true)  # P2 Projectiles (Layer 6)
	aoe.collision_mask = 0
	aoe.set_collision_mask_value(8, true)   # Interactables (COMMIT 018: For Puzzles)
	aoe.set_collision_mask_value(9, true)   # EnemyHurtbox (PVP - Layer 9)
	aoe.set_collision_mask_value(11, true)  # PlayerHurtbox/EnemyHurtbox (Normal - Layer 11)

	aoe.monitoring = true
	aoe.monitorable = false

	# COMMIT 018: Add to group and set metadata for puzzle detection
	aoe.add_to_group("p2_projectiles")
	aoe.set_meta("owner_player", player)

	print("[Void Orb AoE] Released! Charge: %.1fs | Damage: %.1f | Radius: %.0fpx" % [
		orb_charge_time,
		damage,
		orb_radius
	])

	# COMMIT 023.9.6: Use timer instead of await for better collision detection
	await get_tree().create_timer(0.1).timeout

	# Damage all enemies in range
	var hit_areas = aoe.get_overlapping_areas()
	var enemies_hit = 0

	print("[Void Orb AoE] Found %d overlapping areas" % hit_areas.size())

	for area in hit_areas:
		if not area or not is_instance_valid(area):
			continue

		# Get enemy from hurtbox
		var enemy = area.get_parent()
		if not enemy or not is_instance_valid(enemy):
			continue

		# CRITICAL: Only hit enemies, NOT players, NOT self (COMMIT 023.8)
		if enemy.is_in_group("enemies"):
			# CRITICAL: Don't hit yourself!
			if enemy == player:
				print("[Void Orb AoE] Blocked self-hit on %s" % enemy.name)
				continue

			# Deal damage (COMMIT 023.9.11: Use HurtboxComponent to respect invulnerability!)
			# PRIORITY 1: Use HurtboxComponent (respects invulnerability/block!)
			if area is HurtboxComponent:
				var success = area.take_damage(int(damage), Vector2.ZERO, 0.2, player)
				if success:
					enemies_hit += 1
					print("[Void Orb AoE] Hit %s for %.1f damage (HurtboxComponent)" % [enemy.name, damage])
				else:
					print("[Void Orb AoE] BLOCKED by %s (invulnerable!)" % enemy.name)
			# FALLBACK: HealthComponent (old enemies)
			elif enemy.has_node("HealthComponent"):
				var health = enemy.get_node("HealthComponent")
				if health.has_method("take_damage"):
					health.take_damage(int(damage))
					enemies_hit += 1
					print("[Void Orb AoE] Hit %s for %.1f damage (HealthComponent fallback)" % [enemy.name, damage])

	print("[Void Orb AoE] Total enemies hit: %d" % enemies_hit)

	# Cleanup
	aoe.queue_free()

	# Audio
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("void_explosion")

# ============ VFX FUNCTIONS ============

func spawn_charging_orb_vfx() -> void:
	"""Spawn charging orb VFX (COMMIT 021: Growing orb above head)"""
	# Create charging orb sprite
	charging_orb_vfx = Sprite2D.new()
	var orb_texture = load("res://Assets/Placeholder/Legacy Collection/Assets/Packs/Meta data assets files/Visuals/OBJECTS/items/orb-blue/orb-blue1.png")
	if orb_texture:
		charging_orb_vfx.texture = orb_texture
		charging_orb_vfx.modulate = Color(0.5, 0.2, 0.8, 0.8)  # Dark purple
		charging_orb_vfx.scale = Vector2(0.5, 0.5)  # Start small
		player.add_child(charging_orb_vfx)
		charging_orb_vfx.position = Vector2(0, -60)  # Above head
		charging_orb_vfx.z_index = 10
		print("[VFX] Void orb charging started")

func update_charging_orb_vfx(charge_factor: float) -> void:
	"""Update charging orb VFX (COMMIT 021: Scale 0.5 -> 5.0 over 9 seconds)"""
	if charging_orb_vfx and is_instance_valid(charging_orb_vfx):
		# Scale from 0.5 to 5.0 based on charge (0-100%)
		var scale_value = 0.5 + (charge_factor * 4.5)
		charging_orb_vfx.scale = Vector2(scale_value, scale_value)

		# Pulsating effect
		charging_orb_vfx.modulate.a = 0.6 + sin(Time.get_ticks_msec() * 0.01) * 0.2

func clear_charging_orb_vfx() -> void:
	"""Clear charging orb VFX (COMMIT 021: Remove sprite)"""
	if charging_orb_vfx and is_instance_valid(charging_orb_vfx):
		charging_orb_vfx.queue_free()
		charging_orb_vfx = null
	print("[VFX] Void orb charging cleared")
