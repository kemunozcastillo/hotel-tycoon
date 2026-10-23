class_name GridTestHelpers
extends RefCounted
## Utilidades compartidas por los tests y las herramientas de verificación.


## Cuenta todas las paredes de un nivel recorriendo todas las aristas válidas.
static func count_walls(grid: GridMap2D, level: int = 0) -> int:
	var count: int = 0
	for y in range(grid.size.y + 1):
		for x in range(grid.size.x + 1):
			for axis: Edge.Axis in [Edge.Axis.X, Edge.Axis.Y]:
				var edge := Edge.new(Vector2i(x, y), axis)
				if grid.is_edge_valid(edge, level) and grid.has_wall(edge, level):
					count += 1
	return count


## Mapa aleatorio reproducible: ~85% de celdas con suelo, ~16% de aristas con pared y ~4% con
## puerta. Es para probar rutas y movimiento sobre laberintos irregulares.
static func random_state(rng: RandomNumberGenerator, size: Vector2i) -> GameState:
	var state := GameState.new(size)
	for y in range(size.y):
		for x in range(size.x):
			if rng.randf() < 0.85:
				state.build.place_floor(Vector2i(x, y), 0)
	for y in range(size.y + 1):
		for x in range(size.x + 1):
			for axis: Edge.Axis in [Edge.Axis.X, Edge.Axis.Y]:
				var edge := Edge.new(Vector2i(x, y), axis)
				if not state.grid.is_edge_valid(edge, 0):
					continue
				var roll: float = rng.randf()
				if roll < 0.16:
					state.build.place_wall(edge, 0)
				elif roll < 0.20:
					state.build.place_door(edge, 0)
	return state


## Todas las celdas con suelo de un nivel, en orden de fila.
static func walkable_cells(grid: GridMap2D, level: int = 0) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(grid.size.y):
		for x in range(grid.size.x):
			if grid.is_walkable(Vector2i(x, y), level):
				cells.append(Vector2i(x, y))
	return cells


## Cuenta las aristas de un tipo dado en un nivel.
static func count_edges(grid: GridMap2D, type: CellTypes.EdgeType, level: int = 0) -> int:
	var count: int = 0
	for y in range(grid.size.y + 1):
		for x in range(grid.size.x + 1):
			for axis: Edge.Axis in [Edge.Axis.X, Edge.Axis.Y]:
				var edge := Edge.new(Vector2i(x, y), axis)
				if grid.is_edge_valid(edge, level) and grid.get_edge_type(edge, level) == type:
					count += 1
	return count


## Celdas alcanzables desde `start` sin cruzar paredes.
static func flood_fill(grid: GridMap2D, start: Vector2i, level: int = 0) -> Array[Vector2i]:
	var visited: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_back()
		for offset: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = current + offset
			if visited.has(next) or grid.is_blocked_between(current, next, level):
				continue
			visited[next] = true
			queue.append(next)
	var result: Array[Vector2i] = []
	for cell: Vector2i in visited.keys():
		result.append(cell)
	return result
