extends TestCase
## Pruebas del registro de piezas colocadas: cuándo son nuevas y cuándo usadas.

const MAP_SIZE := Vector2i(10, 8)
const NEW := BuildItem.Condition.NEW
const USED := BuildItem.Condition.USED


class Fixture:
	var grid: GridMap2D
	var clock: GameClock
	var rules: EconomyRules
	var pieces: PlacedPieces


func _fixture() -> Fixture:
	var f := Fixture.new()
	f.grid = GridMap2D.new(MAP_SIZE)
	f.clock = GameClock.new()
	f.rules = EconomyRules.new() # ventana de 60 minutos
	f.pieces = PlacedPieces.new(f.grid, f.clock, f.rules)
	return f


func test_a_piece_is_new_just_after_placing_and_used_after_the_window() -> void:
	var f := _fixture()
	var cell := Vector2i(2, 2)
	f.grid.set_floor_type(cell, 0, CellTypes.FloorType.BASIC)
	assert_eq(f.pieces.floor_condition(cell, 0), NEW)
	f.clock.total_minutes += 59.9
	assert_eq(f.pieces.floor_condition(cell, 0), NEW, "justo antes de que acabe el margen")
	f.clock.total_minutes += 0.2
	assert_eq(f.pieces.floor_condition(cell, 0), USED, "pasado el margen")


func test_window_comes_from_the_rules() -> void:
	var f := _fixture()
	f.rules.new_window_minutes = 10.0
	f.grid.set_floor_type(Vector2i(1, 1), 0, CellTypes.FloorType.BASIC)
	f.clock.total_minutes += 9.0
	assert_eq(f.pieces.floor_condition(Vector2i(1, 1), 0), NEW)
	f.clock.total_minutes += 2.0
	assert_eq(f.pieces.floor_condition(Vector2i(1, 1), 0), USED)
	f.rules.new_window_minutes = 0.0
	f.grid.set_floor_type(Vector2i(3, 3), 0, CellTypes.FloorType.BASIC)
	assert_eq(f.pieces.floor_condition(Vector2i(3, 3), 0), USED, "sin margen, todo es usado")


func test_pieces_age_each_on_its_own() -> void:
	var f := _fixture()
	f.grid.set_floor_type(Vector2i(1, 1), 0, CellTypes.FloorType.BASIC)
	f.clock.total_minutes += 45.0
	f.grid.set_floor_type(Vector2i(2, 1), 0, CellTypes.FloorType.BASIC)
	f.clock.total_minutes += 30.0
	assert_eq(f.pieces.floor_condition(Vector2i(1, 1), 0), USED, "la primera lleva 75 min")
	assert_eq(f.pieces.floor_condition(Vector2i(2, 1), 0), NEW, "la segunda, 30 min")


func test_marking_a_piece_as_used_is_immediate_and_permanent() -> void:
	var f := _fixture()
	var edge: Edge = Edge.from_side(Vector2i(3, 3), Edge.Side.NORTH)
	f.grid.set_wall(edge, 0, true)
	assert_eq(f.pieces.edge_condition(edge, 0), NEW)
	f.pieces.mark_edge_used(edge, 0)
	assert_eq(f.pieces.edge_condition(edge, 0), USED)
	var cell := Vector2i(5, 5)
	f.grid.set_floor_type(cell, 0, CellTypes.FloorType.BASIC)
	f.pieces.mark_floor_used(cell, 0)
	assert_eq(f.pieces.floor_condition(cell, 0), USED)


func test_removing_a_piece_forgets_it_and_placing_again_starts_fresh() -> void:
	var f := _fixture()
	var cell := Vector2i(4, 4)
	f.grid.set_floor_type(cell, 0, CellTypes.FloorType.BASIC)
	f.pieces.mark_floor_used(cell, 0)
	assert_eq(f.pieces.record_count(), 1)
	f.grid.set_floor_type(cell, 0, CellTypes.FloorType.NONE)
	assert_eq(f.pieces.record_count(), 0)
	f.grid.set_floor_type(cell, 0, CellTypes.FloorType.BASIC)
	assert_eq(f.pieces.floor_condition(cell, 0), NEW, "una pieza colocada de nuevo no hereda el estado de la anterior")


func test_replacing_a_wall_with_a_door_is_a_new_piece() -> void:
	var f := _fixture()
	var edge: Edge = Edge.from_side(Vector2i(3, 3), Edge.Side.WEST)
	f.grid.set_wall(edge, 0, true)
	f.clock.total_minutes += 120.0
	assert_eq(f.pieces.edge_condition(edge, 0), USED)
	f.grid.set_edge_type(edge, 0, CellTypes.EdgeType.DOOR)
	assert_eq(f.pieces.edge_condition(edge, 0), NEW, "la puerta es nueva aunque la pared fuera vieja")
	assert_eq(f.pieces.record_count(), 1, "una sola pieza por arista")
	f.grid.set_edge_type(edge, 0, CellTypes.EdgeType.NONE)
	assert_eq(f.pieces.record_count(), 0)


func test_unknown_pieces_count_as_used_and_levels_are_independent() -> void:
	var f := _fixture()
	assert_eq(f.pieces.floor_condition(Vector2i(6, 6), 0), USED, "sin registro")
	f.grid.add_level(1)
	f.grid.set_floor_type(Vector2i(2, 2), 0, CellTypes.FloorType.BASIC)
	f.grid.set_floor_type(Vector2i(2, 2), 1, CellTypes.FloorType.BASIC)
	f.grid.set_floor_type(Vector2i(2, 2), 0, CellTypes.FloorType.NONE)
	assert_eq(f.pieces.record_count(), 1, "el otro nivel conserva su pieza")
	assert_eq(f.pieces.floor_condition(Vector2i(2, 2), 1), NEW)


func test_building_through_the_game_state_registers_pieces() -> void:
	var state := GameState.new(MAP_SIZE)
	state.build.place_floor(Vector2i(1, 1), 0)
	state.build.place_wall(Edge.from_side(Vector2i(1, 1), Edge.Side.NORTH), 0)
	assert_eq(state.pieces.floor_condition(Vector2i(1, 1), 0), NEW)
	assert_eq(state.pieces.edge_condition(Edge.from_side(Vector2i(1, 1), Edge.Side.NORTH), 0), NEW)
