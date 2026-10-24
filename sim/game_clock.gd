class_name GameClock
extends RefCounted
## Reloj del juego: pausa y velocidades x1, x2, x3. Convierte el tiempo real en tiempo de
## juego; todavía no lo usa ningún otro sistema. No conoce ninguna vista.

enum Speed { PAUSED, X1, X2, X3 }

## La velocidad cambió (incluida la pausa).
signal speed_changed(new_speed: Speed)

const MINUTES_PER_HOUR: int = 60
const HOURS_PER_DAY: int = 24
## Minutos de juego que pasan por cada segundo real a velocidad x1 (un día dura 24 min reales).
const GAME_MINUTES_PER_REAL_SECOND: float = 1.0
## El juego empieza el día 1 a las 08:00.
const START_MINUTES: float = 8.0 * MINUTES_PER_HOUR

var speed: Speed = Speed.X1

## Minutos de juego transcurridos desde el día 1 a las 00:00.
var total_minutes: float = START_MINUTES

var _speed_before_pause: Speed = Speed.X1


## Multiplicador de tiempo de una velocidad (0 en pausa).
static func multiplier_of(a_speed: Speed) -> int:
	match a_speed:
		Speed.X1:
			return 1
		Speed.X2:
			return 2
		Speed.X3:
			return 3
		_:
			return 0


func is_paused() -> bool:
	return speed == Speed.PAUSED


func set_speed(new_speed: Speed) -> void:
	if new_speed == speed:
		return
	if new_speed == Speed.PAUSED:
		_speed_before_pause = speed
	speed = new_speed
	speed_changed.emit(speed)


## Pausa si está en marcha; si está en pausa, vuelve a la velocidad anterior.
func toggle_pause() -> void:
	if is_paused():
		set_speed(_speed_before_pause)
	else:
		set_speed(Speed.PAUSED)


## Avanza el reloj con el tiempo real transcurrido. Devuelve los minutos de juego que pasaron.
func tick(real_delta: float) -> float:
	var game_minutes: float = real_delta * GAME_MINUTES_PER_REAL_SECOND * multiplier_of(speed)
	total_minutes += game_minutes
	return game_minutes


## Día actual, empezando en 1.
func get_day() -> int:
	return floori(total_minutes / float(MINUTES_PER_HOUR * HOURS_PER_DAY)) + 1


func get_hour() -> int:
	return floori(total_minutes / float(MINUTES_PER_HOUR)) % HOURS_PER_DAY


func get_minute() -> int:
	return floori(total_minutes) % MINUTES_PER_HOUR


# --- Guardado -----------------------------------------------------------------------------------

func serialize() -> Dictionary:
	return {"total_minutes": SaveReader.float_data(total_minutes), "speed": speed, "speed_before_pause": _speed_before_pause}


func restore(data: Dictionary, reader: SaveReader) -> void:
	total_minutes = reader.read_float(data, "total_minutes", "reloj", 0.0)
	speed = reader.read_enum(data, "speed", "reloj", Speed.size()) as Speed
	_speed_before_pause = reader.read_enum(data, "speed_before_pause", "reloj", Speed.size()) as Speed
