class_name AgentRegistry
extends RefCounted
## Crea, guarda y mueve a los agentes.
##
## Cada agente sigue una ruta de A* a velocidad constante (Agent.speed, en celdas por minuto de
## juego), así que el reloj del juego manda: en pausa no se mueven y a x3 van el triple de
## rápido. Si el mapa cambia, antes de seguir comprueba que su ruta aún es transitable; si no,
## la recalcula, y si ya no hay camino queda BLOCKED y reintenta cuando el mapa vuelva a cambiar.

## Apareció un agente.
signal agent_added(agent: Agent)
## Un agente desapareció (el objeto conserva su último estado y su id).
signal agent_removed(agent: Agent)
## Cambió el estado de un agente o su ruta (nuevo destino, ruta recalculada, llegada, bloqueo).
## Las posiciones no emiten señal: la vista las lee cada fotograma.
signal agent_state_changed(agent: Agent)

var _grid: GridMap2D
var _agents: Dictionary = {} # id -> Agent
var _next_id: int = 1


func _init(grid: GridMap2D) -> void:
	_grid = grid


## Crea un agente en el centro de la celda. Devuelve null si la celda no se puede pisar.
func spawn(cell: Vector2i, level: int) -> Agent:
	if not _grid.is_walkable(cell, level):
		return null
	var agent := Agent.new(_next_id, level, Vector2(cell) + Vector2(0.5, 0.5))
	_next_id += 1
	_agents[agent.id] = agent
	agent_added.emit(agent)
	return agent


func remove(id: int) -> bool:
	var agent: Agent = _agents.get(id) as Agent
	if agent == null:
		return false
	_agents.erase(id)
	agent_removed.emit(agent)
	return true


func get_agent(id: int) -> Agent:
	return _agents.get(id) as Agent


## Todos los agentes, ordenados por id.
func get_agents() -> Array[Agent]:
	var result: Array[Agent] = []
	for agent: Agent in _agents.values():
		result.append(agent)
	result.sort_custom(func(a: Agent, b: Agent) -> bool: return a.id < b.id)
	return result


func get_agent_at(cell: Vector2i, level: int) -> Agent:
	for agent: Agent in get_agents():
		if agent.level == level and agent.get_cell() == cell:
			return agent
	return null


## Manda al agente a una celda. Devuelve false (sin cambiar nada) si el agente no existe o no
## hay camino hasta allí.
func set_destination(id: int, cell: Vector2i) -> bool:
	var agent: Agent = _agents.get(id) as Agent
	if agent == null:
		return false
	var path: Array[Vector2i] = Pathfinder.find_path(_grid, agent.level, agent.get_cell(), cell)
	if path.is_empty():
		return false
	_apply_path(agent, path)
	agent.destination = cell
	agent.has_destination = true
	_set_state(agent, Agent.State.WALKING)
	agent_state_changed.emit(agent)
	return true


## Cancela el destino y deja al agente quieto donde esté.
func stop(id: int) -> void:
	var agent: Agent = _agents.get(id) as Agent
	if agent == null:
		return
	_clear_route(agent)
	_set_state(agent, Agent.State.IDLE)
	agent_state_changed.emit(agent)


## Avanza a todos los agentes con los minutos de juego transcurridos.
func tick(game_minutes: float) -> void:
	if game_minutes <= 0.0:
		return
	for agent: Agent in get_agents():
		match agent.state:
			Agent.State.WALKING:
				if agent.planned_revision != _grid.revision and not _revalidate(agent):
					continue
				_advance(agent, game_minutes)
			Agent.State.BLOCKED:
				if agent.planned_revision != _grid.revision:
					_retry_blocked(agent)


# --- Rutas -------------------------------------------------------------------------------

## Guarda la ruta calculada desde la celda del agente (sin esa primera celda, salvo que el
## destino sea la propia celda: entonces va hasta su centro).
func _apply_path(agent: Agent, path: Array[Vector2i]) -> void:
	var remaining: Array[Vector2i] = path.duplicate()
	if remaining.size() > 1:
		remaining.pop_front()
	agent.path = remaining
	agent.planned_revision = _grid.revision


func _clear_route(agent: Agent) -> void:
	agent.path = []
	agent.has_destination = false
	agent.planned_revision = -1


## Recalcula la ruta hacia el destino actual. Devuelve false si ya no hay camino.
func _replan(agent: Agent) -> bool:
	var path: Array[Vector2i] = Pathfinder.find_path(_grid, agent.level, agent.get_cell(), agent.destination)
	if path.is_empty():
		return false
	_apply_path(agent, path)
	return true


## Tras un cambio del mapa: conserva la ruta si sigue siendo transitable, si no la recalcula, y
## si tampoco hay camino pasa a BLOCKED. Devuelve true si el agente puede seguir caminando.
func _revalidate(agent: Agent) -> bool:
	if _path_is_still_valid(agent):
		agent.planned_revision = _grid.revision
		return true
	if _replan(agent):
		agent_state_changed.emit(agent)
		return true
	agent.path = []
	agent.planned_revision = _grid.revision
	_set_state(agent, Agent.State.BLOCKED)
	agent_state_changed.emit(agent)
	return false


func _retry_blocked(agent: Agent) -> void:
	if _replan(agent):
		_set_state(agent, Agent.State.WALKING)
		agent_state_changed.emit(agent)
	else:
		agent.planned_revision = _grid.revision # no volver a intentarlo hasta el próximo cambio


func _path_is_still_valid(agent: Agent) -> bool:
	if not _grid.is_walkable(agent.destination, agent.level):
		return false
	var previous: Vector2i = agent.get_cell()
	for cell: Vector2i in agent.path:
		if cell != previous and not Pathfinder.is_step_legal(_grid, agent.level, previous, cell):
			return false
		previous = cell
	return true


# --- Movimiento ----------------------------------------------------------------------------

func _advance(agent: Agent, game_minutes: float) -> void:
	var budget: float = agent.speed * game_minutes # celdas que puede recorrer en este tick
	while budget > 0.0 and not agent.path.is_empty():
		var target: Vector2 = Vector2(agent.path[0]) + Vector2(0.5, 0.5)
		var distance: float = agent.position.distance_to(target)
		if distance <= budget:
			agent.position = target
			budget -= distance
			agent.path.pop_front()
		else:
			agent.position += (target - agent.position).normalized() * budget
			budget = 0.0
	if agent.path.is_empty():
		_clear_route(agent)
		_set_state(agent, Agent.State.IDLE)
		agent_state_changed.emit(agent)


func _set_state(agent: Agent, new_state: Agent.State) -> void:
	agent.state = new_state


# --- Guardado -----------------------------------------------------------------------------------

func serialize() -> Dictionary:
	var rows: Array = []
	for agent in get_agents():
		rows.append({
			"id": agent.id, "level": agent.level,
			"position": [SaveReader.float_data(agent.position.x), SaveReader.float_data(agent.position.y)],
			"speed": SaveReader.float_data(agent.speed), "state": agent.state, "has_destination": agent.has_destination,
			"destination": SaveReader.vec2i_data(agent.destination), "path": SaveReader.vec2i_list_data(agent.path),
			"planned_revision": agent.planned_revision, "wanders": agent.wanders,
		})
	return {"next_id": _next_id, "agents": rows}


## Sustituye a los agentes por los guardados. No emite `agent_added` (se usa sobre un estado recién
## creado, antes de que exista la vista).
func restore(data: Dictionary, reader: SaveReader) -> void:
	_agents.clear()
	var saved_next: int = reader.read_int(data, "next_id", "agentes", 1)
	var rows: Array = reader.read_array(data, "agents", "agentes")
	_next_id = saved_next
	for i in range(rows.size()):
		var where: String = "agentes.agents[%d]" % i
		var row: Dictionary = reader.as_dict(rows[i], where)
		if row.is_empty():
			continue
		var id: int = reader.read_int(row, "id", where, 1)
		var level: int = reader.read_int(row, "level", where, -64, 64)
		if _agents.has(id):
			reader.fail("%s: el id %d está repetido" % [where, id])
			continue
		if not _grid.has_level(level):
			reader.fail("%s: el nivel %d no existe" % [where, level])
			continue
		var position_raw: Variant = row.get("position")
		if typeof(position_raw) != TYPE_ARRAY or (position_raw as Array).size() != 2:
			reader.fail("%s: 'position' debe ser una pareja [x, y]" % where)
			continue
		var position := Vector2(
			reader.as_float((position_raw as Array)[0], where + ".position[0]", 0.0, float(_grid.size.x)),
			reader.as_float((position_raw as Array)[1], where + ".position[1]", 0.0, float(_grid.size.y)))
		var agent := Agent.new(id, level, position)
		agent.speed = reader.read_float(row, "speed", where, 0.0, 1000.0)
		agent.state = reader.read_enum(row, "state", where, Agent.State.size()) as Agent.State
		agent.has_destination = reader.read_bool(row, "has_destination", where)
		agent.destination = reader.read_vec2i(row, "destination", where)
		agent.planned_revision = reader.read_int(row, "planned_revision", where, -1)
		agent.wanders = reader.read_bool(row, "wanders", where)
		var path_raw: Array = reader.read_array(row, "path", where)
		for j in range(path_raw.size()):
			agent.path.append(reader.as_vec2i(path_raw[j], "%s.path[%d]" % [where, j]))
		_agents[id] = agent
		_next_id = maxi(_next_id, id + 1)
