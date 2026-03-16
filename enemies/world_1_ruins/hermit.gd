extends CharacterBody2D
class_name Hermit

## Der Eremit (The Hermit) - MINI-BOSS
## Starts as NPC, triggers dialog, then transitions to boss fight.
## Phase 1 (100%-50%): Slow projectiles, teleport every 12s
## Phase 2 (<50%): Faster projectiles, teleport every 8s, melee attacks
## Drops temple key on death.

# ============================================================================
# CONSTANTS
# ============================================================================

const MAX_HP: int = 100
const MOVE_SPEED: float = 80.0
const PROJECTILE_DAMAGE: int = 35
const MELEE_DAMAGE: int = 50
const DETECTION_RANGE: float = 600.0

const PHASE1_PROJECTILE_SPEED: float = 250.0
const PHASE2_PROJECTILE_SPEED: float = 450.0
const PHASE1_TELEPORT_INTERVAL: float = 12.0
const PHASE2_TELEPORT_INTERVAL: float = 8.0

const MIN_COINS: int = 10
const MAX_COINS: int = 15

const DIALOG_ID_SP: String = "eremit_encounter"
const DIALOG_ID_COOP: String = "eremit_encounter_coop"

# ============================================================================
# EXPORTS
# ============================================================================

@export var is_defeated_flag: String = "eremit_defeated"

# ============================================================================
# STATE
# ============================================================================

enum Mode { NPC, FIGHTING, DEAD }
var current_mode: Mode = Mode.NPC

var current_hp: int = MAX_HP
var is_dead: bool = false
var is_stunned: bool = false
var stun_duration: float = 0.0
var current_phase: int = 1
var dialog_triggered: bool = false

# ============================================================================
# REFERENCES
# ============================================================================

@onready var sprite: Sprite2D = $Sprite2D
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var hitbox: HitboxComponent = $HitboxComponent
@onready var detection_area: Area2D = $DetectionArea
@onready var health_component: HealthComponent = $HealthComponent
@onready var ai_controller: Node = $HermitAI
@onready var health_bar: Node = $HealthBarContainer

# ============================================================================
# SIGNALS
# ============================================================================

signal health_changed(current: int, maximum: int)
signal phase_changed(new_phase: int)
signal died
signal fight_started

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("hermit")
	add_to_group("mini_boss")

	# Setup health
	if health_component:
		health_component.max_health = MAX_HP
		health_component.current_health = MAX_HP

	# Connect signals
	if hurtbox:
		hurtbox.damage_received.connect(_on_damage_received)
	if health_component:
		health_component.damage_taken.connect(_on_health_damage_taken)
		health_component.health_depleted.connect(_on_health_depleted)
	if detection_area:
		detection_area.body_entered.connect(_on_detection_body_entered)
		detection_area.body_exited.connect(_on_detection_body_exited)

	# Connect dialog finish
	EventBus.dialog_finished.connect(_on_dialog_finished)

	# Start in NPC mode
	_enter_npc_mode()

	# Check if already defeated
	if WorldManager and WorldManager.is_room_cleared(is_defeated_flag):
		queue_free()
		return

	print("[Hermit] Initialized as NPC at %v" % global_position)


# ============================================================================
# NPC MODE
# ============================================================================

func _enter_npc_mode() -> void:
	"""Sets up NPC mode - peaceful, interactable"""
	current_mode = Mode.NPC

	# Disable combat components
	if hurtbox:
		hurtbox.set_deferred("monitorable", false)
	if hitbox:
		hitbox.set_deferred("monitoring", false)
	if ai_controller:
		ai_controller.set_process(false)
	if health_bar:
		health_bar.visible = false

	# Idle visual
	if sprite:
		sprite.modulate = Color(0.9, 0.85, 1.0, 1.0)  # Slight mystical tint


var target_player: CharacterBody2D = null
var player_in_range: bool = false
var prompt_label: Label = null

func _on_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.is_in_group("player2"):
		if current_mode == Mode.NPC and not dialog_triggered:
			player_in_range = true
			target_player = body as CharacterBody2D
			_show_interact_prompt()
		elif current_mode == Mode.FIGHTING:
			target_player = body as CharacterBody2D


func _on_detection_body_exited(body: Node2D) -> void:
	if body == target_player:
		if current_mode == Mode.NPC:
			player_in_range = false
			_hide_interact_prompt()
		elif current_mode == Mode.FIGHTING:
			pass  # Keep target in fight mode


func _show_interact_prompt() -> void:
	if not prompt_label:
		prompt_label = Label.new()
		prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prompt_label.position = Vector2(-40, -80)
		prompt_label.size = Vector2(80, 20)
		prompt_label.add_theme_font_size_override("font_size", 14)
		prompt_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
		prompt_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		prompt_label.add_theme_constant_override("outline_size", 3)
		add_child(prompt_label)
	prompt_label.text = "E - Sprechen"
	prompt_label.visible = true


func _hide_interact_prompt() -> void:
	if prompt_label:
		prompt_label.visible = false


# ============================================================================
# PROCESS
# ============================================================================

func _process(delta: float) -> void:
	if is_dead:
		return

	# NPC interaction check
	if current_mode == Mode.NPC and player_in_range and not dialog_triggered:
		var interact_pressed := false
		if InputManager:
			interact_pressed = InputManager.is_p1_action_just_pressed("interact")
		else:
			interact_pressed = Input.is_action_just_pressed("p1_interact")

		if interact_pressed:
			_trigger_dialog()

	# Stun countdown
	if is_stunned:
		stun_duration -= delta
		if stun_duration <= 0.0:
			_end_stun()


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Apply gravity
	if not is_on_floor():
		velocity.y += 980.0 * delta

	move_and_slide()


# ============================================================================
# DIALOG
# ============================================================================

func _trigger_dialog() -> void:
	if dialog_triggered:
		return
	dialog_triggered = true

	_hide_interact_prompt()

	# Choose dialog based on coop
	var use_coop = CoopManager != null and CoopManager.is_p2_active
	var dialog_id = DIALOG_ID_COOP if use_coop else DIALOG_ID_SP

	# Face player
	if target_player and sprite:
		sprite.flip_h = target_player.global_position.x < global_position.x

	if DialogManager:
		DialogManager.play_dialog(dialog_id)

	print("[Hermit] Dialog triggered: %s" % dialog_id)


func _on_dialog_finished(dialog_id: String) -> void:
	if dialog_id != DIALOG_ID_SP and dialog_id != DIALOG_ID_COOP:
		return

	# Direct transition to fight
	_start_fight()


# ============================================================================
# FIGHT START
# ============================================================================

func _start_fight() -> void:
	"""Transitions from NPC to boss fight"""
	current_mode = Mode.FIGHTING

	# Enable combat
	if hurtbox:
		hurtbox.set_deferred("monitorable", true)
	if ai_controller:
		ai_controller.set_process(true)
	if health_bar:
		health_bar.visible = true
		_update_health_bar()

	# Register with CombatManager
	CombatManager.register_enemy(self)

	# Visual: color shift to hostile
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(1.0, 0.7, 0.7, 1.0), 0.5)
		await tween.finished
		if sprite:
			sprite.modulate = Color.WHITE

	fight_started.emit()
	print("[Hermit] Fight started! Phase 1")


# ============================================================================
# DAMAGE
# ============================================================================

func _on_damage_received(damage: int, knockback: Vector2, hitstun: float) -> void:
	if current_mode != Mode.FIGHTING:
		return

	take_damage(damage)

	# Minimal knockback (boss)
	if knockback.length() > 0:
		velocity = knockback * 0.15

	if hitstun > 0.3:
		stun(hitstun * 0.3)


func take_damage(amount: int, _attacker: Node = null) -> void:
	if is_dead or current_mode != Mode.FIGHTING:
		return
	if health_component:
		health_component.take_damage(amount)


func _on_health_damage_taken(damage: int) -> void:
	current_hp = health_component.current_health
	health_changed.emit(current_hp, MAX_HP)
	_update_health_bar()

	EventBus.enemy_damaged.emit(self, damage)
	_flash_damage()
	AudioManager.play_sfx("enemy_hurt")

	# Phase check
	var hp_percent = float(current_hp) / float(MAX_HP)
	if current_phase == 1 and hp_percent <= 0.5:
		_enter_phase_2()

	print("[Hermit] Took %d damage, HP: %d/%d (%.0f%%)" % [damage, current_hp, MAX_HP, hp_percent * 100])


func _on_health_depleted() -> void:
	if is_dead:
		return
	die()


func _flash_damage() -> void:
	if not sprite:
		return
	var original = sprite.modulate
	sprite.modulate = Color(2.0, 0.5, 0.5, 1.0)
	await get_tree().create_timer(0.1).timeout
	if sprite:
		sprite.modulate = original


# ============================================================================
# PHASES
# ============================================================================

func _enter_phase_2() -> void:
	current_phase = 2
	phase_changed.emit(2)

	# Visual: brief flash
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(2.0, 0.5, 2.0, 1.0), 0.2)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)

	AudioManager.play_sfx("enemy_attack_windup")
	print("[Hermit] Phase 2! Faster projectiles, shorter teleport interval, melee unlocked")


func get_projectile_speed() -> float:
	return PHASE2_PROJECTILE_SPEED if current_phase >= 2 else PHASE1_PROJECTILE_SPEED


func get_teleport_interval() -> float:
	return PHASE2_TELEPORT_INTERVAL if current_phase >= 2 else PHASE1_TELEPORT_INTERVAL


func can_melee() -> bool:
	return current_phase >= 2


# ============================================================================
# DEATH
# ============================================================================

func die() -> void:
	if is_dead:
		return
	is_dead = true
	current_mode = Mode.DEAD

	print("[Hermit] Defeated!")

	died.emit()
	EventBus.enemy_died.emit(self, global_position)

	# Stop AI
	if ai_controller:
		ai_controller.set_process(false)

	# Disable collision
	collision_layer = 0
	collision_mask = 0
	if hurtbox:
		hurtbox.set_deferred("monitorable", false)
	if hitbox:
		hitbox.set_deferred("monitoring", false)

	# Unregister
	CombatManager.unregister_enemy(self)

	# Mark defeated
	if WorldManager:
		WorldManager.mark_room_cleared(is_defeated_flag)

	AudioManager.play_sfx("enemy_death")

	# Drop key
	_drop_temple_key()

	# Drop loot
	_spawn_loot()

	# Death animation
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 0.0, 1.5)
	tween.tween_property(sprite, "position:y", sprite.position.y - 30, 1.5)
	if health_bar:
		tween.tween_property(health_bar, "modulate:a", 0.0, 0.5)
	await tween.finished

	queue_free()


func _drop_temple_key() -> void:
	"""Drops the temple key as a pickup"""
	# Use pickup_base if available, otherwise emit signal
	var pickup_scene = load("res://environment/pickups/pickup_base.tscn")
	if pickup_scene:
		var key = pickup_scene.instantiate()
		key.global_position = global_position + Vector2(0, -20)
		if key.has_method("set") or "item_id" in key:
			key.item_id = "temple_key"
		if "pickup_id" in key:
			key.pickup_id = "eremit/temple_key"
		get_tree().current_scene.call_deferred("add_child", key)
		print("[Hermit] Temple key dropped!")
	else:
		# Fallback: just emit signal
		EventBus.item_picked_up.emit("temple_key", "Tempelschlüssel", "key")
		print("[Hermit] Temple key auto-picked (no pickup scene)")


func _spawn_loot() -> void:
	var gold_coin_scene = load("res://environment/pickups/gold_coin.tscn")
	if not gold_coin_scene:
		return
	var coin_count = randi() % (MAX_COINS - MIN_COINS + 1) + MIN_COINS
	for i in range(coin_count):
		var coin = gold_coin_scene.instantiate()
		var offset = Vector2(randf_range(-50, 50), randf_range(-50, 50))
		coin.global_position = global_position + offset
		coin.gold_value = 1
		get_tree().current_scene.call_deferred("add_child", coin)


# ============================================================================
# HEALTH BAR
# ============================================================================

func _update_health_bar() -> void:
	if not health_bar:
		return
	var bar = health_bar.get_node_or_null("HealthBar")
	if bar and bar is ProgressBar:
		bar.max_value = MAX_HP
		bar.value = current_hp


# ============================================================================
# STUN
# ============================================================================

func stun(duration: float) -> void:
	is_stunned = true
	stun_duration = duration
	if ai_controller and ai_controller.has_method("cancel_attack"):
		ai_controller.cancel_attack()
	if sprite:
		sprite.modulate = Color(1.5, 1.5, 0.5, 1.0)
	EventBus.enemy_stunned.emit(self, duration)


func _end_stun() -> void:
	is_stunned = false
	stun_duration = 0.0
	if sprite:
		sprite.modulate = Color.WHITE


# ============================================================================
# UTILITY
# ============================================================================

func has_target() -> bool:
	return target_player != null and is_instance_valid(target_player)

func get_distance_to_player() -> float:
	if not has_target():
		return INF
	return global_position.distance_to(target_player.global_position)

func get_direction_to_player() -> Vector2:
	if not has_target():
		return Vector2.ZERO
	return (target_player.global_position - global_position).normalized()

func get_hp_percent() -> float:
	return float(current_hp) / float(MAX_HP)

func is_alive() -> bool:
	return current_hp > 0
