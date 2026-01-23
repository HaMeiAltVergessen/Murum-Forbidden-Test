extends CharacterBody2D
class_name AshwormLarge

## Large Ashworm - Burrows and lunges
## Godot 4.4 compatible

# ============================================================================
# CONSTANTS
# ============================================================================

const MAX_HP: int = 90
const MOVE_SPEED: float = 100.0
const DAMAGE: int = 25

# ============================================================================
# STATE
# ============================================================================

var current_hp: int = MAX_HP
var is_stunned: bool = false
var stun_duration: float = 0.0
var is_burrowed: bool = false

# ============================================================================
# REFERENCES
# ============================================================================

@onready var animated_sprite: Sprite2D = $Sprite2D
@onready var ai_controller: Node = $AshwormLargeAI
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
signal burrowed
signal surfaced

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("ashworm_large")

	if hurtbox:
		hurtbox.damage_received.connect(_on_damage_received)

	if animated_sprite:
		animated_sprite.modulate = Color(0.157, 0.157, 0.157, 1.0)

	print("[AshwormLarge] Initialized at %v, HP: %d/%d" % [global_position, current_hp, MAX_HP])

# ============================================================================
# PROCESS
# ============================================================================

func _process(delta: float) -> void:
	if is_stunned:
		stun_duration -= delta
		if stun_duration <= 0.0:
			_end_stun()
		return

# ============================================================================
# PHYSICS - GRAVITY (like undead enemies)
# ============================================================================

func _physics_process(delta: float) -> void:
	# Apply gravity when not burrowed (grounded worms!)
	if not is_burrowed and not is_on_floor():
		velocity.y += 980.0 * delta

	# Apply gravity even when burrowed is ending
	if not is_on_floor():
		move_and_slide()

# ============================================================================
# DAMAGE HANDLING
# ============================================================================

func _on_damage_received(damage: int, knockback: Vector2, hitstun: float) -> void:
	# Cannot damage while burrowed
	if is_burrowed:
		print("[AshwormLarge] Invulnerable while burrowed!")
		return

	take_damage(damage)
	if knockback.length() > 0:
		velocity = knockback
	if hitstun > 0:
		stun(hitstun)

func take_damage(amount: int, _attacker: Node = null) -> void:
	current_hp -= amount
	current_hp = max(current_hp, 0)
	health_changed.emit(current_hp, MAX_HP)
	_flash_damage()

	if AudioManager:
		AudioManager.play_sfx("enemies/geist_hurt", 0.15)

	print("[AshwormLarge] Took %d damage, HP: %d/%d" % [amount, current_hp, MAX_HP])

	if current_hp <= 0:
		die()

func _flash_damage() -> void:
	if not animated_sprite:
		return
	var original_modulate = animated_sprite.modulate
	animated_sprite.modulate = Color(0.5, 0.1, 0.1, 1.0)
	await get_tree().create_timer(0.1).timeout
	if animated_sprite:
		animated_sprite.modulate = original_modulate

# ============================================================================
# BURROW STATE
# ============================================================================

func set_burrowed(is_underground: bool) -> void:
	"""Controls invulnerability during burrow"""
	is_burrowed = is_underground

	if is_underground:
		burrowed.emit()
		print("[AshwormLarge] Burrowed (invulnerable)")
	else:
		surfaced.emit()
		print("[AshwormLarge] Surfaced (vulnerable)")

# ============================================================================
# DEATH
# ============================================================================

func die() -> void:
	print("[AshwormLarge] Died at %v" % global_position)
	died.emit()
	EventBus.enemy_died.emit(self, global_position)
	CombatManager.unregister_enemy(self)

	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)

	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)
	if hitbox:
		hitbox.set_deferred("monitoring", false)
		hitbox.set_deferred("monitorable", false)
	if ai_controller:
		ai_controller.set_process(false)

	if AudioManager:
		AudioManager.play_sfx("enemies/geist_death", 0.15)

	_spawn_loot()
	await get_tree().create_timer(0.5).timeout

	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await tween.finished
	queue_free()

func _spawn_loot() -> void:
	var gold_coin_scene = load("res://environment/pickups/gold_coin.tscn")
	if not gold_coin_scene:
		return

	var coin_count = randi() % 3 + 4  # 4-6 coins
	for i in range(coin_count):
		var coin = gold_coin_scene.instantiate()
		var offset = Vector2(randf_range(-20, 20), randf_range(-20, 20))
		coin.global_position = global_position + offset
		coin.gold_value = 1
		get_tree().current_scene.call_deferred("add_child", coin)

# ============================================================================
# STUN SYSTEM
# ============================================================================

func stun(duration: float) -> void:
	is_stunned = true
	stun_duration = duration

	if ai_controller and ai_controller.has_method("cancel_attack"):
		ai_controller.cancel_attack()

	if animated_sprite:
		animated_sprite.modulate = Color(0.3, 0.3, 0.1, 1.0)

	stunned.emit(duration)
	EventBus.enemy_stunned.emit(self, duration)

func _end_stun() -> void:
	is_stunned = false
	stun_duration = 0.0

	if animated_sprite:
		animated_sprite.modulate = Color(0.157, 0.157, 0.157, 1.0)

	stun_ended.emit()

# ============================================================================
# UTILITY
# ============================================================================

func get_hp_percent() -> float:
	return float(current_hp) / float(MAX_HP)

func is_alive() -> bool:
	return current_hp > 0
