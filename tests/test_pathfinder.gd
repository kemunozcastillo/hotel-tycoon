extends TestCase
## Pruebas de A*: rutas, paredes, puertas, esquinas, costes y comparación con Dijkstra.

const MAP_SIZE := Vector2i(12, 10)
const SQRT2: float = 1.41421356


## Mapa de prueba que encarece algunas celdas (para probar el gancho de coste del terreno).
class CostlyGrid extends GridMap2D:
	var costly: Dictionary = {}

	func get_walk_cost(cell: Vector2i, _level: int) -> float:
		return 10.0 if costly.has(cell) else 1.0


## Mapa de prueba con un coste (inválido) menor que 1.
class CheapGrid extends GridMap2D:
	func get_walk_cost(_cell: Vector2i, _level: int) -> float:
		return 0.1


func _open_floor(size: Vector2i = MAP_SIZE) -> GameState:
	var state := GameState.new(size)
	state.build.fill_rect_floor(Rect2i(Vector2i.ZERO, size), 0)
	return state


func _find(state: GameState, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	return Pathfinder.find_path(state.grid, 0, from, to)


# --- Casos básicos ---------------------------------------------------------------------

func test_same_cell_is_a_single_cell_path() -> void:
	var state := _open_floor()
	assert_eq(_find(state, Vector2i(3, 3), Vector2i(3, 3)), [Vector2i(3, 3)] as Array[Vector2i])


func test_straight_and_diagonal_paths_on_open_floor() -> void:
	var state := _open_floor()
	var straight: Array[Vector2i] = _find(state, Vector2i(1, 1), Vector2i(5, 1))
	assert_eq(straight.size(), 5)
	assert_eq(straight[0], Vector2i(1, 1))
	assert_eq(straight[4], Vector2i(5, 1))
	var diagonal: Array[Vector2i] = _find(state, Vector2i(0, 0), Vector2i(4, 4))
	assert_eq(diagonal.size(), 5, "cuatro pasos en diagonal")
	assert_near(Pathfinder.path_cost(state.grid, 0, diagonal), 4.0 * SQRT2, "", 0.001)


func test_mixed_path_cost_is_octile() -> void:
	var state := _open_floor()
	var path: Array[Vector2i] = _find(state, Vector2i(0, 0), Vector2i(5, 2))
	# 2 diagonales y 3 rectos.
	assert_near(Pathfinder.path_cost(state.grid, 0, path), 3.0 + 2.0 * SQRT2, "", 0.001)


# --- Invalidos -------------------------------------------------------------------------

func test_unwalkable_or_out_of_map_targets_have_no_path() -> void:
	var state := GameState.new(MAP_SIZE)
	state.build.fill_rect_floor(Rect2i(Vector2i.ZERO, Vector2i(4, 4)), 0)
	assert_eq(_find(state, Vector2i(0, 0), Vector2i(8, 8)).size(), 0, "destino sin suelo")
	assert_eq(_find(state, Vector2i(0, 0), Vector2i(-1, 0)).size(), 0, "destino fuera del mapa")
	assert_eq(_find(state, Vector2i(-1, 0), Vector2i(1, 1)).size(), 0, "origen fuera del mapa")
	assert_eq(Pathfinder.find_path(state.grid, 5, Vector2i(0, 0), Vector2i(1, 1)).size(), 0, "nivel inexistente")


func test_start_on_unwalkable_cell_can_still_leave() -> void:
	var state := _open_floor()
	state.build.remove_floor(Vector2i(2, 2), 0) # el agente estaba aquí cuando quitaron el suelo
	var path: Array[Vector2i] = _find(state, Vector2i(2, 2), Vector2i(5, 5))
	assert_true(path.size() > 0)
	assert_eq(path[0], Vector2i(2, 2))


func test_cells_without_floor_are_walked_around() -> void:
	var state := _open_floor()
	# Una columna sin suelo con un paso libre abajo del todo.
	for y in range(0, MAP_SIZE.y - 1):
		state.build.remove_floor(Vector2i(5, y), 0)
	var path: Array[Vector2i] = _find(state, Vector2i(2, 2), Vector2i(8, 2))
	assert_true(path.size() > 0)
	for cell: Vector2i in path:
		assert_true(state.grid.is_walkable(cell, 0) or cell == Vector2i(2, 2), "no pisa celdas sin suelo")
	assert_true(path.has(Vector2i(5, MAP_SIZE.y - 1)), "pasa por el hueco")


# --- Paredes y puertas ---------------------------------------------------------------------

func test_closed_room_is_unreachable_until_a_door_opens() -> void:
	var state := _open_floor()
	var rect := Rect2i(Vector2i(4, 4), Vector2i(2, 2))
	state.build.outline_rect_walls(rect, 0)
	assert_eq(_find(state, Vector2i(0, 0), Vector2i(4, 4)).size(), 0, "encerrada por paredes")
	assert_eq(_find(state, Vector2i(4, 4), Vector2i(0, 0)).size(), 0, "y no se puede salir")
	var door: Edge = Edge.from_side(Vector2i(5, 5), Edge.Side.SOUTH)
	state.build.place_door(door, 0)
	var path: Array[Vector2i] = _find(state, Vector2i(0, 0), Vector2i(4, 4))
	assert_true(path.size() > 0, "con puerta sí")
	var through_door: bool = false
	for i in range(1, path.size()):
		var edge: Edge = Edge.between(path[i - 1], path[i])
		if edge != null and edge.is_equal(door):
			through_door = true
	assert_true(through_door, "la ruta cruza por la puerta")


func test_wall_forces_a_detour() -> void:
	var state := _open_floor()
	# Pared vertical entre las columnas 5 y 6, con hueco solo en la fila 9.
	for y in range(0, 9):
		state.build.place_wall(Edge.from_side(Vector2i(5, y), Edge.Side.EAST), 0)
	var path: Array[Vector2i] = _find(state, Vector2i(3, 2), Vector2i(8, 2))
	assert_true(path.size() > 0)
	assert_true(Pathfinder.path_cost(state.grid, 0, path) > 5.0 + 0.001, "da la vuelta")
	_assert_path_is_legal(state, path)


func test_diagonal_does_not_cut_a_wall_corner() -> void:
	var state := _open_floor()
	# Las paredes este y sur de (2,2) forman una L: ir de (2,2) a (3,3) en diagonal pasaría
	# rozando el vértice de la esquina, y no debe permitirse.
	state.build.place_wall(Edge.from_side(Vector2i(2, 2), Edge.Side.EAST), 0)
	state.build.place_wall(Edge.from_side(Vector2i(2, 2), Edge.Side.SOUTH), 0)
	var path: Array[Vector2i] = _find(state, Vector2i(2, 2), Vector2i(3, 3))
	assert_true(path.size() > 0)
	assert_true(path.size() > 2, "no atraviesa la esquina en un solo paso")
	_assert_path_is_legal(state, path)


func test_diagonal_blocked_by_a_single_wall_beside_it() -> void:
	var state := _open_floor()
	# Con una sola pared al este de (2,2) la diagonal a (3,3) tampoco es válida
	# (el paso intermedio hacia el este está bloqueado), pero sí por abajo.
	state.build.place_wall(Edge.from_side(Vector2i(2, 2), Edge.Side.EAST), 0)
	var path: Array[Vector2i] = _find(state, Vector2i(2, 2), Vector2i(3, 3))
	assert_eq(path.size(), 3, "dos pasos: abajo y luego a la derecha")
	_assert_path_is_legal(state, path)


func test_diagonal_requires_floor_on_both_flanking_cells() -> void:
	var state := _open_floor()
	state.build.remove_floor(Vector2i(3, 2), 0) # flanco este de la diagonal (2,2)->(3,3)
	var path: Array[Vector2i] = _find(state, Vector2i(2, 2), Vector2i(3, 3))
	assert_eq(path.size(), 3, "rodea por la celda con suelo")
	assert_false(path.has(Vector2i(3, 2)))


# --- Costes y límites ------------------------------------------------------------------

func test_walk_cost_makes_cheaper_detours_preferred() -> void:
	var grid := CostlyGrid.new(Vector2i(9, 5))
	for y in range(5):
		for x in range(9):
			grid.set_floor_type(Vector2i(x, y), 0, CellTypes.FloorType.BASIC)
	# Una franja cara en la fila central entre x=3 y x=5.
	for x in range(3, 6):
		grid.costly[Vector2i(x, 2)] = true
	var path: Array[Vector2i] = Pathfinder.find_path(grid, 0, Vector2i(0, 2), Vector2i(8, 2))
	assert_true(path.size() > 0)
	for cell: Vector2i in path:
		assert_false(grid.costly.has(cell), "evita las celdas caras %s" % str(cell))
	# Sin el coste, el camino recto sería 8; con el rodeo es algo más caro pero más barato que pisar.
	assert_true(Pathfinder.path_cost(grid, 0, path) < 8.0 + 3.0 * 9.0)


func test_cost_below_one_is_clamped() -> void:
	# Un coste menor que 1 rompería la heurística; se trata como 1.
	var grid := CheapGrid.new(Vector2i(5, 1))
	for x in range(5):
		grid.set_floor_type(Vector2i(x, 0), 0, CellTypes.FloorType.BASIC)
	var path: Array[Vector2i] = Pathfinder.find_path(grid, 0, Vector2i(0, 0), Vector2i(4, 0))
	assert_near(Pathfinder.path_cost(grid, 0, path), 4.0)


func test_search_limit_gives_up() -> void:
	var state := _open_floor(Vector2i(30, 30))
	assert_eq(Pathfinder.find_path(state.grid, 0, Vector2i(0, 0), Vector2i(29, 29), 5).size(), 0, "límite muy bajo")
	assert_true(Pathfinder.find_path(state.grid, 0, Vector2i(0, 0), Vector2i(29, 29)).size() > 0, "con el límite normal sí")


# --- A* frente a una referencia (Dijkstra) en mapas aleatorios --------------------------------

func test_matches_dijkstra_on_random_maps() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240607
	var compared: int = 0
	var unreachable: int = 0
	for map_index in range(25):
		var state: GameState = GridTestHelpers.random_state(rng, Vector2i(10, 9))
		var cells: Array[Vector2i] = []
		for y in range(9):
			for x in range(10):
				cells.append(Vector2i(x, y))
		for pair_index in range(12):
			var from: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
			var to: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
			var path: Array[Vector2i] = _find(state, from, to)
			var expected: float = _reference_cost(state.grid, from, to)
			compared += 1
			if expected < 0.0:
				unreachable += 1
				assert_eq(path.size(), 0, "mapa %d: %s -> %s no debería tener ruta" % [map_index, str(from), str(to)])
				continue
			assert_true(path.size() > 0, "mapa %d: %s -> %s debería tener ruta" % [map_index, str(from), str(to)])
			if path.is_empty():
				continue
			assert_near(Pathfinder.path_cost(state.grid, 0, path), expected, "mapa %d: coste %s -> %s" % [map_index, str(from), str(to)], 0.001)
			_assert_path_is_legal(state, path)
	assert_true(compared == 300 and unreachable > 20 and unreachable < 280, "la muestra mezcla casos alcanzables e inalcanzables (%d inalcanzables)" % unreachable)


## Dijkstra sencillo (sin montículo) con las reglas de movimiento escritas de nuevo, de forma
## independiente al Pathfinder. Devuelve -1 si no hay camino.
func _reference_cost(grid: GridMap2D, from: Vector2i, to: Vector2i) -> float:
	if not grid.is_walkable(to, 0):
		return -1.0
	var dist: Dictionary = {from: 0.0}
	var done: Dictionary = {}
	while true:
		var best: Vector2i = Vector2i(-999, -999)
		var best_dist: float = INF
		for cell: Vector2i in dist.keys():
			if not done.has(cell) and float(dist[cell]) < best_dist:
				best = cell
				best_dist = dist[cell]
		if best_dist == INF:
			return -1.0
		if best == to:
			return best_dist
		done[best] = true
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var next: Vector2i = best + Vector2i(dx, dy)
				if not _reference_step_is_legal(grid, best, Vector2i(dx, dy)):
					continue
				var length: float = 1.0 if dx == 0 or dy == 0 else SQRT2
				var candidate: float = best_dist + length
				if not dist.has(next) or candidate < float(dist[next]):
					dist[next] = candidate
	return -1.0


func _reference_step_is_legal(grid: GridMap2D, from: Vector2i, step: Vector2i) -> bool:
	var to: Vector2i = from + step
	if not grid.is_walkable(to, 0):
		return false
	if step.x == 0 or step.y == 0:
		return not grid.is_blocked_between(from, to, 0)
	var side_x: Vector2i = from + Vector2i(step.x, 0)
	var side_y: Vector2i = from + Vector2i(0, step.y)
	if not grid.is_walkable(side_x, 0) or not grid.is_walkable(side_y, 0):
		return false
	return not grid.is_blocked_between(from, side_x, 0) \
			and not grid.is_blocked_between(side_x, to, 0) \
			and not grid.is_blocked_between(from, side_y, 0) \
			and not grid.is_blocked_between(side_y, to, 0)


## Comprueba paso a paso que la ruta no atraviesa paredes ni corta esquinas.
func _assert_path_is_legal(state: GameState, path: Array[Vector2i]) -> void:
	for i in range(1, path.size()):
		var step: Vector2i = path[i] - path[i - 1]
		assert_true(absi(step.x) <= 1 and absi(step.y) <= 1 and step != Vector2i.ZERO, "paso contiguo %s" % str(step))
		assert_true(_reference_step_is_legal(state.grid, path[i - 1], step), "paso %d legal: %s -> %s" % [i, str(path[i - 1]), str(path[i])])
