extends CharacterBody2D
class_name BringerOfDeath

## Bringer of Death - Melee Aggressor Enemy
## Chases player and attacks with heavy melee strikes
## Godot 4.4 compatible

# ============================================================================
# CONSTANTS
# ============================================================================

const MAX_HP: int = 50
const MOVE_SPEED: float = 70.0
const DAMAGE: int = 20

# ============================================================================
# STATE
# ============================================================================

var current_hp: int = MAX_HP
var is_stunned: bool = false
var stun_duration: float = 0.0

# ============================================================================
# REFERENCES
# ============================================================================

@onready var animated_sprite: Sprite2D = $Sprite2D
@onready var ai_controller: Node = $BringerOfDeathAI
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
	add_to_group("bringer_of_death")

	# Setup hurtbox
	if hurtbox:
		hurtbox.damage_received.connect(_on_damage_received)

	# Start animation
	if animated_sprite:
		animated_sprite.modulate = Color.WHITE

	print("[BringerOfDeath] Initialized at %v, HP: %d/%d" % [global_position, current_hp, MAX_HP])

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

func _on_damage_received(damage: int, knockback: Vector2, hitstun: float) -> void:
	"""Called when hurtbox receives damage"""
	take_damage(damage)

	# Apply knockback
	if knockback.length() > 0:
		velocity = knockback

	# Apply hitstun if provided
	if hitstun > 0:
		stun(hitstun)

func take_damage(amount: int, _attacker: Node = null) -> void:
	"""Takes damage"""
	current_hp -= amount
	current_hp = max(current_hp, 0)

	health_changed.emit(current_hp, MAX_HP)

	# Visual feedback
	_flash_damage()

	# Audio
	if AudioManager:
		AudioManager.play_sfx("enemies/geist_hurt", 0.15)

	print("[BringerOfDeath] Took %d damage, HP: %d/%d" % [amount, current_hp, MAX_HP])

	# Check death
	if current_hp <= 0:
		die()

func _flash_damage() -> void:
	"""Visual damage feedback"""
	if not animated_sprite:
		return

	var original_modulate = animated_sprite.modulate
	animated_sprite.modulate = Color(2.0, 0.5, 0.5, 1.0)  # Red flash

	await get_tree().create_timer(0.1).timeout

	if animated_sprite:
		animated_sprite.modulate = original_modulate

# ============================================================================
# DEATH
# ============================================================================

func die() -> void:
	"""Handles death"""
	print("[BringerOfDeath] Died at %v" % global_position)

	died.emit()
	EventBus.enemy_died.emit(self, global_position)

	# Unregister from combat
	CombatManager.unregister_enemy(self)

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
	if AudioManager:
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
	var gold_coin_scene = load("res://environment/pickups/gold_coin.tscn")
	if not gold_coin_scene:
		push_warning("[BringerOfDeath] Gold coin scene not found!")
		return

	# Bringer of Death drops 3-5 coins
	var coin_count = randi() % 3 + 3

	for i in range(coin_count):
		var coin = gold_coin_scene.instantiate()
		var offset = Vector2(randf_range(-30, 30), randf_range(-30, 30))
		coin.global_position = global_position + offset
		coin.gold_value = 1
		get_tree().current_scene.call_deferred("add_child", coin)

	print("[BringerOfDeath] Spawned %d gold coins" % coin_count)

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
		animated_sprite.modulate = Color(1.5, 1.5, 0.5, 1.0)  # Yellow tint

	stunned.emit(duration)
	EventBus.enemy_stunned.emit(self, duration)

	print("[BringerOfDeath] Stunned for %.2fs" % duration)

func _end_stun() -> void:
	"""Ends stun effect"""
	is_stunned = false
	stun_duration = 0.0

	# Restore visual
	if animated_sprite:
		animated_sprite.modulate = Color.WHITE

	stun_ended.emit()

	print("[BringerOfDeath] Stun ended")

# ============================================================================
# UTILITY
# ============================================================================

func get_hp_percent() -> float:
	"""Returns HP as percentage (0.0-1.0)"""
	return float(current_hp) / float(MAX_HP)

func is_alive() -> bool:
	"""Returns true if enemy is alive"""
	return current_hp > 0
