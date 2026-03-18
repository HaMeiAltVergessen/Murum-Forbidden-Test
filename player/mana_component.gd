extends Node
## ManaComponent manages mana resource for abilities
class_name ManaComponent

# ============ CONFIGURATION ============
@export var max_mana: int = 100
@export var regeneration_rate: float = 10  # Mana per second (10 fürs Testen)
@export var regen_delay_after_use: float = 0.2  # Delay before regen starts

# ============ STATE ============
var current_mana: int
var is_in_combat: bool = false
var regen_delay_timer: Timer
var _base_max_mana: int = 0  # max_mana before run bonuses
var _run_bonus_mana: int = 0

# ============ SIGNALS ============
signal mana_changed(new_mana: int, max_mana: int)
signal mana_used(amount: int)
signal mana_depleted()


func _ready() -> void:
	# Apply permanent mana bonus (player only)
	if (owner is Murum or owner is Lythrun) and RunManager:
		var perma_bonus: int = RunManager.get_perma_mana_bonus()
		if perma_bonus > 0:
			max_mana += perma_bonus

	_base_max_mana = max_mana
	current_mana = max_mana

	# Create regen delay timer
	regen_delay_timer = Timer.new()
	regen_delay_timer.one_shot = true
	add_child(regen_delay_timer)

	# Emit initial mana
	mana_changed.emit(current_mana, max_mana)


func _process(delta: float) -> void:
	# Regenerate mana when not in combat and delay has passed
	if not is_in_combat and regen_delay_timer.is_stopped():
		_regenerate_mana(delta)


# ============ MANA MANAGEMENT ============
func use_mana(amount: int) -> bool:
	"""
	Attempts to use mana. Returns true if successful.
	"""
	var final_cost: int = amount

	# Apply resonance mode cost reduction
	var resonance = owner.get_node_or_null("CombatSystem/ResonanceSystem")
	if resonance and resonance.is_mode_active():
		final_cost = ceili(amount * resonance.MANA_COST_REDUCTION)

	if current_mana < final_cost:
		return false

	current_mana -= final_cost
	mana_used.emit(final_cost)
	mana_changed.emit(current_mana, max_mana)

	# Start regeneration delay
	regen_delay_timer.start(regen_delay_after_use)

	if current_mana <= 0:
		mana_depleted.emit()

	return true


func restore_mana(amount: int) -> void:
	"""Restores mana by the given amount"""
	if current_mana >= max_mana:
		return

	current_mana = min(max_mana, current_mana + amount)
	mana_changed.emit(current_mana, max_mana)


func apply_run_bonus_mana(bonus: int) -> void:
	"""Applies run-volatile bonus mana (increases max_mana, restores the difference)"""
	var old_max: int = max_mana
	_run_bonus_mana = bonus
	max_mana = _base_max_mana + _run_bonus_mana
	if max_mana > old_max:
		current_mana += (max_mana - old_max)
	else:
		current_mana = mini(current_mana, max_mana)
	mana_changed.emit(current_mana, max_mana)


func reset_mana() -> void:
	"""Resets mana to maximum"""
	current_mana = max_mana
	mana_changed.emit(current_mana, max_mana)


func _regenerate_mana(delta: float) -> void:
	"""Regenerates mana over time"""
	if current_mana >= max_mana:
		return

	var effective_regen: float = regeneration_rate

	# Apply Urgathons Erbe mana regen bonus (player only)
	if (owner is Murum or owner is Lythrun) and UpgradeManager:
		effective_regen *= UpgradeManager.get_mana_regen_multiplier()

	var regen_amount: float = effective_regen * delta
	current_mana = min(max_mana, current_mana + int(regen_amount))
	mana_changed.emit(current_mana, max_mana)


# ============ COMBAT STATE ============
func set_combat_state(in_combat: bool) -> void:
	"""Sets whether the entity is in combat (affects regeneration)"""
	is_in_combat = in_combat


# ============ GETTERS ============
func has_mana(amount: int) -> bool:
	"""Returns true if entity has enough mana"""
	return current_mana >= amount


func get_mana_percentage() -> float:
	"""Returns current mana as a percentage (0.0 to 1.0)"""
	return float(current_mana) / float(max_mana)
