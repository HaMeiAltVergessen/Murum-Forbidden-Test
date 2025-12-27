extends Node
class_name Urteil

## Urteil der Zerstörung (Judgment of Destruction)
## Press Key 2 to mark nearest enemy with death curse
## When marked enemy dies, they explode - pulling and damaging nearby enemies
## Chain reaction: if pulled enemy is also marked and dies, they explode too

# ============================================================================
# CONSTANTS
# ============================================================================

# Ability Parameters
const MARK_RANGE: float = 200.0        # Max distance to mark enemy
const EXPLOSION_RADIUS: float = 200.0  # Explosion detection radius
const PULL_FORCE: float = 300.0        # Force pulling enemies inward
const PULL_DURATION: float = 0.5       # How long enemies are pulled
const EXPLOSION_DAMAGE: int = 25       # Damage to enemies in explosion

# Resource Costs
const MANA_COST: int = 30
const COOLDOWN_DURATION: float = 12.0
const MARK_DURATION: float = 15.0      # Mark expires after 15s

# VFX
const EXPLOSION_HITSTOP: float = 0.12  # Brief hitstop on explosion

# ============================================================================
# STATE
# ============================================================================

var is_on_cooldown: bool = false
var cooldown_timer: float = 0.0

# Marked enemy tracking
var marked_enemy: Node = null
var mark_timer: float = 0.0

# ============================================================================
# REFERENCES
# ============================================================================

var player: CharacterBody2D = null
var mana_component: Node = null

# ============================================================================
# SIGNALS
# ============================================================================

signal urteil_activated(enemy: Node)
signal urteil_mark_applied(enemy: Node)
signal urteil_mark_expired(enemy: Node)
signal urteil_explosion_triggered(position: Vector2, enemy: Node)
signal urteil_enemy_hit(enemy: Node, damage: int)
signal urteil_cooldown_started(duration: float)
signal urteil_cooldown_finished()

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Get player reference (via parent CombatSystem)
	var combat_system = get_parent()
	if combat_system:
		player = combat_system.owner as CharacterBody2D

	# Fallback
	if not player:
		player = owner as CharacterBody2D

	if not player:
		print("[Urteil] ERROR: Could not find player reference!")
		return

	# Get mana component
	mana_component = player.get_node_or_null("ManaComponent")
	if not mana_component:
		print("[Urteil] WARNING: ManaComponent not found!")

	# Connect to enemy death events
	EventBus.enemy_died.connect(_on_enemy_died)

	print("[Urteil] Initialized (Judgment of Destruction)")

# ============================================================================
# INPUT
# ============================================================================

func _input(event: InputEvent) -> void:
	# Activate on Key 2 press
	if event.is_action_pressed("ability_2"):
		attempt_activation()

# ============================================================================
# TIMERS
# ============================================================================

func _process(delta: float) -> void:
	# Update cooldown timer
	if is_on_cooldown:
		cooldown_timer -= delta

		if cooldown_timer <= 0.0:
			_finish_cooldown()

	# Update mark timer
	if marked_enemy and is_instance_valid(marked_enemy):
		mark_timer -= delta

		if mark_timer <= 0.0:
			_expire_mark()

func _start_cooldown() -> void:
	"""Starts the cooldown timer"""
	is_on_cooldown = true
	cooldown_timer = COOLDOWN_DURATION

	print("[Urteil] Cooldown started (%.1fs)" % COOLDOWN_DURATION)

	# Emit signals
	urteil_cooldown_started.emit(COOLDOWN_DURATION)
	EventBus.urteil_cooldown_started.emit(COOLDOWN_DURATION)

func _finish_cooldown() -> void:
	"""Finishes the cooldown"""
	is_on_cooldown = false
	cooldown_timer = 0.0

	print("[Urteil] Cooldown finished - Ready!")

	# Emit signals
	urteil_cooldown_finished.emit()
	EventBus.urteil_cooldown_finished.emit()

# ============================================================================
# ACTIVATION
# ============================================================================

func attempt_activation() -> bool:
	"""Attempts to activate Urteil. Returns true if successful."""

	# Check cooldown
	if is_on_cooldown:
		print("[Urteil] On cooldown (%.1fs remaining)" % cooldown_timer)
		return false

	# Check mana
	if not mana_component:
		print("[Urteil] ERROR: ManaComponent not available!")
		return false

	if not mana_component.has_mana(MANA_COST):
		print("[Urteil] Not enough mana (%d required, %d available)" % [MANA_COST, mana_component.current_mana])
		return false

	# Find nearest enemy in range
	var target = _find_nearest_enemy()
	if not target:
		print("[Urteil] No enemy in range (%.0fpx)" % MARK_RANGE)
		return false

	# All checks passed - activate!
	_activate(target)
	return true

func _activate(target: Node) -> void:
	"""Activates Urteil on the target enemy"""
	print("[Urteil] ===== ACTIVATED ON %s =====" % target.name)

	# Consume mana
	if not mana_component.use_mana(MANA_COST):
		print("[Urteil] ERROR: Failed to consume mana!")
		return

	print("[Urteil] Consumed %d mana" % MANA_COST)

	# Remove existing mark if any
	if marked_enemy and is_instance_valid(marked_enemy):
		_remove_mark(marked_enemy)

	# Apply mark to target
	_apply_mark(target)

	# VFX
	_spawn_mark_vfx(target)

	# Audio
	AudioManager.play_sfx("player_urteil_mark", 0.15)

	# Start cooldown
	_start_cooldown()

	# Emit signal
	urteil_activated.emit(target)
	EventBus.urteil_activated.emit(target)

# ============================================================================
# TARGETING
# ============================================================================

func _find_nearest_enemy() -> Node:
	"""Finds the nearest enemy within MARK_RANGE"""

	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest_enemy: Node = null
	var nearest_distance: float = MARK_RANGE

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		var distance = player.global_position.distance_to(enemy.global_position)

		if distance <= nearest_distance:
			nearest_distance = distance
			nearest_enemy = enemy

	if nearest_enemy:
		print("[Urteil] Found nearest enemy: %s (%.1fpx)" % [nearest_enemy.name, nearest_distance])
	else:
		print("[Urteil] No enemies in range")

	return nearest_enemy

# ============================================================================
# MARK MANAGEMENT
# ============================================================================

func _apply_mark(enemy: Node) -> void:
	"""Applies the death mark to an enemy"""

	marked_enemy = enemy
	mark_timer = MARK_DURATION

	# Set custom property on enemy
	enemy.set_meta("urteil_marked", true)
	enemy.set_meta("urteil_marker", self)

	print("[Urteil] Mark applied to %s (expires in %.1fs)" % [enemy.name, MARK_DURATION])

	# Emit signal
	urteil_mark_applied.emit(enemy)
	EventBus.urteil_mark_applied.emit(enemy)

func _remove_mark(enemy: Node) -> void:
	"""Removes the death mark from an enemy"""

	if not is_instance_valid(enemy):
		return

	enemy.remove_meta("urteil_marked")
	enemy.remove_meta("urteil_marker")

	print("[Urteil] Mark removed from %s" % enemy.name)

func _expire_mark() -> void:
	"""Called when mark duration expires"""

	if not marked_enemy or not is_instance_valid(marked_enemy):
		marked_enemy = null
		mark_timer = 0.0
		return

	print("[Urteil] Mark expired on %s" % marked_enemy.name)

	var expired_enemy = marked_enemy

	# Remove mark
	_remove_mark(marked_enemy)
	marked_enemy = null
	mark_timer = 0.0

	# Emit signal
	urteil_mark_expired.emit(expired_enemy)
	EventBus.urteil_mark_expired.emit(expired_enemy)

# ============================================================================
# EXPLOSION
# ============================================================================

func _on_enemy_died(enemy: Node, death_position: Vector2) -> void:
	"""Called when any enemy dies - check if they were marked"""

	if not is_instance_valid(enemy):
		return

	# Check if this enemy was marked
	if not enemy.has_meta("urteil_marked"):
		return

	print("[Urteil] ===== MARKED ENEMY DIED: %s =====" % enemy.name)

	# Clear our tracked mark if it's this enemy
	if marked_enemy == enemy:
		marked_enemy = null
		mark_timer = 0.0

	# Trigger explosion
	_trigger_explosion(death_position, enemy)

func _trigger_explosion(position: Vector2, source_enemy: Node) -> void:
	"""Triggers explosion at position - pulls and damages enemies"""

	print("[Urteil] EXPLOSION at %v (source: %s)" % [position, source_enemy.name if is_instance_valid(source_enemy) else "destroyed"])

	# Find all enemies in radius
	var enemies = get_tree().get_nodes_in_group("enemies")
	var hit_count = 0

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		# Skip the source enemy (they're already dead)
		if enemy == source_enemy:
			continue

		var distance = position.distance_to(enemy.global_position)

		if distance <= EXPLOSION_RADIUS:
			_apply_explosion_effect(enemy, position, distance)
			hit_count += 1

	print("[Urteil] Explosion hit %d enemies" % hit_count)

	# VFX
	_spawn_explosion_vfx(position)

	# Audio
	AudioManager.play_sfx("player_urteil_explosion", 0.1)

	# Camera shake
	if player.has_node("PlayerCamera"):
		player.get_node("PlayerCamera").add_trauma(0.3)

	# Hitstop
	GlobalTimeEffects.hit_stop(EXPLOSION_HITSTOP)

	# Emit signal
	urteil_explosion_triggered.emit(position, source_enemy)
	EventBus.urteil_explosion_triggered.emit(position, source_enemy)

func _apply_explosion_effect(enemy: Node, explosion_center: Vector2, distance: float) -> void:
	"""Applies pull and damage to a single enemy"""

	# Calculate pull direction (toward explosion center)
	var direction = (explosion_center - enemy.global_position).normalized()

	print("[Urteil] Pulling %s (dist: %.1f, force: %.0f)" % [enemy.name, distance, PULL_FORCE])

	# Apply pull force (toward center)
	var knockback_component = enemy.get_node_or_null("KnockbackComponent")
	if knockback_component and knockback_component.has_method("apply_knockback"):
		knockback_component.apply_knockback(direction, PULL_FORCE, PULL_DURATION)
	elif enemy.has_method("apply_knockback"):
		enemy.apply_knockback(direction, PULL_FORCE, PULL_DURATION)

	# Apply damage
	if enemy.has_method("take_damage"):
		enemy.take_damage(EXPLOSION_DAMAGE, player)
		print("[Urteil] Damaged %s for %d" % [enemy.name, EXPLOSION_DAMAGE])

	# Spawn hit VFX on enemy
	_spawn_hit_vfx(enemy)

	# Emit signal
	urteil_enemy_hit.emit(enemy, EXPLOSION_DAMAGE)
	EventBus.urteil_enemy_hit.emit(enemy, EXPLOSION_DAMAGE)

# ============================================================================
# VFX
# ============================================================================

func _spawn_mark_vfx(enemy: Node) -> void:
	"""Spawns persistent mark VFX on enemy"""

	var vfx_path = "res://vfx/particles/urteil_mark.tscn"

	if not ResourceLoader.exists(vfx_path):
		print("[Urteil] Mark VFX not found: %s" % vfx_path)
		return

	var mark_scene = load(vfx_path)
	var mark_vfx = mark_scene.instantiate()
	enemy.add_child(mark_vfx)
	mark_vfx.emitting = true

	# Auto-cleanup when mark expires
	await get_tree().create_timer(MARK_DURATION).timeout
	if mark_vfx:
		mark_vfx.queue_free()

func _spawn_explosion_vfx(position: Vector2) -> void:
	"""Spawns explosion VFX at death position"""

	var vfx_path = "res://vfx/particles/urteil_explosion.tscn"

	if not ResourceLoader.exists(vfx_path):
		print("[Urteil] Explosion VFX not found: %s" % vfx_path)
		return

	var explosion_scene = load(vfx_path)
	var explosion = explosion_scene.instantiate()
	get_tree().root.add_child(explosion)
	explosion.global_position = position
	explosion.emitting = true

	# Auto-cleanup
	await get_tree().create_timer(2.0).timeout
	if explosion:
		explosion.queue_free()

func _spawn_hit_vfx(enemy: Node) -> void:
	"""Spawns hit effect on pulled enemy"""

	var vfx_path = "res://vfx/particles/urteil_pull.tscn"

	if not ResourceLoader.exists(vfx_path):
		# Silently skip if VFX not found
		return

	var hit_scene = load(vfx_path)
	var hit = hit_scene.instantiate()
	get_tree().root.add_child(hit)
	hit.global_position = enemy.global_position
	hit.emitting = true

	# Auto-cleanup
	await get_tree().create_timer(1.0).timeout
	if hit:
		hit.queue_free()

# ============================================================================
# UTILITY
# ============================================================================

func is_available() -> bool:
	"""Returns true if Urteil can be activated"""
	if is_on_cooldown:
		return false

	if not mana_component:
		return false

	return mana_component.has_mana(MANA_COST)

func get_cooldown_remaining() -> float:
	"""Returns remaining cooldown time"""
	return cooldown_timer if is_on_cooldown else 0.0

func get_cooldown_percentage() -> float:
	"""Returns cooldown as percentage (0.0 = ready, 1.0 = just used)"""
	if not is_on_cooldown:
		return 0.0

	return cooldown_timer / COOLDOWN_DURATION

func is_enemy_marked(enemy: Node) -> bool:
	"""Returns true if the given enemy is marked"""
	if not is_instance_valid(enemy):
		return false

	return enemy.has_meta("urteil_marked")

func get_marked_enemy() -> Node:
	"""Returns the currently marked enemy, or null"""
	return marked_enemy if is_instance_valid(marked_enemy) else null

func get_mark_time_remaining() -> float:
	"""Returns remaining mark duration"""
	return mark_timer if marked_enemy else 0.0
