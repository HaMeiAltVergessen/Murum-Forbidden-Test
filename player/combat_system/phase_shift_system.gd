extends Node
## Phase-Shift ability system extracted from lythrun_player.gd
## 1-hit armor ultimate that absorbs the next incoming damage
class_name PhaseShiftSystem

# ============ PHASE-SHIFT (COMMIT 019.5) ============
const PHASE_SHIFT_MANA_COST: int = 60
const PHASE_SHIFT_DURATION: float = 5.0
const PHASE_SHIFT_COOLDOWN: float = 12.0  # COMMIT 024: Reduced from 15.0s (more frequent use)

var phase_shift_active: bool = false
var phase_shift_cooldown_active: bool = false
var phase_shift_armor: bool = false
var phase_shift_flicker_tween = null

# Player reference (set in _ready)
var player = null

func _ready() -> void:
	player = get_parent()

# ============ PUBLIC API ============

func activate() -> void:
	"""Activate the phase shift ability"""
	phase_shift()

func is_active() -> bool:
	return phase_shift_active

func on_damage_received() -> bool:
	"""Check if phase-shift armor absorbs damage. Returns true if damage was absorbed."""
	if phase_shift_armor:
		print("[Phase-Shift] 1-Hit absorbed!")

		phase_shift_armor = false
		phase_shift_active = false

		# VFX
		spawn_phase_shift_absorb_vfx()

		# Audio
		if AudioManager and AudioManager.has_method("play_sfx"):
			AudioManager.play_sfx("phase_shift_absorb")

		# Damage absorbed
		return true

	# Not absorbed
	return false

# ============ CORE FUNCTIONS ============

func phase_shift() -> void:
	"""1-hit armor ultimate"""
	if player.current_mana < PHASE_SHIFT_MANA_COST:
		print("[Phase-Shift] Not enough mana!")
		return

	if phase_shift_active or phase_shift_cooldown_active:
		return

	# Consume mana
	player.consume_mana(PHASE_SHIFT_MANA_COST)

	phase_shift_active = true
	phase_shift_armor = true
	phase_shift_cooldown_active = true

	print("[Phase-Shift] Activated! 1-Hit Armor")

	# Visual: Semi-transparent
	var original_modulate = player.sprite.modulate if player.sprite else Color.WHITE
	if player.sprite:
		player.sprite.modulate.a = 0.5

	# Flicker effect
	start_phase_shift_flicker()

	# Audio
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("phase_shift_activate")

	# Duration or until hit - FIXED: Use proper time tracking
	var start_time = Time.get_ticks_msec() / 1000.0
	while (Time.get_ticks_msec() / 1000.0 - start_time) < PHASE_SHIFT_DURATION and phase_shift_armor:
		await get_tree().process_frame

	# Deactivate
	phase_shift_active = false
	phase_shift_armor = false
	if player.sprite:
		player.sprite.modulate = original_modulate
	stop_phase_shift_flicker()

	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("phase_shift_deactivate")

	# Cooldown
	await get_tree().create_timer(PHASE_SHIFT_COOLDOWN).timeout
	if is_instance_valid(player):
		phase_shift_cooldown_active = false
		print("[Phase-Shift] Cooldown complete")

func start_phase_shift_flicker() -> void:
	"""Start flicker effect"""
	if not player.sprite:
		return

	phase_shift_flicker_tween = player.create_tween()
	phase_shift_flicker_tween.set_loops()
	phase_shift_flicker_tween.tween_property(player.sprite, "modulate:a", 0.8, 0.3)
	phase_shift_flicker_tween.tween_property(player.sprite, "modulate:a", 0.5, 0.3)

func stop_phase_shift_flicker() -> void:
	"""Stop flicker effect"""
	if phase_shift_flicker_tween:
		phase_shift_flicker_tween.kill()
		phase_shift_flicker_tween = null

	# COMMIT 024: Reset opacity to prevent stuck transparency
	if player.sprite:
		player.sprite.modulate.a = 1.0

# ============ VFX ============

func spawn_phase_shift_absorb_vfx() -> void:
	"""Spawn phase-shift absorb VFX"""
	# Screen flash
	var flash = ColorRect.new()
	flash.color = Color(0.5, 0, 0.8)
	flash.modulate.a = 0.8
	if get_tree() and get_tree().current_scene:
		get_tree().current_scene.add_child(flash)
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)

		var tween = player.create_tween()
		tween.tween_property(flash, "modulate:a", 0.0, 0.3)
		tween.tween_callback(flash.queue_free)
