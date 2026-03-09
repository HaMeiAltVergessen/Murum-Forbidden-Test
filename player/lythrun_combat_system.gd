extends Node2D
## LythrunCombatSystem - P2's combat orchestrator (modular, like P1's CombatSystem)
## Handles 3-hit void strike chain, charged attack, shockwave, and HitboxComponent
class_name LythrunCombatSystem

# ============ REFERENCES ============
@onready var player: CharacterBody2D = get_parent()
@onready var hitbox: Area2D = $HitboxComponent
@onready var movement_controller: MovementController = player.get_node_or_null("MovementController")

# ============ SUBSYSTEMS ============
var combo_tracker: ComboTracker = null

# ============ ATTACK CONFIGURATION ============
@export var attack_multipliers: Array[float] = [0.8, 0.9, 1.2]
@export var attack_durations: Array[float] = [0.3, 0.35, 0.4]
@export var combo_window: float = 1.5  # P2's combo timeout

# ============ SHOCKWAVE CONFIGURATION ============
const SHOCKWAVE_BASE_MULTIPLIER: float = 0.4
const SHOCKWAVE_RADIUS: float = 150.0

# ============ CHARGED ATTACK CONFIGURATION ============
const CHARGED_MULTIPLIER: float = 1.5
const CHARGED_RADIUS: float = 100.0
const CHARGED_RECOVERY: float = 0.6

# ============ COMBO STATE ============
var current_combo: int = 0
var is_attacking: bool = false
var combo_timer: float = 0.0
var attack_timer: float = 0.0
var combo_stacks: int = 0

# ============ ATTACK QUEUE ============
var attack_queued: bool = false

# ============ COMBAT CONTROL ============
var combat_enabled: bool = true


func _ready() -> void:
	if not hitbox:
		push_error("[LythrunCombatSystem] HitboxComponent not found as child!")
		return

	hitbox.monitoring = false
	hitbox.visible = false

	_create_combo_tracker()

	print("[LythrunCombatSystem] Initialized with HitboxComponent")


func _process(delta: float) -> void:
	_update_combo_timer(delta)
	_update_attack_timer(delta)


# ============ PUBLIC API (called from lythrun_player.gd) ============

func request_attack() -> void:
	if not combat_enabled:
		return
	if is_attacking:
		attack_queued = true
		return
	_perform_attack()


func charged_attack() -> void:
	if not combat_enabled or is_attacking:
		return
	_perform_charged_attack()


# ============ ATTACK SYSTEM ============

func _perform_attack() -> void:
	if combo_timer > 0 and current_combo < 3:
		current_combo += 1
	else:
		current_combo = 1

	is_attacking = true
	player.is_attacking = true
	attack_queued = false
	combo_timer = combo_window
	attack_timer = attack_durations[current_combo - 1]

	# Calculate damage from player's base_damage
	var damage = int(player.base_damage * attack_multipliers[current_combo - 1])

	# Apply Geschaerfter Wille damage bonus
	if UpgradeManager:
		var dmg_mult = UpgradeManager.get_damage_multiplier()
		if dmg_mult > 1.0:
			damage = int(damage * dmg_mult)

	if hitbox.has_method("set_damage"):
		hitbox.set_damage(damage)

	_activate_hitbox()

	# Stop horizontal movement during attack
	if player:
		player.velocity.x = 0

	# Audio
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("void_strike")

	# Animate
	_animate_player_attack(current_combo)
	_animate_sense_attack(current_combo)

	# P2 EventBus signals
	EventBus.player_attacked.emit(current_combo)

	# Combo signal: after 1st hit, finisher is coming
	if current_combo == 1:
		EventBus.p2_combo_finisher_ready.emit()

	print("[LythrunCombatSystem] Void Strike %d/3 - Damage: %d" % [current_combo, damage])

	# Echo der Macht: chance for an echo hit after attack
	if UpgradeManager:
		var echo_chance = UpgradeManager.get_echo_chance()
		if echo_chance > 0.0 and randf() < echo_chance:
			_trigger_echo_hit(damage)


func _update_attack_timer(delta: float) -> void:
	if not is_attacking:
		return

	attack_timer -= delta
	if attack_timer <= 0:
		_end_attack()


func _end_attack() -> void:
	_deactivate_hitbox()

	# Check for shockwave on 3rd hit
	if current_combo == 3:
		EventBus.p2_combo_finisher_executed.emit(current_combo)
		combo_stacks = min(combo_stacks + 1, 3)
		_spawn_void_shockwave()

	is_attacking = false
	player.is_attacking = false

	# Check for queued attack
	if attack_queued:
		_perform_attack()


func _update_combo_timer(delta: float) -> void:
	if combo_timer > 0:
		combo_timer -= delta
		if combo_timer <= 0:
			_reset_combo()


func _reset_combo() -> void:
	var old_combo = current_combo
	current_combo = 0
	combo_stacks = 0
	EventBus.p2_combo_broken.emit(old_combo)
	print("[LythrunCombatSystem] Combo reset")


# ============ CHARGED VOID STRIKE ============

func _perform_charged_attack() -> void:
	is_attacking = true
	player.is_attacking = true

	var charged_damage = int(player.base_damage * CHARGED_MULTIPLIER)

	# Apply Geschaerfter Wille damage bonus
	if UpgradeManager:
		var dmg_mult = UpgradeManager.get_damage_multiplier()
		if dmg_mult > 1.0:
			charged_damage = int(charged_damage * dmg_mult)

	# Create temporary AoE hitbox for charged attack (larger than melee)
	var aoe = Area2D.new()
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = CHARGED_RADIUS

	collision.shape = shape
	aoe.add_child(collision)
	player.add_child(aoe)
	aoe.position = Vector2.ZERO

	# Use same collision layers as HitboxComponent
	aoe.collision_layer = hitbox.collision_layer
	aoe.collision_mask = hitbox.collision_mask
	aoe.monitoring = true
	aoe.monitorable = true

	# Visual
	var visual = Sprite2D.new()
	visual.texture = PlaceholderTexture2D.new()
	if visual.texture is PlaceholderTexture2D:
		visual.texture.size = Vector2(CHARGED_RADIUS * 2, CHARGED_RADIUS * 2)
	visual.modulate = Color(0.7, 0.2, 1.0, 0.8)
	aoe.add_child(visual)

	var tween = visual.create_tween()
	tween.tween_property(visual, "scale", Vector2(1.3, 1.3), 0.2)
	tween.parallel().tween_property(visual, "modulate:a", 0.0, 0.2)

	# Damage via HurtboxComponent pipeline
	aoe.area_entered.connect(func(area: Area2D):
		if not area or not is_instance_valid(area):
			return
		if not area is HurtboxComponent:
			return
		var enemy = area.owner if area.owner else area.get_parent()
		if not enemy or not is_instance_valid(enemy):
			return
		if enemy == player:
			return
		if enemy.is_in_group("player") or enemy.is_in_group("player2"):
			return
		area.take_damage(charged_damage, Vector2.ZERO, 0.2, player)
		EventBus.hit_registered.emit(player, enemy, charged_damage)
		print("[LythrunCombatSystem] Charged Strike hit %s for %d" % [enemy.name, charged_damage])
	)

	# Audio
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("void_strike")

	# Camera shake
	var camera = player.get_viewport().get_camera_2d()
	if camera and camera.has_method("shake"):
		camera.shake(10.0, 0.3)

	print("[LythrunCombatSystem] Charged Void Strike - Damage: %d, Radius: %.0f" % [charged_damage, CHARGED_RADIUS])

	# Cleanup
	await player.get_tree().create_timer(0.2).timeout
	if is_instance_valid(aoe):
		aoe.queue_free()

	await player.get_tree().create_timer(CHARGED_RECOVERY).timeout
	if is_instance_valid(self):
		is_attacking = false
		player.is_attacking = false


# ============ SHOCKWAVE ============

func _spawn_void_shockwave() -> void:
	var stack_multiplier = 1.0 + (combo_stacks * 0.2)
	var shockwave_damage = int(player.base_damage * SHOCKWAVE_BASE_MULTIPLIER * stack_multiplier)

	# Apply Geschaerfter Wille damage bonus
	if UpgradeManager:
		var dmg_mult = UpgradeManager.get_damage_multiplier()
		if dmg_mult > 1.0:
			shockwave_damage = int(shockwave_damage * dmg_mult)

	var shockwave = Area2D.new()
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = SHOCKWAVE_RADIUS

	collision.shape = shape
	shockwave.add_child(collision)
	player.get_parent().add_child(shockwave)
	shockwave.global_position = player.global_position + Vector2(0, 10)

	# Use same collision layers as HitboxComponent
	shockwave.collision_layer = hitbox.collision_layer
	shockwave.collision_mask = hitbox.collision_mask
	shockwave.monitoring = true
	shockwave.monitorable = true

	# Damage via HurtboxComponent pipeline
	await player.get_tree().process_frame
	var areas = shockwave.get_overlapping_areas()
	for area in areas:
		if not area is HurtboxComponent:
			continue
		var enemy = area.owner if area.owner else area.get_parent()
		if not enemy or enemy == player:
			continue
		if enemy.is_in_group("player") or enemy.is_in_group("player2"):
			continue
		area.take_damage(shockwave_damage, Vector2.ZERO, 0.2, player)
		EventBus.hit_registered.emit(player, enemy, shockwave_damage)
		print("[LythrunCombatSystem] Shockwave hit %s for %d" % [enemy.name, shockwave_damage])

	# VFX
	_spawn_shockwave_vfx(shockwave.global_position)

	# Audio
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("void_shockwave")

	# Camera shake
	var camera = player.get_viewport().get_camera_2d()
	if camera and camera.has_method("shake"):
		camera.shake(8.0 * stack_multiplier, 0.3)

	print("[LythrunCombatSystem] Shockwave! Stacks: %d | Damage: %d" % [combo_stacks, shockwave_damage])

	await player.get_tree().create_timer(0.3).timeout
	if is_instance_valid(shockwave):
		shockwave.queue_free()


# ============ HITBOX MANAGEMENT ============

func _activate_hitbox() -> void:
	if not hitbox:
		return

	if hitbox.has_method("activate"):
		hitbox.activate()
	else:
		hitbox.monitoring = true
		hitbox.visible = true

	# Position based on facing direction
	if movement_controller:
		var facing: int = movement_controller.get_facing_direction()
		hitbox.scale.x = abs(hitbox.scale.x) * facing
		hitbox.position.x = abs(hitbox.position.x) * facing
	elif player and player.has_node("Sprite2D"):
		var sprite = player.get_node("Sprite2D")
		var facing = -1 if sprite.flip_h else 1
		hitbox.scale.x = abs(hitbox.scale.x) * facing
		hitbox.position.x = abs(hitbox.position.x) * facing


func _deactivate_hitbox() -> void:
	if not hitbox:
		return

	if hitbox.has_method("deactivate"):
		hitbox.deactivate()
	else:
		hitbox.monitoring = false
		hitbox.visible = false


# ============ COMBO TRACKER ============

func _create_combo_tracker() -> void:
	combo_tracker = ComboTracker.new()
	combo_tracker.name = "ComboTracker"
	combo_tracker.is_player_2 = true
	add_child(combo_tracker)
	print("[LythrunCombatSystem] ComboTracker created (P2 mode)")


# ============ ANIMATION ============

func _animate_player_attack(attack_num: int) -> void:
	var sprite = player.get_node_or_null("Sprite2D")
	if not sprite:
		return

	var tween = create_tween()
	tween.set_parallel(true)

	match attack_num:
		1:
			tween.tween_property(sprite, "position:x", 15, attack_durations[0] * 0.4)
			tween.tween_property(sprite, "scale", Vector2(1.15, 0.85), attack_durations[0] * 0.4)
			tween.chain().tween_property(sprite, "position:x", 0, attack_durations[0] * 0.6)
			tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), attack_durations[0] * 0.6)
		2:
			tween.tween_property(sprite, "position:y", -20, attack_durations[1] * 0.3)
			tween.tween_property(sprite, "position:x", 10, attack_durations[1] * 0.3)
			tween.tween_property(sprite, "scale", Vector2(1.2, 0.8), attack_durations[1] * 0.3)
			tween.chain().tween_property(sprite, "position:y", 0, attack_durations[1] * 0.7)
			tween.parallel().tween_property(sprite, "position:x", 0, attack_durations[1] * 0.7)
			tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), attack_durations[1] * 0.7)
		3:
			tween.tween_property(sprite, "position:y", -25, attack_durations[2] * 0.2)
			tween.tween_property(sprite, "scale", Vector2(1.3, 0.7), attack_durations[2] * 0.2)
			tween.chain().tween_property(sprite, "position:x", 15, attack_durations[2] * 0.3)
			tween.parallel().tween_property(sprite, "position:y", 5, attack_durations[2] * 0.3)
			tween.parallel().tween_property(sprite, "scale", Vector2(0.85, 1.15), attack_durations[2] * 0.3)
			tween.chain().tween_property(sprite, "position:x", 0, attack_durations[2] * 0.5)
			tween.parallel().tween_property(sprite, "position:y", 0, attack_durations[2] * 0.5)
			tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), attack_durations[2] * 0.5)


func _animate_sense_attack(attack_num: int) -> void:
	var sense_sprite = player.get_node_or_null("SenseSprite")
	if not sense_sprite:
		return

	var tween = create_tween()
	match attack_num:
		1:
			tween.tween_property(sense_sprite, "rotation", -PI/3, attack_durations[0] * 0.3)
			tween.tween_property(sense_sprite, "rotation", PI/6, attack_durations[0] * 0.7)
		2:
			tween.tween_property(sense_sprite, "rotation", -PI/6, attack_durations[1] * 0.3)
			tween.tween_property(sense_sprite, "rotation", PI/3, attack_durations[1] * 0.7)
		3:
			tween.tween_property(sense_sprite, "rotation", PI/4, attack_durations[2] * 0.4)
			tween.tween_property(sense_sprite, "rotation", -PI/4, attack_durations[2] * 0.6)

	await tween.finished
	var return_tween = create_tween()
	return_tween.tween_property(sense_sprite, "rotation", 0.0, 0.1)


# ============ VFX ============

func _spawn_shockwave_vfx(pos: Vector2) -> void:
	var ring = Sprite2D.new()
	ring.texture = PlaceholderTexture2D.new()
	if ring.texture is PlaceholderTexture2D:
		ring.texture.size = Vector2(SHOCKWAVE_RADIUS * 2, SHOCKWAVE_RADIUS * 2)
	ring.modulate = Color(0.5, 0.1, 0.8, 0.6)
	ring.global_position = pos
	player.get_parent().add_child(ring)

	var tween = ring.create_tween()
	tween.tween_property(ring, "scale", Vector2(1.5, 1.5), 0.3)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.3)
	tween.tween_callback(ring.queue_free)


# ============ ECHO DER MACHT ============

func _trigger_echo_hit(base_damage: int) -> void:
	"""Triggers an echo hit after a short delay (Echo der Macht upgrade)"""
	var echo_damage: int = int(base_damage * 0.5)
	if UpgradeManager.has_echo_strong():
		echo_damage = base_damage
	print("[LythrunCombatSystem] Echo der Macht! Extra hit for %d damage" % echo_damage)

	await player.get_tree().create_timer(0.1).timeout
	if not is_instance_valid(hitbox):
		return

	if hitbox.has_method("set_damage"):
		hitbox.set_damage(echo_damage)
	_activate_hitbox()

	if UpgradeManager.has_echo_aoe():
		hitbox.scale *= 1.5

	await player.get_tree().create_timer(0.1).timeout
	if is_instance_valid(hitbox):
		if UpgradeManager.has_echo_aoe():
			hitbox.scale /= 1.5
		_deactivate_hitbox()


# ============ GETTERS ============

func can_attack() -> bool:
	return combat_enabled and not is_attacking

func get_current_combo() -> int:
	return current_combo
