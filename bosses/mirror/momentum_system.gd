extends Node
## MomentumSystem — Dual mode: Momentum (Phase 1) OR Knockdown-Meter (Phase 2+3)
## Phase 1: momentum determines when boss is vulnerable (finisher windows)
## Phase 2+3: knockdown meter triggers knockdown states for full-damage windows
class_name MomentumSystem

# ============ SIGNALS ============
signal momentum_changed(value: float, state: int)
signal state_changed(new_state: int)
signal max_reached()
signal finisher_window_opened()
signal finisher_window_closed()
signal knockdown_triggered(count: int)
signal knockdown_ended(count: int)
signal knockdown_meter_changed(value: float)

# ============ MOMENTUM STATES ============
enum State { RUECKSTAND, GLEICHAUF, UEBERHOLEN, MAX }

const STATE_THRESHOLDS: Dictionary = {
	State.RUECKSTAND: 0.0,
	State.GLEICHAUF: 34.0,
	State.UEBERHOLEN: 67.0,
	State.MAX: 100.0,
}

# ============ MOMENTUM GAINS (Phase 1) ============
const GAIN_PERFECT_PARRY: float = 22.0
const GAIN_COMBO_FINISHER: float = 15.0
const GAIN_AIR_COMBO: float = 12.0
const GAIN_DAMAGE_FREE_PER_SEC: float = 3.0
const GAIN_WOLKENBRUCH: float = 8.0
const GAIN_MACHTBRUCH: float = 12.0

# ============ MOMENTUM LOSSES (Phase 1) ============
const LOSS_PLAYER_DAMAGED: float = 20.0
const LOSS_OBSTACLE_HIT: float = 10.0
const LOSS_BEHIND_CAMERA_PER_SEC: float = 3.0

# ============ KNOCKDOWN GAINS (Phase 2+3) ============
const KD_GAIN_PER_DAMAGE_POINT: float = 0.5
const KD_GAIN_PERFECT_PARRY: float = 15.0
const KD_GAIN_COMBO_FINISHER: float = 10.0
const KD_GAIN_AIR_COMBO: float = 8.0
const KD_GAIN_WOLKENBRUCH: float = 5.0
const KD_GAIN_MACHTBRUCH: float = 8.0

# ============ KNOCKDOWN CONFIG ============
const KNOCKDOWN_DURATION: float = 4.0

# ============ FINISHER WINDOW ============
const FINISHER_WINDOW_DURATION: float = 5.0

# ============ STATE ============
var momentum: float = 0.0
var current_state: int = State.RUECKSTAND
var controller: Node = null
var mode: String = "momentum"  # "momentum" or "knockdown"
var knockdown_meter: float = 0.0
var knockdown_count: int = 0
var _knockdown_active: bool = false
var _knockdown_timer: float = 0.0
var _damage_free_timer: float = 0.0
var _finisher_window_active: bool = false
var _finisher_window_timer: float = 0.0
var _was_damaged_recently: bool = false


func _ready() -> void:
	EventBus.perfect_parry_executed.connect(_on_perfect_parry)
	EventBus.combo_finisher_executed.connect(_on_combo_finisher)
	EventBus.air_combo_ended.connect(_on_air_combo_ended)
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.wolkenbruch_impact.connect(_on_wolkenbruch_impact)
	EventBus.machtbruch_released.connect(_on_machtbruch_released)
	EventBus.hit_registered.connect(_on_hit_registered)


func _process(delta: float) -> void:
	if not controller or not controller.is_fight_active:
		return

	if mode == "momentum":
		_process_momentum(delta)
	else:
		_process_knockdown(delta)


func _process_momentum(delta: float) -> void:
	# Damage-free bonus
	if not _was_damaged_recently:
		_damage_free_timer += delta
		if _damage_free_timer >= 1.0:
			_damage_free_timer -= 1.0
			add_momentum(GAIN_DAMAGE_FREE_PER_SEC)

	# Behind camera penalty
	_check_behind_camera(delta)


func _process_knockdown(_delta: float) -> void:
	# Knockdown timer is handled by MirrorBoss._process_knockdown()
	# which calls exit_knockdown_state() → controller.on_knockdown_ended() → _end_knockdown()
	pass


# ============ MODE SWITCHING ============
func switch_to_knockdown_mode() -> void:
	"""Switch from momentum to knockdown-meter mode (Phase 2+3)"""
	print("[MomentumSystem] Switching to KNOCKDOWN mode")
	mode = "knockdown"
	knockdown_meter = 0.0
	knockdown_count = 0
	_knockdown_active = false
	_finisher_window_active = false
	momentum = 0.0


# ============ MOMENTUM MODIFICATION (Phase 1) ============
func add_momentum(amount: float) -> void:
	if mode != "momentum" or _finisher_window_active:
		return

	var old_momentum: float = momentum
	momentum = clampf(momentum + amount, 0.0, 100.0)

	if momentum != old_momentum:
		_update_state()
		momentum_changed.emit(momentum, current_state)

	if momentum >= 100.0 and old_momentum < 100.0:
		_open_finisher_window()


func reduce_momentum(amount: float) -> void:
	if mode != "momentum" or _finisher_window_active:
		return

	var old_momentum: float = momentum
	momentum = clampf(momentum - amount, 0.0, 100.0)

	if momentum != old_momentum:
		_update_state()
		momentum_changed.emit(momentum, current_state)


func _update_state() -> void:
	var new_state: int = State.RUECKSTAND
	if momentum >= 100.0:
		new_state = State.MAX
	elif momentum >= 67.0:
		new_state = State.UEBERHOLEN
	elif momentum >= 34.0:
		new_state = State.GLEICHAUF

	if new_state != current_state:
		current_state = new_state
		state_changed.emit(current_state)


# ============ KNOCKDOWN METER (Phase 2+3) ============
func add_knockdown_meter(amount: float) -> void:
	if mode != "knockdown" or _knockdown_active:
		return

	# Scale gains with knockdown count (gets harder each time)
	var phase_multiplier: float = 1.0 + knockdown_count * 0.15
	var scaled_amount: float = amount / phase_multiplier

	var old_meter: float = knockdown_meter
	knockdown_meter = clampf(knockdown_meter + scaled_amount, 0.0, 100.0)

	if knockdown_meter != old_meter:
		knockdown_meter_changed.emit(knockdown_meter)

	if knockdown_meter >= 100.0 and old_meter < 100.0:
		_trigger_knockdown()


func _trigger_knockdown() -> void:
	if _knockdown_active:
		return

	knockdown_count += 1
	_knockdown_active = true
	_knockdown_timer = KNOCKDOWN_DURATION
	print("[MomentumSystem] KNOCKDOWN #%d triggered!" % knockdown_count)
	knockdown_triggered.emit(knockdown_count)

	# Notify controller
	if controller and controller.has_method("on_knockdown_triggered"):
		controller.on_knockdown_triggered(knockdown_count)


func _end_knockdown() -> void:
	if not _knockdown_active:
		return

	print("[MomentumSystem] Knockdown #%d ended" % knockdown_count)
	_knockdown_active = false
	_knockdown_timer = 0.0
	knockdown_meter = 0.0
	knockdown_meter_changed.emit(knockdown_meter)
	knockdown_ended.emit(knockdown_count)


func is_knockdown_active() -> bool:
	return _knockdown_active


func get_knockdown_time_remaining() -> float:
	return _knockdown_timer if _knockdown_active else 0.0


# ============ FINISHER WINDOW (Phase 1) ============
func _open_finisher_window() -> void:
	if _finisher_window_active:
		return

	print("[MomentumSystem] FINISHER WINDOW OPEN — kein Zeitlimit!")
	_finisher_window_active = true
	_finisher_window_timer = 0.0
	max_reached.emit()
	finisher_window_opened.emit()

	if controller and controller.mirror_boss:
		if controller.mirror_boss.has_method("enter_vulnerable_state"):
			controller.mirror_boss.enter_vulnerable_state()


func _close_finisher_window() -> void:
	if not _finisher_window_active:
		return

	print("[MomentumSystem] Finisher window MISSED — momentum drops to 50")
	_finisher_window_active = false
	_finisher_window_timer = 0.0
	momentum = 50.0
	_update_state()
	momentum_changed.emit(momentum, current_state)
	finisher_window_closed.emit()

	if controller and controller.mirror_boss:
		if controller.mirror_boss.has_method("exit_vulnerable_state"):
			controller.mirror_boss.exit_vulnerable_state()


func is_finisher_window_open() -> bool:
	return _finisher_window_active


func on_finisher_landed() -> void:
	"""Called when player lands a finisher hit during the window"""
	if not _finisher_window_active:
		return

	print("[MomentumSystem] FINISHER LANDED!")
	_finisher_window_active = false
	_finisher_window_timer = 0.0

	momentum = 0.0
	_update_state()
	momentum_changed.emit(momentum, current_state)

	if controller:
		controller.on_finisher_landed()


# ============ EVENT HANDLERS ============
func _on_perfect_parry(_enemy: Node) -> void:
	if not controller or not controller.is_fight_active:
		return
	if mode == "momentum":
		add_momentum(GAIN_PERFECT_PARRY)
		print("[MomentumSystem] +%.0f Momentum (Perfect Parry) → %.0f" % [GAIN_PERFECT_PARRY, momentum])
	else:
		add_knockdown_meter(KD_GAIN_PERFECT_PARRY)


func _on_combo_finisher(_combo_count: int) -> void:
	if not controller or not controller.is_fight_active:
		return

	if mode == "momentum":
		if _finisher_window_active:
			on_finisher_landed()
		else:
			add_momentum(GAIN_COMBO_FINISHER)
			print("[MomentumSystem] +%.0f Momentum (Combo Finisher) → %.0f" % [GAIN_COMBO_FINISHER, momentum])
	else:
		add_knockdown_meter(KD_GAIN_COMBO_FINISHER)


func _on_air_combo_ended(_final_count: int) -> void:
	if not controller or not controller.is_fight_active:
		return
	if mode == "momentum":
		add_momentum(GAIN_AIR_COMBO)
	else:
		add_knockdown_meter(KD_GAIN_AIR_COMBO)


func _on_player_damaged(_damage: int, _source: Node) -> void:
	if not controller or not controller.is_fight_active:
		return
	if mode == "momentum":
		reduce_momentum(LOSS_PLAYER_DAMAGED)
		_was_damaged_recently = true
		_damage_free_timer = 0.0
		get_tree().create_timer(3.0).timeout.connect(func(): _was_damaged_recently = false)
		print("[MomentumSystem] -%.0f Momentum (Damaged) → %.0f" % [LOSS_PLAYER_DAMAGED, momentum])
	# Knockdown mode: no meter loss on player damage


func _on_wolkenbruch_impact(_powered: bool) -> void:
	if not controller or not controller.is_fight_active:
		return
	if mode == "momentum":
		add_momentum(GAIN_WOLKENBRUCH)
	else:
		add_knockdown_meter(KD_GAIN_WOLKENBRUCH)


func _on_machtbruch_released(_tier: int, _damage: int, _radius: float) -> void:
	if not controller or not controller.is_fight_active:
		return

	if mode == "momentum":
		if _finisher_window_active:
			on_finisher_landed()
		else:
			add_momentum(GAIN_MACHTBRUCH)
	else:
		add_knockdown_meter(KD_GAIN_MACHTBRUCH)


func _on_hit_registered(_attacker: Node, target: Node, damage: int) -> void:
	"""Listen for damage dealt to boss — feeds knockdown meter in Phase 2+3"""
	if mode != "knockdown":
		return
	if not controller or not controller.is_fight_active:
		return
	# Only count hits on the mirror boss
	if target == controller.mirror_boss:
		add_knockdown_meter(damage * KD_GAIN_PER_DAMAGE_POINT)


func _check_behind_camera(delta: float) -> void:
	var player: Node2D = GameManager.player if GameManager else null
	if not player or not is_instance_valid(player):
		return

	if not controller or not controller.runner_camera:
		return

	var cam_left: float = controller.runner_camera.get_left_edge()
	if player.global_position.x < cam_left + 200.0:
		reduce_momentum(LOSS_BEHIND_CAMERA_PER_SEC * delta)


func on_obstacle_hit() -> void:
	if mode == "momentum":
		reduce_momentum(LOSS_OBSTACLE_HIT)
