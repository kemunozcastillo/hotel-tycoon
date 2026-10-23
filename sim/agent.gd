class_name Agent
extends RefCounted
## Una persona que camina por el edificio (huésped, personal...). Es solo estado: quien lo mueve
## es AgentRegistry. No conoce ninguna vista.

enum State {
	IDLE, ## Quieto, sin destino.
	WALKING, ## Siguiendo una ruta hacia `destination`.
	BLOCKED, ## Tiene destino pero ahora no hay camino; reintenta si el mapa cambia.
}

## Velocidad de paseo por defecto: celdas por minuto de juego (2 celdas por segundo real a x1).
const DEFAULT_SPEED: float = 2.0

var id: int
var level: int
## Posición continua en coordenadas de la cuadrícula: la celda (x, y) tiene su centro en
## (x + 0.5, y + 0.5).
var position: Vector2
var speed: float = DEFAULT_SPEED
var state: State = State.IDLE
## true mientras hay un destino pendiente (WALKING o BLOCKED).
var has_destination: bool = false
var destination: Vector2i = Vector2i.ZERO
## Celdas que quedan por visitar; la primera es el siguiente punto al que se dirige.
var path: Array[Vector2i] = []
## Revisión del mapa con la que se calculó `path` (la usa AgentRegistry para saber si debe
## comprobar que la ruta sigue siendo válida).
var planned_revision: int = -1
## Si el comportamiento de paseo puede mandarlo a pasear cuando está libre.
var wanders: bool = true


func _init(p_id: int, p_level: int, p_position: Vector2) -> void:
	id = p_id
	level = p_level
	position = p_position


## Celda que contiene al agente.
func get_cell() -> Vector2i:
	return Vector2i(floori(position.x), floori(position.y))
