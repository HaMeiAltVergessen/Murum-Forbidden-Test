extends Node
## MomentumSystem — Tracks momentum value (0-100) for mirror boss fight
## Replaces traditional HP: momentum determines when boss is vulnerable
class_name MomentumSystem

# ============ SIGNALS ============
signal momentum_changed(value: float, state: int)
signal state_changed(new_state: int)
signal max_reached()
signal finisher_window_opened()
signal finisher_window_closed()

# ============ MOMENTUM STATES ============
enum State { RUECKSTAND, GLEICHAUF, UEBERHOLEN, MAX }

const STATE_THRESHOLDS: Dictionary = {
	State.RUECKSTAND: 0.0,
	State.GLEICHAUF: 34.0,
	State.UEBERHOLEN: 67.0,
	State.MAX: 100.0,
}

# ============ MOMENTUM GAINS ============
const GAIN_PERFECT_PARRY: float = 15.0
const GAIN_COMBO_FINISHER: float = 10.0
const GAIN_AIR_COMBO: float = 8.0
const GAIN_DAMAGE_FREE_PER_SEC: float = 2.0
const GAIN_WOLKENBRUCH: float = 5.0
const GAIN_MACHTBRUCH: float = 8.0

# ============ MOMENTUM LOSSES ============
const LOSS_PLAYER_DAMAGED: float = 20.0
const LOSS_OBSTACLE_HIT: float = 10.0
const LOSS_BEHIND_CAMERA_PER_SEC: float = 3.0

# ============ FINISHER WINDOW ============
const FINISHER_WINDOW_DURATION: float = 5.0

# ============ STATE ============
var momentum: float = 0.0
var current_state: int = State.RUECKSTAND
var controller: Node = null  # MirrorController reference
var _damage_free_timer: float = 0.0
var _finisher_window_active: bool = false
var _finisher_window_timer: float = 0.0
var _was_damaged_recently: bool = false


func _ready() -> void:
	# Connect to EventBus signals
	EventBus.perfect_parry_executed.connect(_on_perfect_parry)
	EventBus.combo_finisher_executed.connect(_on_combo_finisher)
	EventBus.air_combo_ended.connect(_on_air_combo_ended)
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.wolkenbruch_impact.connect(_on_wolkenbruch_impact)
	EventBus.machtbruch_released.connect(_on_machtbruch_released)


func _process(delta: float) -> void:
	if not controller or not controller.is_fight_active:
		return

	# Damage-free bonus
	if not _was_damaged_recently:
		_damage_free_timer += delta
		if _damage_free_timer >= 1.0:
			_damage_free_timer -= 1.0
			add_momentum(GAIN_DAMAGE_FREE_PER_SEC)

	# Behind camera penalty
	_check_behind_camera(delta)

	# Finisher window: no time limit — stays open until player lands a finisher


# ============ MOMENTUM MODIFICATION ============
func add_momentum(amount: float) -> void:
	if _finisher_window_active:
		return  # Don't change during finisher window

	var old_momentum: float = momentum
	momentum = clampf(momentum + amount, 0.0, 100.0)

	if momentum != old_momentum:
		_update_state()
		momentum_changed.emit(momentum, current_state)

	# Check MAX
	if momentum >= 100.0 and old_momentum < 100.0:
		_open_finisher_window()


func reduce_momentum(amount: float) -> void:
	if _finisher_window_active:
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


# ============ FINISHER WINDOW ============
func _open_finisher_window() -> void:
	if _finisher_window_active:
		return

	print("[MomentumSystem] FINISHER WINDOW OPEN — kein Zeitlimit!")
	_finisher_window_active = true
	_finisher_window_timer = 0.0  # Unused — no time limit
	max_reached.emit()
	finisher_window_opened.emit()

	# Make boss vulnerable
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

	# Boss returns to running
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

	# Reset momentum after finisher
	momentum = 0.0
	_update_state()
	momentum_changed.emit(momentum, current_state)

	# Notify controller
	if controller:
		controller.on_finisher_landed()


# ============ EVENT HANDLERS ============
func _on_perfect_parry(_enemy: Node) -> void:
	if not controller or not controller.is_fight_active:
		return
	add_momentum(GAIN_PERFECT_PARRY)
	print("[MomentumSystem] +%.0f Momentum (Perfect Parry) → %.0f" % [GAIN_PERFECT_PARRY, momentum])


func _on_combo_finisher(_combo_count: int) -> void:
	if not controller or not controller.is_fight_active:
		return

	# Check if finisher window is open — this IS the finisher
	if _finisher_window_active:
		on_finisher_landed()
	else:
		add_momentum(GAIN_COMBO_FINISHER)
		print("[MomentumSystem] +%.0f Momentum (Combo Finisher) → %.0f" % [GAIN_COMBO_FINISHER, momentum])


func _on_air_combo_ended(_final_count: int) -> void:
	if not controller or not controller.is_fight_active:
		return
	add_momentum(GAIN_AIR_COMBO)


func _on_player_damaged(_damage: int, _source: Node) -> void:
	if not controller or not controller.is_fight_active:
		return
	reduce_momentum(LOSS_PLAYER_DAMAGED)
	_was_damaged_recently = true
	_damage_free_timer = 0.0
	# Reset damage flag after 3 seconds
	get_tree().create_timer(3.0).timeout.connect(func(): _was_damaged_recently = false)
	print("[MomentumSystem] -%.0f Momentum (Damaged) → %.0f" % [LOSS_PLAYER_DAMAGED, momentum])


func _on_wolkenbruch_impact(_powered: bool) -> void:
	if not controller or not controller.is_fight_active:
		return
	add_momentum(GAIN_WOLKENBRUCH)


func _on_machtbruch_released(_tier: int, _damage: int, _radius: float) -> void:
	if not controller or not controller.is_fight_active:
		return

	# Check if finisher window is open — Machtbruch counts as finisher
	if _finisher_window_active:
		on_finisher_landed()
	else:
		add_momentum(GAIN_MACHTBRUCH)


func _check_behind_camera(delta: float) -> void:
	var player: Node2D = GameManager.player if GameManager else null
	if not player or not is_instance_valid(player):
		return

	if not controller or not controller.runner_camera:
		return

	var cam_left: float = controller.runner_camera.get_left_edge()
	if player.global_position.x < cam_left + 200.0:  # Within danger zone
		reduce_momentum(LOSS_BEHIND_CAMERA_PER_SEC * delta)


func on_obstacle_hit() -> void:
	"""Call when player hits an obstacle"""
	reduce_momentum(LOSS_OBSTACLE_HIT)
