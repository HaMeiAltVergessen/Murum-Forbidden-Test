extends Node
## HealthComponent manages entity health and damage reception
class_name HealthComponent

# ============ CONFIGURATION ============
@export var max_health: int = 100
@export var invulnerability_duration: float = 0.5

# ============ STATE ============
var current_health: int
var is_invulnerable: bool = false
var invulnerability_timer: Timer

# Run-volatile bonus HP
var _base_max_health: int = 0  # max_health before run bonuses
var _run_bonus_hp: int = 0

# Block mitigation state
var block_active: bool = false
var block_reduction: float = 0.0

# ============ SIGNALS ============
signal health_changed(new_health: int, max_health: int)
signal damage_taken(damage: int)
signal health_depleted()
signal invulnerability_started()
signal invulnerability_ended()


func _ready() -> void:
	# Apply Erwachende Essenz HP bonus (player only)
	if (owner is Murum or owner is Lythrun) and UpgradeManager:
		var hp_mult = UpgradeManager.get_hp_multiplier()
		if hp_mult > 1.0:
			max_health = int(max_health * hp_mult)
			print("[HealthComponent] Erwachende Essenz: max_health = %d (x%.2f)" % [max_health, hp_mult])

	_base_max_health = max_health
	current_health = max_health

	# Create invulnerability timer
	invulnerability_timer = Timer.new()
	invulnerability_timer.one_shot = true
	invulnerability_timer.timeout.connect(_on_invulnerability_timeout)
	add_child(invulnerability_timer)

	# Connect to block signal
	EventBus.attack_blocked.connect(_on_attack_blocked)

	# Connect to perfect parry signal (grants brief invulnerability)
	EventBus.perfect_parry_executed.connect(_on_perfect_parry)

	# Emit initial health
	health_changed.emit(current_health, max_health)


# ============ HEALTH MANAGEMENT ============
func take_damage(damage: int) -> bool:
	"""
	Applies damage to health. Returns true if damage was applied.
	"""
	if is_invulnerable or current_health <= 0:
		return false

	# Apply block damage reduction if active
	var final_damage = damage
	if block_active:
		final_damage = int(damage * (1.0 - block_reduction))
		print("[HealthComponent] Blocked! Reduced damage: %d → %d (%.0f%% reduction)" % [damage, final_damage, block_reduction * 100])

	# Apply Erinnerung der Voch Numta damage reduction (player only)
	if (owner is Murum or owner is Lythrun) and UpgradeManager:
		var dr = UpgradeManager.get_damage_reduction()
		if dr > 0.0:
			final_damage = int(final_damage * (1.0 - dr))
			print("[HealthComponent] Voch Numta: damage reduced to %d (%.0f%% DR)" % [final_damage, dr * 100])

	current_health = max(0, current_health - final_damage)

	# Play hurt SFX
	AudioManager.play_sfx("player_hurt", 0.1)

	# Emit signals
	damage_taken.emit(final_damage)
	health_changed.emit(current_health, max_health)

	# ========== REBOUND RESET (Commit 018) ==========
	# Notify parry system that player took damage (resets parry counter)
	var parry_system = owner.get_node_or_null("CombatSystem/ParryBlockSystem")
	if parry_system and parry_system.has_method("_on_player_damaged"):
		parry_system._on_player_damaged(final_damage, null)

	# Start invulnerability
	if invulnerability_duration > 0.0:
		start_invulnerability()

	# Check if health depleted
	if current_health <= 0:
		AudioManager.play_sfx("player_death")
		health_depleted.emit()

	return true


func heal(amount: int) -> void:
	"""Restores health by the given amount"""
	if current_health >= max_health:
		return

	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)


func apply_run_bonus_hp(bonus: int) -> void:
	"""Applies run-volatile bonus HP (increases max_health, heals the difference)"""
	var old_max: int = max_health
	_run_bonus_hp = bonus
	max_health = _base_max_health + _run_bonus_hp
	if max_health > old_max:
		current_health += (max_health - old_max)
	else:
		current_health = mini(current_health, max_health)
	health_changed.emit(current_health, max_health)


func reset_health() -> void:
	"""Resets health to maximum"""
	current_health = max_health
	is_invulnerable = false
	if invulnerability_timer.time_left > 0:
		invulnerability_timer.stop()
	health_changed.emit(current_health, max_health)


# ============ INVULNERABILITY ============
func start_invulnerability() -> void:
	"""Starts the invulnerability period"""
	is_invulnerable = true
	invulnerability_timer.start(invulnerability_duration)
	invulnerability_started.emit()


func _on_invulnerability_timeout() -> void:
	"""Called when invulnerability period ends"""
	is_invulnerable = false
	invulnerability_ended.emit()


# ============ GETTERS ============
func get_health_percentage() -> float:
	"""Returns current health as a percentage (0.0 to 1.0)"""
	return float(current_health) / float(max_health)


func is_alive() -> bool:
	"""Returns true if entity has health remaining"""
	return current_health > 0


# ============ BLOCK HANDLING ============
func _on_attack_blocked(enemy: Node, reduction: float) -> void:
	"""Called when player blocks an attack"""
	block_active = true
	block_reduction = reduction

	# Clear after brief window (next frame)
	await get_tree().create_timer(0.05).timeout
	block_active = false
	block_reduction = 0.0


func _on_perfect_parry(enemy: Node) -> void:
	"""Called when perfect parry is executed - grants brief invulnerability"""
	is_invulnerable = true

	# Erinnerung der Voch Numta level 2: extended perfect block immunity
	var immunity_duration: float = 0.1
	if (owner is Murum or owner is Lythrun) and UpgradeManager and UpgradeManager.has_perfect_block_immunity():
		immunity_duration = 0.5
		print("[HealthComponent] Voch Numta: extended perfect block immunity (0.5s)")
	else:
		print("[HealthComponent] Perfect parry invulnerability activated!")

	await get_tree().create_timer(immunity_duration).timeout
	is_invulnerable = false
