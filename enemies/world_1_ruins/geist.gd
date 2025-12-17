extends CharacterBody2D
class_name Geist

## Geist - Ranged Kiter Enemy
## Maintains distance from player and fires projectiles

# ============================================================================
# CONSTANTS
# ============================================================================

const MAX_HP: int = 30
const MOVE_SPEED: float = 80.0
const DAMAGE: int = 15

# ============================================================================
# STATE
# ============================================================================

var current_hp: int = MAX_HP
var is_stunned: bool = false
var stun_duration: float = 0.0

# ============================================================================
# REFERENCES
# ============================================================================

@onready var animated_sprite: Node2D = $AnimatedSprite2D  # Can be AnimatedSprite2D or Polygon2D placeholder
@onready var ai_controller: Node = $GeistAI
@onready var hurtbox: Area2D = $HurtboxComponent
@onready var hitbox: Area2D = $HitboxComponent
@onready var detection_area: Area2D = $DetectionArea

# ============================================================================
# SIGNALS
# ============================================================================

signal health_changed(current: int, maximum: int)
signal died
signal stunned(duration: float)
signal stun_ended

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Add to groups
	add_to_group("enemies")
	add_to_group("geist")

	# Setup hurtbox
	if hurtbox:
		hurtbox.damage_received.connect(_on_damage_received)

	# Start animation
	if animated_sprite:
		if animated_sprite.has_method("play"):
			animated_sprite.play("idle")
		# Semi-transparent ghost effect
		animated_sprite.modulate = Color(1.0, 1.0, 1.0, 0.7)

	print("[Geist] Initialized at %v, HP: %d/%d" % [global_position, current_hp, MAX_HP])

# ============================================================================
# PROCESS
# ============================================================================

func _process(delta: float) -> void:
	# Stun countdown
	if is_stunned:
		stun_duration -= delta
		if stun_duration <= 0.0:
			_end_stun()
		return

# ============================================================================
# DAMAGE HANDLING
# ============================================================================

func _on_damage_received(amount: int, attacker: Node = null) -> void:
	"""Called when hurtbox receives damage"""
	take_damage(amount, attacker)

func take_damage(amount: int, _attacker: Node = null) -> void:
	"""Takes damage"""

	current_hp -= amount
	current_hp = max(current_hp, 0)

	health_changed.emit(current_hp, MAX_HP)

	# Visual feedback
	_flash_damage()

	# Audio
	AudioManager.play_sfx("enemies/geist_hurt", 0.15)

	print("[Geist] Took %d damage, HP: %d/%d" % [amount, current_hp, MAX_HP])

	# Check death
	if current_hp <= 0:
		die()

func _flash_damage() -> void:
	"""Visual damage feedback"""
	if not animated_sprite:
		return

	var original_modulate = animated_sprite.modulate
	animated_sprite.modulate = Color(2.0, 0.5, 0.5, 0.7)  # Red flash

	await get_tree().create_timer(0.1).timeout

	if animated_sprite:
		animated_sprite.modulate = original_modulate

# ============================================================================
# DEATH
# ============================================================================

func die() -> void:
	"""Handles death"""

	print("[Geist] Died at %v" % global_position)

	died.emit()
	EventBus.enemy_killed.emit(self, null)

	# Unregister from combat
	CombatManager.unregister_enemy(self)

	# Play death animation
	if animated_sprite and animated_sprite.has_method("play"):
		animated_sprite.play("death")

	# Disable collision
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)

	# Disable components
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)
	if hitbox:
		hitbox.set_deferred("monitoring", false)
		hitbox.set_deferred("monitorable", false)

	# Disable AI
	if ai_controller:
		ai_controller.set_process(false)

	# Audio
	AudioManager.play_sfx("enemies/geist_death", 0.15)

	# Spawn loot
	_spawn_loot()

	# Wait for animation
	await get_tree().create_timer(0.5).timeout

	# Fade out
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await tween.finished

	# Cleanup
	queue_free()

func _spawn_loot() -> void:
	"""Spawns coins on death"""
	# TODO: Spawn coin pickup
	print("[Geist] Dropped loot at %v" % global_position)

# ============================================================================
# STUN SYSTEM
# ============================================================================

func stun(duration: float) -> void:
	"""Stuns enemy (from perfect parry)"""
	is_stunned = true
	stun_duration = duration

	# Cancel attack
	if ai_controller and ai_controller.has_method("cancel_attack"):
		ai_controller.cancel_attack()

	# Visual feedback
	if animated_sprite:
		animated_sprite.modulate = Color(1.5, 1.5, 0.5, 0.7)  # Yellow tint

	stunned.emit(duration)
	EventBus.enemy_stunned.emit(self, duration)

	print("[Geist] Stunned for %.2fs" % duration)

func _end_stun() -> void:
	"""Ends stun effect"""
	is_stunned = false
	stun_duration = 0.0

	# Restore visual
	if animated_sprite:
		animated_sprite.modulate = Color(1.0, 1.0, 1.0, 0.7)  # Back to ghost alpha

	stun_ended.emit()

	print("[Geist] Stun ended")

# ============================================================================
# UTILITY
# ============================================================================

func get_hp_percent() -> float:
	"""Returns HP as percentage (0.0-1.0)"""
	return float(current_hp) / float(MAX_HP)

func is_alive() -> bool:
	"""Returns true if enemy is alive"""
	return current_hp > 0
