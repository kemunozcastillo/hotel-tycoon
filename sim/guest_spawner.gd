class_name GuestSpawner
extends RefCounted
## Decide cuándo llega el siguiente huésped: cada 15 a 45 minutos de juego, al azar. Solo manda
## llegar; si no se puede (sin entrada, sin recepción operativa, demasiada cola), esa llegada se
## pierde y se espera a la siguiente. Los tiempos son provisionales.

const MIN_INTERVAL_MINUTES: float = 15.0
const MAX_INTERVAL_MINUTES: float = 45.0

## Si es false no llega nadie (útil para pruebas y para pausar la demanda).
var enabled: bool = true
var rng := RandomNumberGenerator.new()

var _guests: GuestRegistry
var _level: int
var _minutes_left: float = 0.0


func _init(guests: GuestRegistry, level: int = 0) -> void:
	_guests = guests
	_level = level
	rng.randomize()
	_schedule_next()


## Fija la semilla del azar y reprograma la próxima llegada (para pruebas reproducibles).
func set_seed(seed_value: int) -> void:
	rng.seed = seed_value
	_schedule_next()


## Minutos de juego que faltan para la próxima llegada.
func get_minutes_until_next() -> float:
	return _minutes_left


func tick(game_minutes: float) -> void:
	if game_minutes <= 0.0 or not enabled:
		return
	_minutes_left -= game_minutes
	if _minutes_left <= 0.0:
		_guests.arrive(_level)
		_schedule_next()


func _schedule_next() -> void:
	_minutes_left = rng.randf_range(MIN_INTERVAL_MINUTES, MAX_INTERVAL_MINUTES)


# --- Guardado -----------------------------------------------------------------------------------

func serialize() -> Dictionary:
	return {"enabled": enabled, "minutes_left": SaveReader.float_data(_minutes_left), "rng": SaveReader.rng_data(rng)}


func restore(data: Dictionary, reader: SaveReader) -> void:
	enabled = reader.read_bool(data, "enabled", "llegadas")
	_minutes_left = reader.read_float(data, "minutes_left", "llegadas", -1.0e9)
	reader.read_rng(data, "rng", "llegadas", rng)
