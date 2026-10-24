extends TestCase
## Pruebas del exterior: catálogo de terrenos, caminar y coste, construir sobre terreno y el
## trazado inicial (calle, acera, césped).

const STREET: StringName = &"street"
const SIDEWALK: StringName = &"sidewalk"
const GRASS: StringName = &"grass"


func _grid(size: Vector2i = Vector2i(16, 10)) -> GridMap2D:
	return GridMap2D.new(size, TerrainCatalog.load_default())


func _paint(grid: GridMap2D, rect: Rect2i, id: StringName) -> void:
	var index: int = grid.terrain.index_of(id)
	for cell: Vector2i in GridShapes.rect_cells(rect):
		grid.set_terrain_index(cell, 0, index)


func _rules() -> EconomyRules:
	var rules := EconomyRules.new()
	rules.start_money = 100000
	return rules


# --- Catálogo ------------------------------------------------------------------------------------

func test_default_file_loads_cleanly() -> void:
	var catalog: TerrainCatalog = TerrainCatalog.load_default()
	assert_eq(catalog.warnings, [] as Array[String], "sin avisos")
	assert_eq(catalog.count(), 4, "tres terrenos más 'sin terreno'")
	assert_eq(catalog.index_of(TerrainCatalog.NONE_ID), 0)
	assert_eq(catalog.index_of(STREET), 1, "los del archivo van en su orden a partir de 1")
	assert_eq(catalog.index_of(GRASS), 3)
	assert_eq(catalog.index_of(&"lava"), -1)
	assert_false(catalog.has_type(&"lava"))


func test_default_terrain_values() -> void:
	var catalog: TerrainCatalog = TerrainCatalog.load_default()
	var street: TerrainType = catalog.get_type(STREET)
	assert_true(street.walkable and not street.buildable)
	assert_near(street.cost, 4.0)
	var sidewalk: TerrainType = catalog.get_type(SIDEWALK)
	assert_true(sidewalk.walkable and not sidewalk.buildable)
	assert_near(sidewalk.cost, 1.0)
	var grass: TerrainType = catalog.get_type(GRASS)
	assert_true(grass.walkable and grass.buildable)
	assert_near(grass.cost, 1.4)
	assert_eq(catalog.get_types().size(), 3, "get_types no incluye 'sin terreno'")


func test_no_terrain_cannot_be_walked_but_can_be_built_on() -> void:
	var catalog := TerrainCatalog.new()
	var none: TerrainType = catalog.get_by_index(0)
	assert_eq(none.id, TerrainCatalog.NONE_ID)
	assert_false(none.walkable)
	assert_true(none.buildable)
	assert_eq(catalog.get_by_index(99), none, "un índice desconocido es 'sin terreno'")
	assert_eq(catalog.get_by_index(-1), none)


func test_bad_entries_are_dropped_with_a_warning() -> void:
	var text: String = '{"terrain_types": [' + ", ".join([
		'{"id": "ok", "name": "Bueno", "color": "#112233", "cost": 1.5}',
		'{"id": "none", "name": "Reservado"}',
		'{"id": "ok", "name": "Repetido"}',
		'{"id": "barato", "name": "Barato", "cost": 0.5}',
		'{"id": "color", "name": "Color", "color": "azul"}',
		'{"id": "caminar", "name": "Caminar", "walkable": "si"}',
		'{"name": "Sin id"}',
		'7',
	]) + ']}'
	var catalog: TerrainCatalog = TerrainCatalog.parse(text)
	assert_eq(catalog.count(), 2, "solo sobrevive la primera")
	assert_true(catalog.has_type(&"ok"))
	assert_eq(catalog.warnings.size(), 7)


func test_broken_files_leave_only_no_terrain() -> void:
	for text: String in ["{ esto no es json", "[1]", '{"terrain_types": 3}']:
		var catalog: TerrainCatalog = TerrainCatalog.parse(text)
		assert_eq(catalog.count(), 1, text)
		assert_eq(catalog.warnings.size(), 1, text)
	var missing: TerrainCatalog = TerrainCatalog.load_file("res://data/no_existe.json", false)
	assert_eq(missing.count(), 1)
	assert_eq(missing.warnings.size(), 1)


# --- Caminar y coste -------------------------------------------------------------------------------

func test_a_grid_without_terrain_only_walks_on_built_floor() -> void:
	var grid := GridMap2D.new(Vector2i(6, 6))
	assert_false(grid.is_walkable(Vector2i(2, 2), 0))
	grid.set_floor_type(Vector2i(2, 2), 0, CellTypes.FloorType.BASIC)
	assert_true(grid.is_walkable(Vector2i(2, 2), 0))
	assert_near(grid.get_walk_cost(Vector2i(2, 2), 0), 1.0)


func test_terrain_makes_cells_walkable_with_its_cost() -> void:
	var grid := _grid()
	_paint(grid, Rect2i(Vector2i(0, 0), Vector2i(16, 3)), GRASS)
	_paint(grid, Rect2i(Vector2i(0, 3), Vector2i(16, 1)), SIDEWALK)
	_paint(grid, Rect2i(Vector2i(0, 4), Vector2i(16, 2)), STREET)
	assert_true(grid.is_walkable(Vector2i(5, 1), 0))
	assert_near(grid.get_walk_cost(Vector2i(5, 1), 0), 1.4)
	assert_near(grid.get_walk_cost(Vector2i(5, 3), 0), 1.0)
	assert_near(grid.get_walk_cost(Vector2i(5, 4), 0), 4.0)
	assert_false(grid.is_walkable(Vector2i(5, 8), 0), "lo que no tiene terreno sigue sin poder pisarse")
	assert_false(grid.is_walkable(Vector2i(-1, 0), 0))
	assert_false(grid.is_walkable(Vector2i(20, 0), 0))


func test_built_floor_costs_one_even_over_grass_or_street() -> void:
	var grid := _grid()
	_paint(grid, Rect2i(Vector2i(0, 0), Vector2i(16, 10)), GRASS)
	grid.set_floor_type(Vector2i(3, 3), 0, CellTypes.FloorType.BASIC)
	assert_near(grid.get_walk_cost(Vector2i(3, 3), 0), 1.0)
	assert_near(grid.get_walk_cost(Vector2i(4, 3), 0), 1.4)


func test_changing_terrain_emits_a_signal_and_bumps_the_revision() -> void:
	var grid := _grid()
	var seen: Array[Vector2i] = []
	grid.terrain_changed.connect(func(cell: Vector2i, _level: int) -> void: seen.append(cell))
	var revision: int = grid.revision
	var grass: int = grid.terrain.index_of(GRASS)
	assert_true(grid.set_terrain_index(Vector2i(2, 2), 0, grass))
	assert_eq(grid.revision, revision + 1)
	assert_false(grid.set_terrain_index(Vector2i(2, 2), 0, grass), "sin cambios no avisa")
	assert_false(grid.set_terrain_index(Vector2i(2, 2), 0, 99), "un terreno que no existe")
	assert_false(grid.set_terrain_index(Vector2i(2, 2), 7, grass), "un nivel que no existe")
	assert_false(grid.set_terrain_index(Vector2i(50, 2), 0, grass), "fuera del mapa")
	assert_eq(seen, [Vector2i(2, 2)] as Array[Vector2i])
	assert_eq(grid.get_terrain_type(Vector2i(2, 2), 0).id, GRASS)


func test_the_pathfinder_avoids_the_street_when_it_can() -> void:
	var grid := _grid(Vector2i(14, 6))
	_paint(grid, Rect2i(Vector2i(0, 0), Vector2i(14, 1)), SIDEWALK)
	_paint(grid, Rect2i(Vector2i(0, 1), Vector2i(14, 1)), STREET)
	_paint(grid, Rect2i(Vector2i(0, 2), Vector2i(14, 1)), SIDEWALK)
	var path: Array[Vector2i] = Pathfinder.find_path(grid, 0, Vector2i(0, 1), Vector2i(12, 1))
	assert_false(path.is_empty())
	var on_street: int = 0
	for cell: Vector2i in path:
		if grid.get_terrain_type(cell, 0).id == STREET:
			on_street += 1
	assert_eq(on_street, 2, "solo pisa la calle al salir y al llegar")


func test_the_street_can_still_be_crossed() -> void:
	var grid := _grid(Vector2i(14, 6))
	_paint(grid, Rect2i(Vector2i(0, 0), Vector2i(14, 1)), SIDEWALK)
	_paint(grid, Rect2i(Vector2i(0, 1), Vector2i(14, 2)), STREET)
	_paint(grid, Rect2i(Vector2i(0, 3), Vector2i(14, 1)), SIDEWALK)
	var path: Array[Vector2i] = Pathfinder.find_path(grid, 0, Vector2i(5, 0), Vector2i(5, 3))
	assert_eq(path.size(), 4, "cruza recto")


# --- Construir -------------------------------------------------------------------------------------

func _state() -> GameState:
	var state := GameState.new_hotel_game(_rules())
	return state


func test_floor_and_walls_can_only_be_built_where_the_terrain_allows() -> void:
	var state := _state()
	var row: int = TerrainGenerator.sidewalk_row_of(state.grid.size)
	assert_true(state.build.place_floor(Vector2i(5, 5), 0), "césped: sí")
	assert_false(state.build.place_floor(Vector2i(5, row), 0), "acera: no")
	assert_false(state.build.place_floor(Vector2i(5, row + 1), 0), "calle: no")
	assert_eq(state.grid.get_floor_type(Vector2i(5, row), 0), CellTypes.FloorType.NONE)
	var balance: int = state.ledger.balance
	assert_eq(state.build.fill_rect_floor(Rect2i(Vector2i(2, row - 2), Vector2i(3, 4)), 0), 6, "solo las dos filas de césped")
	assert_eq(state.ledger.balance, balance - 60, "y solo se cobran esas")
	assert_eq(state.grid.get_floor_type(Vector2i(2, row - 1), 0), CellTypes.FloorType.BASIC)
	assert_eq(state.grid.get_floor_type(Vector2i(2, row), 0), CellTypes.FloorType.NONE)


func test_a_wall_or_door_can_stand_between_grass_and_sidewalk_but_not_between_sidewalk_and_street() -> void:
	var state := _state()
	var row: int = TerrainGenerator.sidewalk_row_of(state.grid.size)
	var grass_to_sidewalk: Edge = Edge.from_side(Vector2i(6, row - 1), Edge.Side.SOUTH)
	assert_true(state.build.place_wall(grass_to_sidewalk, 0))
	assert_true(state.build.place_door(grass_to_sidewalk, 0), "y una puerta ahí mismo")
	var sidewalk_to_street: Edge = Edge.from_side(Vector2i(6, row), Edge.Side.SOUTH)
	assert_false(state.build.place_wall(sidewalk_to_street, 0))
	assert_false(state.build.place_door(sidewalk_to_street, 0))
	assert_eq(state.grid.get_edge_type(sidewalk_to_street, 0), CellTypes.EdgeType.NONE)


func test_removing_is_always_allowed_even_where_building_is_not() -> void:
	var state := _state()
	var row: int = TerrainGenerator.sidewalk_row_of(state.grid.size)
	# Algo construido antes de que existiera esa regla (por ejemplo, una partida antigua).
	state.grid.set_floor_type(Vector2i(8, row), 0, CellTypes.FloorType.BASIC)
	assert_true(state.build.remove_floor(Vector2i(8, row), 0))


# --- Trazado inicial --------------------------------------------------------------------------------

func test_the_default_layout_has_grass_a_sidewalk_and_a_street() -> void:
	var state := _state()
	var size: Vector2i = state.grid.size
	var row: int = TerrainGenerator.sidewalk_row_of(size)
	assert_eq(row, size.y - 3)
	for x: int in [0, size.x / 2, size.x - 1]:
		assert_eq(state.grid.get_terrain_type(Vector2i(x, 0), 0).id, GRASS)
		assert_eq(state.grid.get_terrain_type(Vector2i(x, row - 1), 0).id, GRASS)
		assert_eq(state.grid.get_terrain_type(Vector2i(x, row), 0).id, SIDEWALK)
		assert_eq(state.grid.get_terrain_type(Vector2i(x, row + 1), 0).id, STREET)
		assert_eq(state.grid.get_terrain_type(Vector2i(x, size.y - 1), 0).id, STREET)
	for y in range(size.y):
		for x in range(size.x):
			assert_true(state.grid.is_walkable(Vector2i(x, y), 0), "todo el mapa se puede pisar")


func test_the_hotel_game_registers_the_two_arrival_points() -> void:
	var state := _state()
	var cells: Array[Vector2i] = TerrainGenerator.arrival_cells(state.grid.size)
	assert_eq(cells.size(), 2)
	assert_eq(state.entrances.get_valid(0), cells)
	for cell: Vector2i in cells:
		assert_eq(state.grid.get_terrain_type(cell, 0).id, SIDEWALK)


func test_the_layout_needs_the_terrains_and_enough_room() -> void:
	assert_false(TerrainGenerator.apply_default_layout(GridMap2D.new(Vector2i(20, 20)), 0), "sin catálogo")
	assert_false(TerrainGenerator.apply_default_layout(_grid(Vector2i(20, 4)), 0), "mapa demasiado bajo")
	assert_false(TerrainGenerator.apply_default_layout(_grid(), 3), "nivel inexistente")
	assert_true(TerrainGenerator.apply_default_layout(_grid(), 0))


func test_a_plain_game_state_has_no_terrain() -> void:
	var state := GameState.new(Vector2i(10, 8))
	assert_false(state.grid.is_walkable(Vector2i(3, 3), 0))
	assert_true(state.build.place_floor(Vector2i(3, 3), 0), "y se construye en cualquier sitio")
