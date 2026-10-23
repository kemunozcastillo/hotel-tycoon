extends TestCase
## Pruebas de la altura de las paredes según el modo (lógica pura) y de los modos de visualización.

const MAP_SIZE := Vector2i(14, 12)
const ROOM := Rect2i(Vector2i(4, 4), Vector2i(3, 3)) # celdas x 4..6, y 4..6


func _room_state() -> GameState:
	var state := GameState.new(MAP_SIZE)
	state.build.build_room(ROOM, 0)
	return state


func _height(state: GameState, edge: Edge, mode: WallViewMode.Mode) -> WallStyle.Height:
	return WallVisibility.height_for(state.grid, 0, edge, mode)


# --- Modos ---------------------------------------------------------------------------------

func test_modes_cycle_through_all_four_and_come_back() -> void:
	var mode: WallViewMode.Mode = WallViewMode.Mode.UP
	var seen: Array[int] = []
	for i in range(WallViewMode.MODE_COUNT):
		seen.append(mode)
		mode = WallViewMode.next(mode)
	assert_eq(mode, WallViewMode.Mode.UP, "tras cuatro cambios vuelve al principio")
	assert_eq(seen, [WallViewMode.Mode.UP, WallViewMode.Mode.CUTAWAY, WallViewMode.Mode.LOW, WallViewMode.Mode.DOWN] as Array[int])
	assert_eq(WallViewMode.default_mode(), WallViewMode.Mode.CUTAWAY, "se arranca en modo corte")


func test_labels_are_distinct_and_in_spanish() -> void:
	var labels: Dictionary = {}
	for mode: int in [WallViewMode.Mode.UP, WallViewMode.Mode.CUTAWAY, WallViewMode.Mode.LOW, WallViewMode.Mode.DOWN]:
		labels[WallViewMode.label(mode as WallViewMode.Mode)] = true
	assert_eq(labels.size(), 4)
	assert_eq(WallViewMode.label(WallViewMode.Mode.CUTAWAY), "Corte")


# --- Modos uniformes ---------------------------------------------------------------------------

func test_up_low_and_down_ignore_the_map() -> void:
	var state := _room_state()
	for edge: Edge in GridShapes.rect_perimeter(ROOM):
		assert_eq(_height(state, edge, WallViewMode.Mode.UP), WallStyle.Height.FULL)
		assert_eq(_height(state, edge, WallViewMode.Mode.LOW), WallStyle.Height.LOW)
		assert_eq(_height(state, edge, WallViewMode.Mode.DOWN), WallStyle.Height.FLAT)
	var far := Edge.new(Vector2i(0, 0), Edge.Axis.Y)
	assert_eq(_height(state, far, WallViewMode.Mode.UP), WallStyle.Height.FULL, "también sobre aristas sin nada")


# --- Corte -------------------------------------------------------------------------------------

func test_cutaway_lowers_the_front_walls_of_a_room_and_keeps_the_back_ones() -> void:
	var state := _room_state()
	var cut: WallViewMode.Mode = WallViewMode.Mode.CUTAWAY
	for x in range(4, 7):
		assert_eq(_height(state, Edge.from_side(Vector2i(x, 4), Edge.Side.NORTH), cut), WallStyle.Height.FULL, "norte de (%d,4): fondo" % x)
		assert_eq(_height(state, Edge.from_side(Vector2i(x, 6), Edge.Side.SOUTH), cut), WallStyle.Height.LOW, "sur de (%d,6): delante" % x)
	for y in range(4, 7):
		assert_eq(_height(state, Edge.from_side(Vector2i(4, y), Edge.Side.WEST), cut), WallStyle.Height.FULL, "oeste de (4,%d): fondo" % y)
		assert_eq(_height(state, Edge.from_side(Vector2i(6, y), Edge.Side.EAST), cut), WallStyle.Height.LOW, "este de (6,%d): delante" % y)


func test_cutaway_shared_wall_between_two_rooms_is_low() -> void:
	var state := GameState.new(MAP_SIZE)
	state.build.build_room(Rect2i(Vector2i(2, 2), Vector2i(3, 2)), 0)
	state.build.build_room(Rect2i(Vector2i(2, 4), Vector2i(3, 2)), 0) # justo debajo (al sur)
	var shared: Edge = Edge.from_side(Vector2i(3, 3), Edge.Side.SOUTH) # sur del primero = norte del segundo
	assert_true(state.grid.has_wall(shared, 0))
	assert_eq(_height(state, shared, WallViewMode.Mode.CUTAWAY), WallStyle.Height.LOW, "tapa la habitación de atrás")
	var side_shared: Edge = Edge.from_side(Vector2i(4, 2), Edge.Side.EAST)
	state.build.build_room(Rect2i(Vector2i(5, 2), Vector2i(3, 2)), 0) # a la derecha (al este)
	assert_eq(_height(state, side_shared, WallViewMode.Mode.CUTAWAY), WallStyle.Height.LOW)


func test_cutaway_keeps_everything_tall_when_there_is_no_floor_to_reveal() -> void:
	var state := GameState.new(MAP_SIZE)
	state.build.outline_rect_walls(ROOM, 0) # solo paredes, sin suelo dentro
	for edge: Edge in GridShapes.rect_perimeter(ROOM):
		assert_eq(_height(state, edge, WallViewMode.Mode.CUTAWAY), WallStyle.Height.FULL)


func test_cutaway_uses_the_same_rule_for_doors_and_follows_the_floor() -> void:
	var state := _room_state()
	var south_door: Edge = Edge.from_side(Vector2i(5, 6), Edge.Side.SOUTH)
	state.build.place_door(south_door, 0)
	assert_eq(_height(state, south_door, WallViewMode.Mode.CUTAWAY), WallStyle.Height.LOW, "una puerta al frente baja igual")
	state.build.remove_floor(Vector2i(5, 6), 0)
	assert_eq(_height(state, south_door, WallViewMode.Mode.CUTAWAY), WallStyle.Height.FULL, "sin suelo detrás ya no tapa nada")


func test_cutaway_on_the_map_border() -> void:
	var state := GameState.new(Vector2i(6, 5))
	state.build.fill_rect_floor(Rect2i(Vector2i.ZERO, Vector2i(6, 5)), 0)
	state.build.outline_rect_walls(Rect2i(Vector2i.ZERO, Vector2i(6, 5)), 0)
	var cut: WallViewMode.Mode = WallViewMode.Mode.CUTAWAY
	assert_eq(_height(state, Edge.new(Vector2i(2, 0), Edge.Axis.X), cut), WallStyle.Height.FULL, "borde norte: detrás está fuera del mapa")
	assert_eq(_height(state, Edge.new(Vector2i(0, 2), Edge.Axis.Y), cut), WallStyle.Height.FULL, "borde oeste")
	assert_eq(_height(state, Edge.new(Vector2i(2, 5), Edge.Axis.X), cut), WallStyle.Height.LOW, "borde sur: detrás hay suelo")
	assert_eq(_height(state, Edge.new(Vector2i(6, 2), Edge.Axis.Y), cut), WallStyle.Height.LOW, "borde este")


# --- Celdas detrás y dependientes ------------------------------------------------------------------

func test_cell_behind() -> void:
	assert_eq(WallVisibility.cell_behind(Edge.new(Vector2i(5, 5), Edge.Axis.X)), Vector2i(5, 4), "norte")
	assert_eq(WallVisibility.cell_behind(Edge.new(Vector2i(5, 5), Edge.Axis.Y)), Vector2i(4, 5), "oeste")


func test_dependent_wall_cells_are_exactly_those_whose_edges_have_the_cell_behind() -> void:
	for cell: Vector2i in [Vector2i(0, 0), Vector2i(3, 7), Vector2i(-2, 4)]:
		var dependents: Array[Vector2i] = WallVisibility.dependent_wall_cells(cell)
		assert_eq(dependents.size(), 2)
		# Se comprueba contra una búsqueda exhaustiva en el entorno de la celda.
		var found: Array[Vector2i] = []
		for dy in range(-2, 4):
			for dx in range(-2, 4):
				var owner: Vector2i = cell + Vector2i(dx, dy)
				for axis: Edge.Axis in [Edge.Axis.X, Edge.Axis.Y]:
					if WallVisibility.cell_behind(Edge.new(owner, axis)) == cell and not found.has(owner):
						found.append(owner)
		found.sort()
		var sorted_dependents: Array[Vector2i] = dependents.duplicate()
		sorted_dependents.sort()
		assert_eq(sorted_dependents, found, "dependientes de %s" % str(cell))
