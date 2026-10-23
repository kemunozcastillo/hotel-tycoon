extends TestCase
## Pruebas de LevelView con el modo de paredes: qué tile se muestra en cada celda, la actualización
## incremental y su equivalencia con un redibujado completo.

const MAP_SIZE := Vector2i(14, 12)
const ROOM := Rect2i(Vector2i(4, 4), Vector2i(3, 3))

const WALL := CellTypes.EdgeType.WALL
const DOOR := CellTypes.EdgeType.DOOR
const NONE := CellTypes.EdgeType.NONE
const FULL := WallStyle.Height.FULL
const LOW := WallStyle.Height.LOW
const FLAT := WallStyle.Height.FLAT


func _view_for(state: GameState) -> LevelView:
	var view := LevelView.new()
	view.setup(state.grid, 0)
	return view


## Lo que muestra cada celda (incluida la fila y la columna de cierre del mapa).
func _snapshot(view: LevelView, size: Vector2i) -> Dictionary:
	var result: Dictionary = {}
	for y in range(size.y + 1):
		for x in range(size.x + 1):
			result[Vector2i(x, y)] = view.get_wall_coords(Vector2i(x, y))
	return result


func _coords(type_x: CellTypes.EdgeType, height_x: WallStyle.Height, type_y: CellTypes.EdgeType, height_y: WallStyle.Height) -> Vector2i:
	return TilesetFactory.wall_coords(type_x, height_x, type_y, height_y)


# --- Qué se muestra ------------------------------------------------------------------------------

func test_default_mode_is_cutaway_and_shows_front_walls_low() -> void:
	var state := GameState.new(MAP_SIZE)
	state.build.build_room(ROOM, 0)
	var view: LevelView = _view_for(state)
	assert_eq(view.get_wall_mode(), WallViewMode.Mode.CUTAWAY)
	assert_eq(view.get_wall_coords(Vector2i(4, 4)), _coords(WALL, FULL, WALL, FULL), "esquina norte-oeste: dos paredes del fondo")
	assert_eq(view.get_wall_coords(Vector2i(5, 4)), _coords(WALL, FULL, NONE, FULL), "pared norte")
	assert_eq(view.get_wall_coords(Vector2i(4, 7)), _coords(WALL, LOW, NONE, FULL), "pared sur, baja")
	assert_eq(view.get_wall_coords(Vector2i(7, 4)), _coords(NONE, FULL, WALL, LOW), "pared este, baja")
	assert_eq(view.get_wall_coords(Vector2i(8, 8)), Vector2i(-1, -1), "sin nada")
	view.free()


func test_switching_modes_redraws_with_the_new_heights_and_emits_once() -> void:
	var state := GameState.new(MAP_SIZE)
	state.build.build_room(ROOM, 0)
	var view: LevelView = _view_for(state)
	var emitted: Array[int] = []
	view.wall_mode_changed.connect(func(mode: WallViewMode.Mode) -> void: emitted.append(mode))

	view.set_wall_mode(WallViewMode.Mode.UP)
	assert_eq(view.get_wall_coords(Vector2i(4, 7)), _coords(WALL, FULL, NONE, FULL), "arriba: la pared sur completa")
	view.set_wall_mode(WallViewMode.Mode.LOW)
	assert_eq(view.get_wall_coords(Vector2i(4, 4)), _coords(WALL, LOW, WALL, LOW), "bajas: también las del fondo")
	view.set_wall_mode(WallViewMode.Mode.DOWN)
	assert_eq(view.get_wall_coords(Vector2i(4, 4)), _coords(WALL, FLAT, WALL, FLAT), "ocultas: solo la línea de la base")
	view.set_wall_mode(WallViewMode.Mode.DOWN)
	view.set_wall_mode(WallViewMode.Mode.CUTAWAY)
	assert_eq(view.get_wall_coords(Vector2i(4, 7)), _coords(WALL, LOW, NONE, FULL), "y al volver al corte, como al principio")
	assert_eq(emitted, [WallViewMode.Mode.UP, WallViewMode.Mode.LOW, WallViewMode.Mode.DOWN, WallViewMode.Mode.CUTAWAY] as Array[int], "una señal por cambio real")
	view.free()


func test_doors_follow_the_same_heights() -> void:
	var state := GameState.new(MAP_SIZE)
	state.build.build_room(ROOM, 0)
	state.build.place_door(Edge.from_side(Vector2i(5, 6), Edge.Side.SOUTH), 0)
	state.build.place_door(Edge.from_side(Vector2i(5, 4), Edge.Side.NORTH), 0)
	var view: LevelView = _view_for(state)
	assert_eq(view.get_wall_coords(Vector2i(5, 7)), _coords(DOOR, LOW, NONE, FULL), "puerta delantera, baja")
	assert_eq(view.get_wall_coords(Vector2i(5, 4)), _coords(DOOR, FULL, NONE, FULL), "puerta del fondo, completa")
	view.set_wall_mode(WallViewMode.Mode.DOWN)
	assert_eq(view.get_wall_coords(Vector2i(5, 7)), _coords(DOOR, FLAT, NONE, FULL))
	view.free()


# --- Actualización incremental ---------------------------------------------------------------------

func test_floor_changes_update_only_what_depends_on_them_in_cutaway() -> void:
	var state := GameState.new(MAP_SIZE)
	state.build.outline_rect_walls(ROOM, 0) # paredes sin suelo
	var view: LevelView = _view_for(state)
	assert_eq(view.get_wall_coords(Vector2i(4, 7)), _coords(WALL, FULL, NONE, FULL), "sin suelo detrás, completa")
	assert_eq(view.get_wall_coords(Vector2i(7, 4)), _coords(NONE, FULL, WALL, FULL))

	state.build.fill_rect_floor(ROOM, 0)
	assert_eq(view.get_wall_coords(Vector2i(4, 7)), _coords(WALL, LOW, NONE, FULL), "con suelo detrás, baja (arista X)")
	assert_eq(view.get_wall_coords(Vector2i(7, 4)), _coords(NONE, FULL, WALL, LOW), "y también la arista Y")
	assert_eq(view.get_wall_coords(Vector2i(4, 4)), _coords(WALL, FULL, WALL, FULL), "las del fondo no cambian")

	state.build.remove_floor(Vector2i(4, 6), 0)
	assert_eq(view.get_wall_coords(Vector2i(4, 7)), _coords(WALL, FULL, NONE, FULL), "al quitar el suelo de atrás, vuelve a ser completa")
	assert_eq(view.get_wall_coords(Vector2i(5, 7)), _coords(WALL, LOW, NONE, FULL), "pero la de la celda de al lado sigue baja")
	view.free()


func test_floor_changes_do_not_matter_in_the_other_modes() -> void:
	var state := GameState.new(MAP_SIZE)
	state.build.outline_rect_walls(ROOM, 0)
	var view: LevelView = _view_for(state)
	view.set_wall_mode(WallViewMode.Mode.UP)
	state.build.fill_rect_floor(ROOM, 0)
	assert_eq(view.get_wall_coords(Vector2i(4, 7)), _coords(WALL, FULL, NONE, FULL), "en modo Arriba el suelo no cambia las alturas")
	view.set_wall_mode(WallViewMode.Mode.CUTAWAY)
	assert_eq(view.get_wall_coords(Vector2i(4, 7)), _coords(WALL, LOW, NONE, FULL), "y al pasar a Corte se ve con el suelo ya puesto")
	view.free()


func test_edge_changes_are_drawn_with_the_current_mode() -> void:
	var state := GameState.new(MAP_SIZE)
	state.build.fill_rect_floor(ROOM, 0)
	var view: LevelView = _view_for(state)
	state.build.place_wall(Edge.from_side(Vector2i(5, 6), Edge.Side.SOUTH), 0)
	assert_eq(view.get_wall_coords(Vector2i(5, 7)), _coords(WALL, LOW, NONE, FULL), "pared nueva delante de un suelo")
	state.build.place_wall(Edge.from_side(Vector2i(5, 4), Edge.Side.NORTH), 0)
	assert_eq(view.get_wall_coords(Vector2i(5, 4)), _coords(WALL, FULL, NONE, FULL), "pared nueva al fondo")
	state.build.remove_wall(Edge.from_side(Vector2i(5, 6), Edge.Side.SOUTH), 0)
	assert_eq(view.get_wall_coords(Vector2i(5, 7)), Vector2i(-1, -1), "al quitarla desaparece")
	view.free()


# --- Equivalencia con un redibujado completo -----------------------------------------------------------

func test_incremental_updates_always_match_a_full_redraw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var size := Vector2i(12, 10)
	var state: GameState = GridTestHelpers.random_state(rng, size)
	var view: LevelView = _view_for(state)
	var modes: Array[WallViewMode.Mode] = [WallViewMode.Mode.UP, WallViewMode.Mode.CUTAWAY, WallViewMode.Mode.LOW, WallViewMode.Mode.DOWN]
	var comparisons: int = 0
	for step in range(300):
		var roll: int = rng.randi_range(0, 9)
		var cell := Vector2i(rng.randi_range(0, size.x - 1), rng.randi_range(0, size.y - 1))
		var edge := Edge.new(Vector2i(rng.randi_range(0, size.x), rng.randi_range(0, size.y)),
				Edge.Axis.X if rng.randf() < 0.5 else Edge.Axis.Y)
		match roll:
			0, 1, 2:
				state.build.place_floor(cell, 0)
			3, 4:
				state.build.remove_floor(cell, 0)
			5:
				state.build.place_wall(edge, 0)
			6:
				state.build.remove_wall(edge, 0)
			7:
				state.build.place_door(edge, 0)
			8:
				state.build.clear_edge(edge, 0)
			_:
				view.set_wall_mode(modes[rng.randi_range(0, modes.size() - 1)])
		if step % 10 == 9:
			var fresh: LevelView = _view_for(state)
			fresh.set_wall_mode(view.get_wall_mode())
			var expected: Dictionary = _snapshot(fresh, size)
			var actual: Dictionary = _snapshot(view, size)
			fresh.free()
			var mismatches: int = 0
			for key: Vector2i in expected.keys():
				if expected[key] != actual[key]:
					mismatches += 1
			assert_eq(mismatches, 0, "paso %d (modo %d): la vista incremental difiere de un redibujado" % [step, view.get_wall_mode()])
			comparisons += 1
	assert_eq(comparisons, 30)
	view.free()
