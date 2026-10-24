class_name WanderBehavior
extends RefCounted
## Comportamiento provisional: los agentes libres pasean. Cada uno espera un rato, elige una
## celda alcanzable no muy lejana, camina hasta allí y vuelve a esperar. Se sustituirá por las
## necesidades de los huéspedes y las tareas del personal.
##
## Solo toca a los agentes que están IDLE y tienen `wanders`; no pisa las órdenes manuales
## (un agente que camina no se toca) y no tiene estado propio más que el tiempo de espera.

## Espera entre paseos, en minutos de juego.
const MIN_WAIT: float = 1.0
const MAX_WAIT: float = 4.0
## Distancia máxima (en celdas, por eje) del destino elegido.
const MAX_DISTANCE: int = 12
## Intentos de encontrar un destino alcanzable antes de volver a esperar.
const MAX_TRIES: int = 8

var rng := RandomNumberGenerator.new()

var _grid: GridMap2D
var _agents: AgentRegistry
var _wait: Dictionary = {} # id del agente -> minutos de espera que le quedan


func _init(grid: GridMap2D, agents: AgentRegistry) -> void:
	_grid = grid
	_agents = agents
	rng.randomize()
	agents.agent_removed.connect(_on_agent_removed)


## Fija la semilla del azar (para pruebas reproducibles).
func set_seed(seed_value: int) -> void:
	rng.seed = seed_value


func tick(game_minutes: float) -> void:
	if game_minutes <= 0.0:
		return
	for agent: Agent in _agents.get_agents():
		if agent.state != Agent.State.IDLE or not agent.wanders:
			_wait.erase(agent.id) # al volver a estar libre, esperará de nuevo desde cero
			continue
		if not _wait.has(agent.id):
			_wait[agent.id] = rng.randf_range(MIN_WAIT, MAX_WAIT)
		_wait[agent.id] = float(_wait[agent.id]) - game_minutes
		if float(_wait[agent.id]) > 0.0:
			continue
		_wait.erase(agent.id)
		_start_walk(agent)


## Intenta mandar al agente a una celda cercana al azar. Si no encuentra ninguna alcanzable,
## no pasa nada: volverá a intentarlo tras otra espera.
func _start_walk(agent: Agent) -> void:
	var origin: Vector2i = agent.get_cell()
	for attempt in range(MAX_TRIES):
		var target := Vector2i(
			origin.x + rng.randi_range(-MAX_DISTANCE, MAX_DISTANCE),
			origin.y + rng.randi_range(-MAX_DISTANCE, MAX_DISTANCE))
		if target == origin or not _grid.is_walkable(target, agent.level):
			continue
		if _agents.set_destination(agent.id, target):
			return


func _on_agent_removed(agent: Agent) -> void:
	_wait.erase(agent.id)


# --- Guardado -----------------------------------------------------------------------------------

func serialize() -> Dictionary:
	var waits: Dictionary = {}
	for id: int in _wait.keys():
		waits[str(id)] = SaveReader.float_data(_wait[id])
	return {"wait": waits, "rng": SaveReader.rng_data(rng)}


func restore(data: Dictionary, reader: SaveReader) -> void:
	_wait.clear()
	var waits: Dictionary = reader.read_dict(data, "wait", "paseo")
	for key: Variant in waits.keys():
		if typeof(key) != TYPE_STRING or not (key as String).is_valid_int():
			reader.fail("paseo.wait: id inválido '%s'" % str(key))
			continue
		_wait[(key as String).to_int()] = reader.as_float(waits[key], "paseo.wait[%s]" % str(key), -1.0e9)
	reader.read_rng(data, "rng", "paseo", rng)
