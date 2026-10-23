class_name RoomDetector
extends RefCounted
## Detecta las habitaciones de un nivel. Función pura: lee el mapa y devuelve datos nuevos.
##
## Una habitación es una región de celdas conectadas sin cruzar paredes ni puertas
## (GridMap2D.is_room_boundary) y que está cerrada: no llega al borde del mapa por ningún lado
## sin pared o puerta. Las regiones abiertas (el "exterior") no son habitaciones. Una región
## cerrada cuenta como habitación aunque le falte suelo (se marca en has_complete_floor).

const OFFSETS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]


## Todas las habitaciones del nivel, ordenadas por su primera celda (fila a fila).
static func detect(grid: GridMap2D, level: int) -> Array[Room]:
	var rooms: Array[Room] = []
	if not grid.has_level(level):
		return rooms
	var visited: Dictionary = {}
	for y in range(grid.size.y):
		for x in range(grid.size.x):
			var start := Vector2i(x, y)
			if visited.has(start):
				continue
			var room: Room = _explore(grid, level, start, visited)
			if room != null:
				rooms.append(room)
	return rooms


## Recorre la región que contiene `start`. Devuelve la habitación, o null si la región es abierta.
static func _explore(grid: GridMap2D, level: int, start: Vector2i, visited: Dictionary) -> Room:
	var cells: Array[Vector2i] = []
	var doors: Array[Edge] = []
	var door_keys: Dictionary = {}
	var leaks: bool = false
	var complete_floor: bool = true

	visited[start] = true
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		cells.append(cell)
		if grid.get_floor_type(cell, level) == CellTypes.FloorType.NONE:
			complete_floor = false
		for offset: Vector2i in OFFSETS:
			var next: Vector2i = cell + offset
			var edge: Edge = Edge.between(cell, next)
			if grid.get_edge_type(edge, level) == CellTypes.EdgeType.DOOR:
				var key := Vector3i(edge.cell.x, edge.cell.y, edge.axis)
				if not door_keys.has(key):
					door_keys[key] = true
					doors.append(edge)
			if grid.is_room_boundary(cell, next, level):
				continue
			if not grid.in_bounds(next):
				leaks = true # el borde del mapa sin pared es un escape
				continue
			if not visited.has(next):
				visited[next] = true
				queue.append(next)

	if leaks:
		return null
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return Room.new(level, cells, doors, complete_floor)
