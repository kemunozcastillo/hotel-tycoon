class_name GuestRegistry
extends RefCounted
## Gobierna el ciclo de estancia de los huéspedes: llegada por una entrada, cola y check-in en una
## recepción, asignación de un dormitorio operativo, estancia y salida. Cada huésped usa un Agent
## como cuerpo (le ordena adónde ir y observa cuándo llega). Todos los tiempos son minutos de
## juego, así que el reloj manda.
##
## Asignación: al terminar el check-in se elige el dormitorio libre y operativo más cercano (por
## coste de ruta desde donde está el huésped) entre los alcanzables, y se reserva en `occupancy`
## en ese mismo instante, así que dos huéspedes nunca reciben el mismo. Si no hay ninguno, el
## huésped espera y se reintenta cada vez que cambia el mapa, las habitaciones o la ocupación.
## Si su habitación deja de ser válida (derribada, sin tipo, no operativa), la pierde y vuelve a
## esperar con la paciencia renovada.
##
## Los números de abajo son provisionales: cuando haya personal y economía se ajustarán.

## Ids de los tipos de habitación (data/room_types.json) que el hotel necesita.
const BEDROOM_TYPE: StringName = &"bedroom"
const RECEPTION_TYPE: StringName = &"reception"

## Duración del check-in (de uno en uno).
const CHECK_IN_MINUTES: float = 3.0
## Cuánto espera un huésped, desde que llega hasta que le dan habitación, antes de marcharse.
const PATIENCE_MINUTES: float = 60.0
## Cuánto aguanta sin camino (puerta cerrada...) antes de rendirse al irse.
const BLOCKED_PATIENCE_MINUTES: float = 30.0
## Máximo de huéspedes esperando a la vez (llegando, en cola, en check-in o sin habitación).
const MAX_WAITING: int = 4
## Duración de la estancia, al azar entre estos dos valores (2 a 6 horas de juego).
const STAY_MIN_MINUTES: float = 120.0
const STAY_MAX_MINUTES: float = 360.0

## Estados en los que el huésped ocupa un puesto en la línea de la recepción.
const LINE_STATES: Array[Guest.State] = [
	Guest.State.ARRIVING, Guest.State.QUEUED, Guest.State.CHECKING_IN, Guest.State.WAITING_ROOM,
]

## Llegó un huésped nuevo.
signal guest_arrived(guest: Guest)
## Un huésped cambió de estado.
signal guest_state_changed(guest: Guest)
## A un huésped se le asignó dormitorio (acaba de terminar el check-in o recuperó uno).
signal guest_checked_in(guest: Guest)
## Un huésped terminó su estancia (se va contento): es el momento de cobrarle el resto.
signal guest_stay_completed(guest: Guest)
## Un huésped pierde su dormitorio antes de terminar la estancia (derribado, sin tipo, no operativo
## o inalcanzable). Se emite con la habitación todavía asignada.
signal guest_room_lost(guest: Guest)
## Un huésped se fue (el objeto conserva su último estado y `left_unhappy`).
signal guest_left(guest: Guest)

var rng := RandomNumberGenerator.new()
var occupancy := RoomOccupancy.new()

var total_arrived: int = 0
var total_checked_in: int = 0
var total_left_happy: int = 0
var total_left_unhappy: int = 0

var _grid: GridMap2D
var _agents: AgentRegistry
var _rooms: RoomRegistry
var _entrances: EntrancePoints
var _guests: Dictionary = {} # id -> Guest
var _by_agent: Dictionary = {} # id del agente -> id del huésped
var _next_id: int = 1
var _next_ticket: int = 1
var _dirty_lines: Dictionary = {} # id de recepción -> true
# Hay que reintentar la asignación de los que esperan habitación (algo cambió).
var _assign_dirty: bool = true
var _seen_revision: int = -1


func _init(grid: GridMap2D, agents: AgentRegistry, rooms: RoomRegistry, entrances: EntrancePoints) -> void:
	_grid = grid
	_agents = agents
	_rooms = rooms
	_entrances = entrances
	rng.randomize()
	agents.agent_removed.connect(_on_agent_removed)
	rooms.room_created.connect(_on_rooms_changed)
	rooms.room_changed.connect(_on_rooms_changed)
	rooms.room_removed.connect(_on_rooms_changed)
	rooms.room_type_changed.connect(_on_rooms_changed)
	occupancy.occupancy_changed.connect(_mark_assignment_dirty)


## Fija la semilla del azar (para pruebas reproducibles).
func set_seed(seed_value: int) -> void:
	rng.seed = seed_value


# --- Consultas -----------------------------------------------------------------------------

## Todos los huéspedes, ordenados por id.
func get_guests() -> Array[Guest]:
	var result: Array[Guest] = []
	for guest: Guest in _guests.values():
		result.append(guest)
	result.sort_custom(func(a: Guest, b: Guest) -> bool: return a.id < b.id)
	return result


func get_guest(id: int) -> Guest:
	return _guests.get(id) as Guest


## El huésped que usa ese agente como cuerpo, o null si el agente no es un huésped.
func get_guest_by_agent(agent_id: int) -> Guest:
	return _guests.get(_by_agent.get(agent_id, 0)) as Guest


func get_guest_count() -> int:
	return _guests.size()


func count_in_state(state: Guest.State) -> int:
	var count: int = 0
	for guest: Guest in _guests.values():
		if guest.state == state:
			count += 1
	return count


## true si hay alguna recepción operativa en el nivel (sin ella no pueden llegar huéspedes).
func has_operational_reception(level: int) -> bool:
	for room: Room in _rooms.get_rooms(level):
		if room.type_id == RECEPTION_TYPE and _rooms.get_status(room).is_operational():
			return true
	return false


## Dormitorios operativos del nivel y cuántos de ellos están libres.
func count_bedrooms(level: int) -> Vector2i:
	var total: int = 0
	var free: int = 0
	for room: Room in _rooms.get_rooms(level):
		if _is_usable_bedroom(room):
			total += 1
			if occupancy.is_free(room.id):
				free += 1
	return Vector2i(free, total)


## Huéspedes que esperan algo en ese nivel (llegando, en cola, en check-in o sin habitación).
func get_waiting_count(level: int) -> int:
	var count: int = 0
	for guest: Guest in _guests.values():
		if guest.level == level and LINE_STATES.has(guest.state):
			count += 1
	return count


# --- Llegada ---------------------------------------------------------------------------------

## Hace llegar a un huésped por una entrada válida al azar. Devuelve null si no se puede: no hay
## entrada válida, no hay recepción operativa y alcanzable desde ella, o ya hay demasiados
## huéspedes esperando.
func arrive(level: int) -> Guest:
	if get_waiting_count(level) >= MAX_WAITING:
		return null
	var entrances: Array[Vector2i] = _entrances.get_valid(level)
	if entrances.is_empty():
		return null
	var entrance: Vector2i = entrances[rng.randi_range(0, entrances.size() - 1)]
	var reception: Room = _pick_reception(entrance, level)
	if reception == null:
		return null
	var agent: Agent = _agents.spawn(entrance, level)
	if agent == null:
		return null
	agent.wanders = false

	var guest := Guest.new(_next_id, agent.id, level)
	_next_id += 1
	guest.ticket = _next_ticket
	_next_ticket += 1
	guest.entrance_cell = entrance
	guest.reception_room_id = reception.id
	_guests[guest.id] = guest
	_by_agent[agent.id] = guest.id
	total_arrived += 1
	guest_arrived.emit(guest)
	_dirty_lines[reception.id] = true
	_flush_lines()
	return guest


## La recepción operativa más cercana (por coste de ruta) a la entrada, o null.
func _pick_reception(entrance: Vector2i, level: int) -> Room:
	var costs: Dictionary = Pathfinder.reachable_costs(_grid, level, entrance)
	var best: Room = null
	var best_cost: float = INF
	for room: Room in _rooms.get_rooms(level):
		if room.type_id != RECEPTION_TYPE or not _rooms.get_status(room).is_operational():
			continue
		for cell: Vector2i in room.cells:
			if costs.has(cell) and float(costs[cell]) < best_cost:
				best_cost = costs[cell]
				best = room
	return best


# --- Avance --------------------------------------------------------------------------------

## Avanza a los huéspedes con los minutos de juego transcurridos.
func tick(game_minutes: float) -> void:
	if game_minutes <= 0.0:
		return
	for guest: Guest in get_guests():
		var agent: Agent = _agents.get_agent(guest.agent_id)
		if agent == null:
			continue
		guest.blocked_minutes = guest.blocked_minutes + game_minutes if agent.state == Agent.State.BLOCKED else 0.0
		match guest.state:
			Guest.State.ARRIVING:
				_wait(guest, game_minutes)
				if guest.state == Guest.State.ARRIVING and _is_at_target(guest, agent):
					_set_state(guest, Guest.State.QUEUED)
			Guest.State.QUEUED, Guest.State.WAITING_ROOM:
				_wait(guest, game_minutes)
			Guest.State.CHECKING_IN:
				_wait(guest, game_minutes)
				if guest.state == Guest.State.CHECKING_IN:
					guest.timer_minutes -= game_minutes
					if guest.timer_minutes <= 0.0:
						_finish_check_in(guest)
			Guest.State.GOING_TO_ROOM:
				if not _room_is_valid(guest) or guest.blocked_minutes >= BLOCKED_PATIENCE_MINUTES:
					_revoke_room(guest)
				elif _is_at_target(guest, agent):
					guest.timer_minutes = rng.randf_range(STAY_MIN_MINUTES, STAY_MAX_MINUTES)
					_set_state(guest, Guest.State.STAYING)
			Guest.State.STAYING:
				if not _room_is_valid(guest):
					_revoke_room(guest)
				else:
					guest.timer_minutes -= game_minutes
					if guest.timer_minutes <= 0.0:
						_start_leaving(guest, false)
			Guest.State.LEAVING:
				if _is_at_target(guest, agent) or guest.blocked_minutes >= BLOCKED_PATIENCE_MINUTES:
					_despawn(guest)
	_start_next_check_ins()
	_assign_waiting_guests()
	_flush_lines()


## Suma tiempo de espera y, si se acaba la paciencia, el huésped se marcha enfadado.
func _wait(guest: Guest, game_minutes: float) -> void:
	guest.waited_minutes += game_minutes
	if guest.waited_minutes >= PATIENCE_MINUTES:
		_start_leaving(guest, true)


func _is_at_target(guest: Guest, agent: Agent) -> bool:
	return guest.has_target and agent.state == Agent.State.IDLE and agent.get_cell() == guest.target_cell


func _finish_check_in(guest: Guest) -> void:
	guest.timer_minutes = 0.0
	_set_state(guest, Guest.State.WAITING_ROOM)
	_try_assign_room(guest)


# --- Asignación de dormitorio ----------------------------------------------------------------

func _on_rooms_changed(_room: Room) -> void:
	_assign_dirty = true


func _mark_assignment_dirty() -> void:
	_assign_dirty = true


## true si la habitación es un dormitorio que ahora mismo cumple sus requisitos.
func _is_usable_bedroom(room: Room) -> bool:
	return room.type_id == BEDROOM_TYPE and _rooms.get_status(room).is_operational()


## true si el dormitorio asignado al huésped sigue existiendo y siendo utilizable.
func _room_is_valid(guest: Guest) -> bool:
	var room: Room = _rooms.get_room(guest.room_id)
	return room != null and _is_usable_bedroom(room)


## Reintenta dar habitación a los que esperan, solo si algo cambió desde la última vez: el mapa,
## las habitaciones o la ocupación. Los más antiguos van primero.
func _assign_waiting_guests() -> void:
	if _grid.revision != _seen_revision:
		_seen_revision = _grid.revision
		_assign_dirty = true
	if not _assign_dirty:
		return
	_assign_dirty = false
	var waiting: Array[Guest] = []
	for guest: Guest in _guests.values():
		if guest.state == Guest.State.WAITING_ROOM:
			waiting.append(guest)
	waiting.sort_custom(func(a: Guest, b: Guest) -> bool: return a.ticket < b.ticket)
	for guest: Guest in waiting:
		_try_assign_room(guest)


## Busca el dormitorio libre, operativo y alcanzable más cercano a la posición del huésped, lo
## reserva y lo manda allí. Devuelve false si no hay ninguno.
func _try_assign_room(guest: Guest) -> bool:
	var agent: Agent = _agents.get_agent(guest.agent_id)
	if agent == null:
		return false
	var costs: Dictionary = Pathfinder.reachable_costs(_grid, guest.level, agent.get_cell())
	var best: Room = null
	var best_cost: float = INF
	for room: Room in _rooms.get_rooms(guest.level):
		if not _is_usable_bedroom(room) or not occupancy.is_free(room.id):
			continue
		for cell: Vector2i in room.cells:
			if costs.has(cell) and float(costs[cell]) < best_cost:
				best_cost = costs[cell]
				best = room
	if best == null:
		return false

	# Dentro del dormitorio va a la celda más alejada de su puerta (la "cama").
	var spot: Vector2i = best.cells[0]
	var spot_cost: float = -1.0
	for cell: Vector2i in best.cells:
		if costs.has(cell) and float(costs[cell]) > spot_cost:
			spot_cost = costs[cell]
			spot = cell
	if not occupancy.reserve(best.id, guest.id):
		return false
	guest.room_id = best.id
	if not _send(guest, spot):
		occupancy.release_guest(guest.id)
		guest.room_id = 0
		return false
	total_checked_in += 1
	_set_state(guest, Guest.State.GOING_TO_ROOM)
	guest_checked_in.emit(guest)
	return true


## El huésped pierde su habitación (ya no es válida o no puede llegar a ella) y vuelve a esperar
## otra, con la paciencia renovada.
func _revoke_room(guest: Guest) -> void:
	guest_room_lost.emit(guest) # antes de soltar la habitación: quien escuche aún la ve asignada
	occupancy.release_guest(guest.id)
	guest.room_id = 0
	guest.waited_minutes = 0.0
	guest.blocked_minutes = 0.0
	guest.timer_minutes = 0.0
	_set_state(guest, Guest.State.WAITING_ROOM)
	_try_assign_room(guest)


## Si la recepción está libre, el primero de la línea que ya esté en su puesto empieza el
## check-in. Es estricto: si el primero aún está llegando, nadie se le adelanta.
func _start_next_check_ins() -> void:
	var receptions: Dictionary = {}
	for guest: Guest in _guests.values():
		if LINE_STATES.has(guest.state):
			receptions[guest.reception_room_id] = true
	for reception_id: int in receptions.keys():
		var line: Array[Guest] = _line_of(reception_id)
		if line.is_empty():
			continue
		var head: Guest = line[0]
		var agent: Agent = _agents.get_agent(head.agent_id)
		if head.state == Guest.State.QUEUED and agent != null and _is_at_target(head, agent):
			head.timer_minutes = CHECK_IN_MINUTES
			_set_state(head, Guest.State.CHECKING_IN)


# --- Salida --------------------------------------------------------------------------------

## El huésped se va por la entrada por la que llegó (o por otra válida). Sin ninguna válida, o sin
## camino hasta ella, desaparece en el sitio.
func _start_leaving(guest: Guest, unhappy: bool) -> void:
	guest.left_unhappy = unhappy
	if not unhappy:
		guest.stay_completed = true
		guest_stay_completed.emit(guest)
	occupancy.release_guest(guest.id)
	guest.room_id = 0
	_set_state(guest, Guest.State.LEAVING)
	var exit: Vector2i = guest.entrance_cell
	if not _entrances.get_valid(guest.level).has(exit):
		var valid: Array[Vector2i] = _entrances.get_valid(guest.level)
		if valid.is_empty():
			_despawn(guest)
			return
		exit = valid[0]
	if not _send(guest, exit):
		_despawn(guest)


func _despawn(guest: Guest) -> void:
	if not _guests.has(guest.id):
		return
	_forget(guest)
	if guest.left_unhappy:
		total_left_unhappy += 1
	else:
		total_left_happy += 1
	_agents.remove(guest.agent_id)
	guest_left.emit(guest)


## Quita al huésped de los registros (sin tocar su agente).
func _forget(guest: Guest) -> void:
	_guests.erase(guest.id)
	_by_agent.erase(guest.agent_id)
	occupancy.release_guest(guest.id)
	_dirty_lines[guest.reception_room_id] = true


## Alguien eliminó el agente (la herramienta de desarrollo, por ejemplo): el huésped desaparece.
func _on_agent_removed(agent: Agent) -> void:
	var guest: Guest = get_guest_by_agent(agent.id)
	if guest == null:
		return
	_forget(guest)
	guest_left.emit(guest)
	_flush_lines()


# --- Línea de la recepción -----------------------------------------------------------------

## Huéspedes que hacen cola en esa recepción, en orden de atención: primero el que está en
## check-in, luego los que llegan o esperan turno por orden de llegada y al final los que ya se
## registraron pero esperan habitación (no deben bloquear a los demás).
func _line_of(reception_id: int) -> Array[Guest]:
	var line: Array[Guest] = []
	for guest: Guest in _guests.values():
		if guest.reception_room_id == reception_id and LINE_STATES.has(guest.state):
			line.append(guest)
	line.sort_custom(_compare_line)
	return line


func _compare_line(a: Guest, b: Guest) -> bool:
	var rank_a: int = _line_rank(a)
	var rank_b: int = _line_rank(b)
	if rank_a != rank_b:
		return rank_a < rank_b
	return a.ticket < b.ticket


func _line_rank(guest: Guest) -> int:
	match guest.state:
		Guest.State.CHECKING_IN:
			return 0
		Guest.State.WAITING_ROOM:
			return 2
		_:
			return 1


## Recoloca a los huéspedes de las recepciones marcadas: cada uno va al puesto que le toca.
func _flush_lines() -> void:
	var ids: Array = _dirty_lines.keys()
	_dirty_lines.clear()
	for reception_id: int in ids:
		_refresh_line(reception_id)


func _refresh_line(reception_id: int) -> void:
	var room: Room = _rooms.get_room(reception_id)
	if room == null:
		return
	var slots: Array[Vector2i] = _slot_cells(room)
	var line: Array[Guest] = _line_of(reception_id)
	for i in range(line.size()):
		var cell: Vector2i = slots[mini(i, slots.size() - 1)] # si no caben, comparten el último
		if not line[i].has_target or line[i].target_cell != cell:
			_send(line[i], cell)


## Puestos de la recepción: sus celdas, de la más lejana a la puerta (el mostrador) a la más
## cercana, de modo que la cola se forma desde el fondo hacia la puerta.
func _slot_cells(room: Room) -> Array[Vector2i]:
	var reference: Vector2 = _door_reference(room)
	var cells: Array[Vector2i] = room.cells.duplicate()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var distance_a: float = Vector2(a).distance_squared_to(reference)
		var distance_b: float = Vector2(b).distance_squared_to(reference)
		if distance_a != distance_b:
			return distance_a > distance_b
		return a.y < b.y or (a.y == b.y and a.x < b.x))
	return cells


## Punto de referencia de la entrada a la habitación: la media de las celdas interiores junto a
## sus puertas (o su centro, si no tiene).
func _door_reference(room: Room) -> Vector2:
	var sum := Vector2.ZERO
	var count: int = 0
	for door: Edge in room.doors:
		for cell: Vector2i in door.cells():
			if room.contains(cell):
				sum += Vector2(cell)
				count += 1
	if count == 0:
		return Vector2(room.get_bounds().get_center())
	return sum / float(count)


# --- Utilidades ----------------------------------------------------------------------------

## Manda al agente del huésped a una celda y la recuerda como su objetivo. Devuelve false si no
## hay camino.
func _send(guest: Guest, cell: Vector2i) -> bool:
	guest.target_cell = cell
	guest.has_target = true
	return _agents.set_destination(guest.agent_id, cell)


func _set_state(guest: Guest, new_state: Guest.State) -> void:
	if guest.state == new_state:
		return
	guest.state = new_state
	_dirty_lines[guest.reception_room_id] = true
	guest_state_changed.emit(guest)
