extends CharacterBody2D
class_name Nightborne

## Nightborne - Fast Agile Enemy
## Chases player and attacks with high speed
## Godot 4.4 compatible

# ============================================================================
# CONSTANTS
# ============================================================================

const MAX_HP: int = 25
const MOVE_SPEED: float = 100.0
const DAMAGE: int = 12
const MIN_COINS: int = 2
const MAX_COINS: int = 3

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
@onready var ai_controller: Node = $NightborneAI
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
	add_to_group("enemies")
	add_to_group("nightborne")

	if hurtbox:
		hurtbox.damage_received.connect(_on_damage_received)

	if animated_sprite:
		animated_sprite.modulate = Color.WHITE

	print("[Nightborne] Initialized at %v, HP: %d/%d" % [global_position, current_hp, MAX_HP])

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
# DAMAGE HANDLING
# ============================================================================

func _on_damage_received(damage: int, knockback: Vector2, hitstun: float) -> void:
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
	print("[Nightborne] Took %d damage, HP: %d/%d" % [amount, current_hp, MAX_HP])
	if current_hp <= 0:
		die()

func _flash_damage() -> void:
	if not animated_sprite:
		return
	var original_modulate = animated_sprite.modulate
	animated_sprite.modulate = Color(2.0, 0.5, 0.5, 1.0)
	await get_tree().create_timer(0.1).timeout
	if animated_sprite:
		animated_sprite.modulate = original_modulate

# ============================================================================
# DEATH
# ============================================================================

func die() -> void:
	print("[Nightborne] Died at %v" % global_position)
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
	var coin_count = randi() % (MAX_COINS - MIN_COINS + 1) + MIN_COINS
	for i in range(coin_count):
		var coin = gold_coin_scene.instantiate()
		var offset = Vector2(randf_range(-30, 30), randf_range(-30, 30))
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
		animated_sprite.modulate = Color(1.5, 1.5, 0.5, 1.0)
	stunned.emit(duration)
	EventBus.enemy_stunned.emit(self, duration)

func _end_stun() -> void:
	is_stunned = false
	stun_duration = 0.0
	if animated_sprite:
		animated_sprite.modulate = Color.WHITE
	stun_ended.emit()

# ============================================================================
# UTILITY
# ============================================================================

func get_hp_percent() -> float:
	return float(current_hp) / float(MAX_HP)

func is_alive() -> bool:
	return current_hp > 0
