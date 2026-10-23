class_name Pathfinder
extends RefCounted
## Búsqueda de caminos A* sobre la cuadrícula. Función pura: lee el mapa y devuelve una ruta.
##
## - Se mueve en 8 direcciones. Un paso diagonal solo es válido si los dos pasos ortogonales
##   que lo rodean también lo son (no se cortan esquinas de pared ni celdas sin suelo).
## - Una pared bloquea el paso; una puerta se cruza (GridMap2D.is_blocked_between).
## - Qué celdas se pueden pisar y cuánto cuesta pisarlas lo decide solo el mapa
##   (GridMap2D.is_walkable / get_walk_cost). El coste de un paso es su longitud (1 en recto,
##   √2 en diagonal) por el coste de la celda de destino, con un mínimo de 1.0 para que la
##   heurística siga siendo admisible.

## Si la búsqueda expande más celdas que esto sin llegar, se da por perdida (evita cuelgues).
const DEFAULT_MAX_EXPANSIONS: int = 4096

const DIAGONAL_COST: float = 1.41421356
const ORTHOGONAL_STEPS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
const DIAGONAL_STEPS: Array[Vector2i] = [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]


## Ruta de `from` a `to`, ambas incluidas (si son la misma celda, solo esa). Devuelve un array
## vacío si no hay camino: destino no pisable o fuera del mapa, origen fuera del mapa, destino
## inalcanzable o búsqueda demasiado larga. El origen no tiene que ser pisable: un agente
## puede estar sobre un suelo que acaban de quitar y debe poder salir de ahí.
static func find_path(grid: GridMap2D, level: int, from: Vector2i, to: Vector2i, max_expansions: int = DEFAULT_MAX_EXPANSIONS) -> Array[Vector2i]:
	var no_path: Array[Vector2i] = []
	if not grid.has_level(level) or not grid.in_bounds(from) or not grid.is_walkable(to, level):
		return no_path
	if from == to:
		return [from]

	var open := MinHeap.new()
	var best_cost: Dictionary = {from: 0.0} # celda -> mejor coste conocido
	var came_from: Dictionary = {}
	var closed: Dictionary = {}
	open.push(from, _heuristic(from, to))

	var expansions: int = 0
	while not open.is_empty():
		var current: Vector2i = open.pop()
		if closed.has(current):
			continue
		if current == to:
			return _rebuild(came_from, from, to)
		closed[current] = true
		expansions += 1
		if expansions > max_expansions:
			return no_path
		var current_cost: float = best_cost[current]
		for step: Vector2i in ORTHOGONAL_STEPS:
			if can_step(grid, level, current, step):
				_relax(grid, level, current, step, 1.0, current_cost, to, open, best_cost, came_from, closed)
		for step: Vector2i in DIAGONAL_STEPS:
			if _diagonal_is_open(grid, level, current, step):
				_relax(grid, level, current, step, DIAGONAL_COST, current_cost, to, open, best_cost, came_from, closed)
	return no_path


## Coste mínimo de llegar desde `from` a cada celda alcanzable (Dijkstra con las mismas reglas
## que find_path). Devuelve celda -> coste; `from` figura con 0 aunque no sea pisable. Sirve para
## comparar muchos destinos a la vez (la habitación más cercana, por ejemplo) con una sola
## búsqueda. `max_cost` recorta la búsqueda.
static func reachable_costs(grid: GridMap2D, level: int, from: Vector2i, max_cost: float = INF) -> Dictionary:
	var costs: Dictionary = {}
	if not grid.has_level(level) or not grid.in_bounds(from):
		return costs
	var best_cost: Dictionary = {from: 0.0}
	var open := MinHeap.new()
	open.push(from, 0.0)
	while not open.is_empty():
		var current: Vector2i = open.pop()
		if costs.has(current):
			continue
		var current_cost: float = best_cost[current]
		costs[current] = current_cost
		for step: Vector2i in ORTHOGONAL_STEPS:
			if can_step(grid, level, current, step):
				_relax_cost(grid, level, current + step, 1.0, current_cost, max_cost, open, best_cost, costs)
		for step: Vector2i in DIAGONAL_STEPS:
			if _diagonal_is_open(grid, level, current, step):
				_relax_cost(grid, level, current + step, DIAGONAL_COST, current_cost, max_cost, open, best_cost, costs)
	return costs


static func _relax_cost(grid: GridMap2D, level: int, next: Vector2i, length: float, current_cost: float, max_cost: float,
		open: MinHeap, best_cost: Dictionary, done: Dictionary) -> void:
	if done.has(next):
		return
	var new_cost: float = current_cost + length * maxf(1.0, grid.get_walk_cost(next, level))
	if new_cost > max_cost:
		return
	if best_cost.has(next) and new_cost >= float(best_cost[next]):
		return
	best_cost[next] = new_cost
	open.push(next, new_cost)


## Coste total de una ruta (la suma de sus pasos con la misma fórmula que usa find_path).
static func path_cost(grid: GridMap2D, level: int, path: Array[Vector2i]) -> float:
	var total: float = 0.0
	for i in range(1, path.size()):
		var step: Vector2i = path[i] - path[i - 1]
		var length: float = 1.0 if step.x == 0 or step.y == 0 else DIAGONAL_COST
		total += length * maxf(1.0, grid.get_walk_cost(path[i], level))
	return total


## true si ir de `from` a la celda contigua `to` (ortogonal o diagonal) es un paso válido según
## las reglas de find_path. Sirve para comprobar que una ruta guardada sigue siendo transitable.
static func is_step_legal(grid: GridMap2D, level: int, from: Vector2i, to: Vector2i) -> bool:
	var step: Vector2i = to - from
	if step == Vector2i.ZERO or absi(step.x) > 1 or absi(step.y) > 1:
		return false
	if step.x == 0 or step.y == 0:
		return can_step(grid, level, from, step)
	return _diagonal_is_open(grid, level, from, step)


## true si se puede ir de `from` a la celda contigua `from + step` (ortogonal) sin pared y
## pisando una celda válida.
static func can_step(grid: GridMap2D, level: int, from: Vector2i, step: Vector2i) -> bool:
	var next: Vector2i = from + step
	return grid.is_walkable(next, level) and not grid.is_blocked_between(from, next, level)


## true si el paso diagonal es válido: la celda de destino y las dos que lo flanquean se pueden
## pisar y los cuatro pasos ortogonales alrededor no cruzan paredes.
static func _diagonal_is_open(grid: GridMap2D, level: int, from: Vector2i, step: Vector2i) -> bool:
	var horizontal := Vector2i(step.x, 0)
	var vertical := Vector2i(0, step.y)
	return can_step(grid, level, from, horizontal) \
			and can_step(grid, level, from, vertical) \
			and can_step(grid, level, from + horizontal, vertical) \
			and can_step(grid, level, from + vertical, horizontal)


## Registra el paso `current -> current + step` si mejora lo conocido. El llamador ya comprobó
## que el paso es válido (ortogonal o diagonal).
static func _relax(grid: GridMap2D, level: int, current: Vector2i, step: Vector2i, length: float, current_cost: float,
		to: Vector2i, open: MinHeap, best_cost: Dictionary, came_from: Dictionary, closed: Dictionary) -> void:
	var next: Vector2i = current + step
	if closed.has(next):
		return
	var new_cost: float = current_cost + length * maxf(1.0, grid.get_walk_cost(next, level))
	if best_cost.has(next) and new_cost >= float(best_cost[next]):
		return
	best_cost[next] = new_cost
	came_from[next] = current
	open.push(next, new_cost + _heuristic(next, to))


## Distancia octil: la más corta posible con 8 direcciones y coste mínimo 1.
static func _heuristic(a: Vector2i, b: Vector2i) -> float:
	var dx: int = absi(a.x - b.x)
	var dy: int = absi(a.y - b.y)
	return float(maxi(dx, dy)) + (DIAGONAL_COST - 1.0) * float(mini(dx, dy))


static func _rebuild(came_from: Dictionary, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [to]
	var cell: Vector2i = to
	while cell != from:
		cell = came_from[cell]
		path.append(cell)
	path.reverse()
	return path
