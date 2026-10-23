class_name HotelFixture
extends RefCounted
## Hotel de prueba para los tests de huéspedes: un vestíbulo de suelo abierto con una entrada, una
## recepción y N dormitorios, todos con su puerta al vestíbulo.
##
##   mapa 30x14, entrada en (1,7), recepción de 4x3 en (8,2) con la puerta al oeste,
##   dormitorios de 3x2 en la fila 9 (x = 3, 8, 13, ...) con la puerta al norte.

const MAP_SIZE: Vector2i = Vector2i(30, 14)
const ENTRANCE: Vector2i = Vector2i(1, 7)
const RECEPTION_RECT: Rect2i = Rect2i(Vector2i(8, 2), Vector2i(4, 3))


static func bedroom_rect(index: int) -> Rect2i:
	return Rect2i(Vector2i(3 + index * 5, 9), Vector2i(3, 2))


## Las llegadas automáticas están desactivadas por defecto: cada test llama a `guests.arrive` a su
## ritmo. Con `auto_arrivals` se activan. Con `economy_rules` el hotel se construye con esas reglas
## (por defecto no cuesta nada, así que el saldo empieza en 0 y no se mueve al construir).
static func build(bedroom_count: int = 2, seed_value: int = 1, auto_arrivals: bool = false,
		economy_rules: EconomyRules = null) -> GameState:
	var state := GameState.new(MAP_SIZE, null, economy_rules)
	state.build.fill_rect_floor(Rect2i(Vector2i.ZERO, MAP_SIZE), 0)
	state.build.build_room(RECEPTION_RECT, 0)
	state.build.place_door(Edge.from_side(Vector2i(8, 3), Edge.Side.WEST), 0)
	for i in range(bedroom_count):
		var rect: Rect2i = bedroom_rect(i)
		state.build.build_room(rect, 0)
		state.build.place_door(Edge.from_side(rect.position, Edge.Side.NORTH), 0)
	state.entrances.add(ENTRANCE, 0)
	state.rooms.set_room_type(reception(state).id, GuestRegistry.RECEPTION_TYPE)
	for i in range(bedroom_count):
		state.rooms.set_room_type(bedroom(state, i).id, GuestRegistry.BEDROOM_TYPE)
	state.guests.set_seed(seed_value)
	state.wander.set_seed(seed_value)
	state.spawner.set_seed(seed_value)
	state.spawner.enabled = auto_arrivals
	return state


static func reception(state: GameState) -> Room:
	return state.rooms.get_room_at(RECEPTION_RECT.position, 0)


static func bedroom(state: GameState, index: int) -> Room:
	return state.rooms.get_room_at(bedroom_rect(index).position, 0)


## Avanza `minutes` minutos de juego a velocidad x1 (pasos de 0,1 s reales = 0,1 min).
static func run(state: GameState, minutes: float) -> void:
	for i in range(roundi(minutes / 0.1)):
		state.tick(0.1)


## Avanza hasta que se cumpla la condición (o se agoten `max_minutes`). Devuelve los minutos
## transcurridos, o -1.0 si no se cumplió.
static func run_until(state: GameState, condition: Callable, max_minutes: float = 200.0) -> float:
	var elapsed: float = 0.0
	while elapsed < max_minutes:
		if condition.call():
			return elapsed
		state.tick(0.1)
		elapsed += 0.1
	return elapsed if condition.call() else -1.0
