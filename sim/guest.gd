class_name Guest
extends RefCounted
## Un huésped: la parte "de hotel" de una persona. Su cuerpo es un Agent (que es quien camina);
## el Guest guarda en qué punto del ciclo de estancia está. Lo mueve GuestRegistry.

enum State {
	ARRIVING, ## Aparece en la entrada y camina a su puesto en la recepción.
	QUEUED, ## Esperando su turno de check-in (en un puesto de la recepción).
	CHECKING_IN, ## Haciendo el check-in (de uno en uno).
	WAITING_ROOM, ## Ya registrado, pero sin dormitorio libre: espera.
	GOING_TO_ROOM, ## Camina hacia su dormitorio.
	STAYING, ## Alojado en su dormitorio.
	LEAVING, ## Camina hacia la entrada para irse.
}

var id: int
var agent_id: int
var level: int
var state: State = State.ARRIVING
## Número de llegada: manda en el orden de la cola.
var ticket: int = 0
## Entrada por la que llegó y por la que se irá.
var entrance_cell: Vector2i = Vector2i.ZERO
## Recepción en la que hace el check-in (id de habitación).
var reception_room_id: int = 0
## Dormitorio asignado (id de habitación; 0 = ninguno).
var room_id: int = 0
## Celda a la que se dirige ahora (puesto de la cola, dormitorio o entrada); solo vale si
## `has_target`.
var target_cell: Vector2i = Vector2i.ZERO
var has_target: bool = false
## Minutos de juego esperando sin que le atiendan ni le den habitación (su paciencia).
var waited_minutes: float = 0.0
## Minutos de juego que lleva sin poder avanzar porque no hay camino.
var blocked_minutes: float = 0.0
## Minutos que quedan de check-in o de estancia.
var timer_minutes: float = 0.0
## true si se va sin haber sido alojado (se cansó de esperar o perdió su habitación).
var left_unhappy: bool = false


func _init(p_id: int, p_agent_id: int, p_level: int) -> void:
	id = p_id
	agent_id = p_agent_id
	level = p_level
