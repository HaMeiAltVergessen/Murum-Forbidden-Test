extends Node
class_name MyrkursEcho

## Myrkurs Echo - Passive Mana Regeneration für Lythrun (P2)
## Shadow-Variante von EchoVonUrgathon
## Testing Mode: Alle 1 Sekunde → 1/8 max Mana

# ============================================================================
# CONSTANTS
# ============================================================================

const HITS_REQUIRED: int = 3
const MANA_RESTORE: int = 9

# Testing mode: Zeit-basiert statt Hit-basiert
const TESTING_MODE: bool = true  # Auf false setzen für Hit-basierte Mechanik
const TESTING_INTERVAL: float = 1.0  # Jede Sekunde
const TESTING_MANA_FRACTION: float = 0.125  # 1/8 des maximalen Manas

# ============================================================================
# STATE
# ============================================================================

var hit_counter: int = 0
var testing_timer: float = 0.0

# Story flag - für Testing auf true
@export var is_unlocked: bool = true

# ============================================================================
# REFERENCES
# ============================================================================

@onready var player: CharacterBody2D = owner
@onready var mana_component: ManaComponent = player.get_node("ManaComponent") if player.has_node("ManaComponent") else null

# ============================================================================
# SIGNALS
# ============================================================================

signal mana_restored(amount: int, trigger: String)  # trigger: "hits" oder "timer"

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	if TESTING_MODE:
		print("[MyrkursEcho] Initialized in TESTING MODE (every %.1fs → 1/8 max mana)" % TESTING_INTERVAL)
	else:
		print("[MyrkursEcho] Initialized (every %d hits → %d mana)" % [HITS_REQUIRED, MANA_RESTORE])

	print("[MyrkursEcho] Unlocked: %s" % is_unlocked)

	# Connect to hit signal nur wenn nicht im Testing Mode
	if not TESTING_MODE and EventBus:
		EventBus.hit_registered.connect(_on_hit_registered)

# ============================================================================
# UPDATE
# ============================================================================

func _process(delta: float) -> void:
	if not is_unlocked:
		return

	# Testing Mode: Timer-basiert
	if TESTING_MODE:
		testing_timer += delta

		if testing_timer >= TESTING_INTERVAL:
			testing_timer = 0.0
			_restore_mana("timer")

# ============================================================================
# HIT DETECTION (nur im normalen Modus)
# ============================================================================

func _on_hit_registered(attacker: Node, target: Node, damage: int) -> void:
	"""Called when any hit is registered - nur wenn nicht im Testing Mode"""

	if not is_unlocked:
		return

	# Nur auf Player-Hits reagieren
	if attacker != player:
		return

	# Hit counter erhöhen
	hit_counter += 1

	print("[MyrkursEcho] Hit %d/%d" % [hit_counter, HITS_REQUIRED])

	# Prüfen ob genug Hits
	if hit_counter >= HITS_REQUIRED:
		hit_counter = 0
		_restore_mana("hits")

# ============================================================================
# MANA RESTORATION
# ============================================================================

func _restore_mana(trigger: String) -> void:
	"""Stellt Mana wieder her"""

	if not mana_component:
		print("[MyrkursEcho] ERROR: No ManaComponent found!")
		return

	# Berechne Mana-Betrag basierend auf Trigger
	var mana_amount: int
	if trigger == "timer":
		# Testing Mode: 1/8 des maximalen Manas
		mana_amount = int(mana_component.max_mana * TESTING_MANA_FRACTION)
	else:
		# Hit-basiert: Fester Betrag
		mana_amount = MANA_RESTORE

	# Mana wiederherstellen
	mana_component.restore_mana(mana_amount)

	var trigger_text = "timer (%.1fs, 1/8 max)" % TESTING_INTERVAL if trigger == "timer" else "%d hits" % HITS_REQUIRED
	print("[MyrkursEcho] ✓ Restored %d mana (trigger: %s)" % [mana_amount, trigger_text])

	# Emit signals
	mana_restored.emit(mana_amount, trigger)
	if EventBus:
		EventBus.echo_mana_gained.emit(mana_amount)

	# Visual feedback
	_spawn_mana_gain_vfx()

# ============================================================================
# VISUAL EFFECTS
# ============================================================================

func _spawn_mana_gain_vfx() -> void:
	"""Spawns visual effect when mana is restored"""

	# TODO: Add shadow-themed mana restoration particle effect
	# Könnte violette Partikel oder Shadow-Text-Popup sein
	pass

# ============================================================================
# UTILITY
# ============================================================================

func get_hit_progress() -> float:
	"""Returns progress to next mana restore (0.0 - 1.0)"""
	if TESTING_MODE:
		return testing_timer / TESTING_INTERVAL
	else:
		return float(hit_counter) / float(HITS_REQUIRED)

func get_hits_remaining() -> int:
	"""Returns hits remaining until next mana restore"""
	return HITS_REQUIRED - hit_counter

func reset_counter() -> void:
	"""Resets hit counter"""
	hit_counter = 0
	testing_timer = 0.0
	print("[MyrkursEcho] Counter reset")
