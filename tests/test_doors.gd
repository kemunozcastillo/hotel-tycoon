extends TestCase
## Pruebas de los tipos de arista: las puertas se cruzan pero separan habitaciones.

const MAP_SIZE := Vector2i(10, 8)


func test_edge_types_default_to_none_and_set() -> void:
	var grid := GridMap2D.new(MAP_SIZE)
	var edge: Edge = Edge.from_side(Vector2i(3, 3), Edge.Side.NORTH)
	assert_eq(grid.get_edge_type(edge, 0), CellTypes.EdgeType.NONE)
	assert_true(grid.set_edge_type(edge, 0, CellTypes.EdgeType.DOOR))
	assert_eq(grid.get_edge_type(edge, 0), CellTypes.EdgeType.DOOR)
	assert_true(grid.has_door(edge, 0))
	assert_false(grid.has_wall(edge, 0), "una puerta no cuenta como pared")
	assert_false(grid.set_edge_type(edge, 0, CellTypes.EdgeType.DOOR), "sin cambio devuelve false")


func test_door_is_shared_between_neighbors() -> void:
	var grid := GridMap2D.new(MAP_SIZE)
	grid.set_edge_type(Edge.from_side(Vector2i(2, 2), Edge.Side.EAST), 0, CellTypes.EdgeType.DOOR)
	assert_true(grid.has_door(Edge.from_side(Vector2i(3, 2), Edge.Side.WEST), 0))


func test_door_on_map_border_is_valid_and_out_of_range_is_not() -> void:
	var grid := GridMap2D.new(MAP_SIZE)
	var border: Edge = Edge.from_side(Vector2i(MAP_SIZE.x - 1, 0), Edge.Side.EAST)
	assert_true(grid.set_edge_type(border, 0, CellTypes.EdgeType.DOOR))
	assert_false(grid.set_edge_type(Edge.new(Vector2i(MAP_SIZE.x, 0), Edge.Axis.X), 0, CellTypes.EdgeType.DOOR))
	assert_false(grid.set_edge_type(border, 4, CellTypes.EdgeType.DOOR), "nivel inexistente")


func test_wall_replaces_door_and_door_replaces_wall() -> void:
	var state := GameState.new(MAP_SIZE)
	var edge: Edge = Edge.from_side(Vector2i(4, 4), Edge.Side.SOUTH)
	assert_true(state.build.place_door(edge, 0))
	assert_true(state.build.place_wall(edge, 0), "colocar una pared sobre la puerta la sustituye")
	assert_true(state.grid.has_wall(edge, 0))
	assert_true(state.build.place_door(edge, 0), "colocar una puerta sobre la pared la sustituye")
	assert_true(state.grid.has_door(edge, 0))
	assert_false(state.build.place_door(edge, 0), "ya hay una puerta")


func test_remove_wall_and_remove_door_only_touch_their_own_type() -> void:
	var state := GameState.new(MAP_SIZE)
	var edge: Edge = Edge.from_side(Vector2i(4, 4), Edge.Side.SOUTH)
	state.build.place_door(edge, 0)
	assert_false(state.build.remove_wall(edge, 0), "quitar pared no quita puertas")
	assert_true(state.grid.has_door(edge, 0))
	assert_true(state.build.remove_door(edge, 0))
	assert_eq(state.grid.get_edge_type(edge, 0), CellTypes.EdgeType.NONE)
	state.build.place_wall(edge, 0)
	assert_false(state.build.remove_door(edge, 0), "quitar puerta no quita paredes")
	assert_true(state.grid.has_wall(edge, 0))
	state.build.place_door(edge, 0)
	assert_true(state.build.clear_edge(edge, 0), "clear_edge quita cualquier tipo")
	assert_eq(state.grid.get_edge_type(edge, 0), CellTypes.EdgeType.NONE)


func test_door_signals_changes_once() -> void:
	var state := GameState.new(MAP_SIZE)
	var events: Array[Edge] = []
	state.grid.edge_changed.connect(func(edge: Edge, _level: int) -> void: events.append(edge))
	var edge: Edge = Edge.new(Vector2i(1, 1), Edge.Axis.Y)
	state.build.place_door(edge, 0)
	state.build.place_door(edge, 0)
	state.build.place_wall(edge, 0)
	state.build.remove_door(edge, 0) # ya es pared: no cambia
	assert_eq(events.size(), 2)


func test_door_lets_movement_through_but_still_separates_rooms() -> void:
	var state := GameState.new(MAP_SIZE)
	var rect := Rect2i(Vector2i(3, 3), Vector2i(2, 2))
	state.build.outline_rect_walls(rect, 0)
	var door: Edge = Edge.from_side(Vector2i(3, 3), Edge.Side.NORTH)
	var outside := Vector2i(3, 2)
	assert_true(state.grid.is_blocked_between(Vector2i(3, 3), outside, 0), "con pared bloquea el paso")
	assert_true(state.grid.is_room_boundary(Vector2i(3, 3), outside, 0))
	state.build.place_door(door, 0)
	assert_false(state.grid.is_blocked_between(Vector2i(3, 3), outside, 0), "la puerta se cruza")
	assert_true(state.grid.is_room_boundary(Vector2i(3, 3), outside, 0), "pero sigue separando habitaciones")
	assert_true(GridTestHelpers.flood_fill(state.grid, Vector2i(3, 3)).size() > 4, "se puede salir por la puerta")


func test_is_room_boundary_edge_cases() -> void:
	var state := GameState.new(MAP_SIZE)
	var a := Vector2i(0, 0)
	assert_false(state.grid.is_room_boundary(a, Vector2i(1, 0), 0), "arista vacía")
	assert_false(state.grid.is_room_boundary(a, Vector2i(2, 0), 0), "no contiguas")
	# Hacia fuera del mapa solo separa si hay pared o puerta en el borde.
	assert_false(state.grid.is_room_boundary(a, Vector2i(-1, 0), 0), "borde del mapa sin pared")
	state.build.place_wall(Edge.from_side(a, Edge.Side.WEST), 0)
	assert_true(state.grid.is_room_boundary(a, Vector2i(-1, 0), 0), "borde del mapa con pared")
	assert_false(state.grid.is_room_boundary(a, Vector2i(1, 0), 5), "nivel inexistente")


func test_outline_and_build_room_respect_existing_doors() -> void:
	var state := GameState.new(MAP_SIZE)
	var rect := Rect2i(Vector2i(2, 2), Vector2i(3, 3))
	state.build.build_room(rect, 0)
	var door: Edge = Edge.from_side(Vector2i(3, 2), Edge.Side.NORTH)
	state.build.place_door(door, 0)
	assert_eq(GridTestHelpers.count_edges(state.grid, CellTypes.EdgeType.WALL), 11)
	assert_eq(state.build.build_room(rect, 0), 0, "reconstruir no tapa la puerta")
	assert_true(state.grid.has_door(door, 0))
	assert_eq(state.build.clear_outline_walls(rect, 0), 11, "quitar el perímetro respeta la puerta")
	assert_true(state.grid.has_door(door, 0))


func test_demolish_room_removes_doors_too() -> void:
	var state := GameState.new(MAP_SIZE)
	var rect := Rect2i(Vector2i(2, 2), Vector2i(2, 2))
	state.build.build_room(rect, 0)
	state.build.place_door(Edge.from_side(Vector2i(2, 2), Edge.Side.WEST), 0)
	state.build.demolish_room(rect, 0)
	assert_eq(GridTestHelpers.count_edges(state.grid, CellTypes.EdgeType.WALL), 0)
	assert_eq(GridTestHelpers.count_edges(state.grid, CellTypes.EdgeType.DOOR), 0)
	assert_eq(state.grid.get_floor_type(Vector2i(2, 2), 0), CellTypes.FloorType.NONE)
