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
