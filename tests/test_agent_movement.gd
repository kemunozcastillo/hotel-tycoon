extends TestCase
## Pruebas de AgentRegistry: creación, rutas, movimiento, replanificación y bloqueo.

const MAP_SIZE := Vector2i(12, 8)
const SPEED: float = Agent.DEFAULT_SPEED # celdas por minuto de juego


func _open_state(size: Vector2i = MAP_SIZE) -> GameState:
	var state := GameState.new(size)
	state.build.fill_rect_floor(Rect2i(Vector2i.ZERO, size), 0)
	return state


func _center(cell: Vector2i) -> Vector2:
	return Vector2(cell) + Vector2(0.5, 0.5)


# --- Creación -------------------------------------------------------------------------------

func test_spawn_places_agent_at_cell_center() -> void:
	var state := _open_state()
	var added: Array[Agent] = []
	state.agents.agent_added.connect(func(agent: Agent) -> void: added.append(agent))
	var agent: Agent = state.agents.spawn(Vector2i(2, 3), 0)
	assert_true(agent != null)
	assert_eq(agent.id, 1)
	assert_eq(agent.position, Vector2(2.5, 3.5))
	assert_eq(agent.get_cell(), Vector2i(2, 3))
	assert_eq(agent.state, Agent.State.IDLE)
	assert_false(agent.has_destination)
	assert_near(agent.speed, SPEED)
	assert_eq(added.size(), 1)
	assert_eq(state.agents.spawn(Vector2i(4, 4), 0).id, 2, "ids correlativos")
	assert_eq(state.agents.get_agents().size(), 2)
	assert_eq(state.agents.get_agent_at(Vector2i(2, 3), 0), agent)
	assert_eq(state.agents.get_agent_at(Vector2i(9, 9), 0), null)


func test_spawn_rejects_cells_that_cannot_be_walked() -> void:
	var state := GameState.new(MAP_SIZE)
	state.build.place_floor(Vector2i(1, 1), 0)
	assert_eq(state.agents.spawn(Vector2i(5, 5), 0), null, "sin suelo")
	assert_eq(state.agents.spawn(Vector2i(-1, 0), 0), null, "fuera del mapa")
	assert_eq(state.agents.spawn(Vector2i(1, 1), 4), null, "nivel inexistente")
	assert_true(state.agents.spawn(Vector2i(1, 1), 0) != null)


func test_remove_agent() -> void:
	var state := _open_state()
	var removed: Array[Agent] = []
	state.agents.agent_removed.connect(func(agent: Agent) -> void: removed.append(agent))
	var agent: Agent = state.agents.spawn(Vector2i(1, 1), 0)
	assert_true(state.agents.remove(agent.id))
	assert_false(state.agents.remove(agent.id), "ya no existe")
	assert_eq(removed.size(), 1)
	assert_eq(state.agents.get_agent(agent.id), null)


# --- Destinos --------------------------------------------------------------------------------

func test_unreachable_destination_is_rejected_and_changes_nothing() -> void:
	var state := _open_state()
	state.build.outline_rect_walls(Rect2i(Vector2i(6, 2), Vector2i(2, 2)), 0)
	var agent: Agent = state.agents.spawn(Vector2i(0, 0), 0)
	assert_false(state.agents.set_destination(agent.id, Vector2i(6, 2)), "encerrada")
	assert_false(state.agents.set_destination(agent.id, Vector2i(30, 30)), "fuera del mapa")
	assert_false(state.agents.set_destination(999, Vector2i(1, 1)), "agente que no existe")
	assert_eq(agent.state, Agent.State.IDLE)
	assert_false(agent.has_destination)
	assert_eq(agent.path.size(), 0)


func test_set_destination_starts_walking_and_emits() -> void:
	var state := _open_state()
	var agent: Agent = state.agents.spawn(Vector2i(0, 0), 0)
	var events: Array[int] = []
	state.agents.agent_state_changed.connect(func(changed: Agent) -> void: events.append(changed.state))
	assert_true(state.agents.set_destination(agent.id, Vector2i(4, 0)))
	assert_eq(agent.state, Agent.State.WALKING)
	assert_true(agent.has_destination)
	assert_eq(agent.destination, Vector2i(4, 0))
	assert_eq(agent.path, [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)] as Array[Vector2i])
	assert_eq(events, [Agent.State.WALKING] as Array[int])


# --- Movimiento ------------------------------------------------------------------------------

func test_walking_speed_is_cells_per_game_minute() -> void:
	var state := _open_state()
	var agent: Agent = state.agents.spawn(Vector2i(0, 0), 0)
	state.agents.set_destination(agent.id, Vector2i(6, 0))
	state.agents.tick(0.25)
	assert_near(agent.position.x, 0.5 + 0.5, "", 0.0001)
	state.agents.tick(0.75)
	assert_near(agent.position.x, 0.5 + 2.0, "tras un minuto: 2 celdas", 0.0001)
	assert_near(agent.position.y, 0.5)
	assert_eq(agent.state, Agent.State.WALKING)


func test_arrival_stops_exactly_on_the_destination_center() -> void:
	var state := _open_state()
	var agent: Agent = state.agents.spawn(Vector2i(0, 0), 0)
	var states: Array[int] = []
	state.agents.agent_state_changed.connect(func(changed: Agent) -> void: states.append(changed.state))
	state.agents.set_destination(agent.id, Vector2i(4, 0))
	state.agents.tick(100.0) # un tick enorme no debe pasarse del destino
	assert_eq(agent.position, _center(Vector2i(4, 0)))
	assert_eq(agent.state, Agent.State.IDLE)
	assert_false(agent.has_destination)
	assert_eq(agent.path.size(), 0)
	assert_eq(states, [Agent.State.WALKING, Agent.State.IDLE] as Array[int])
	state.agents.tick(5.0)
	assert_eq(agent.position, _center(Vector2i(4, 0)), "ya quieto")


func test_diagonal_movement_has_the_same_speed() -> void:
	var state := _open_state()
	var agent: Agent = state.agents.spawn(Vector2i(0, 0), 0)
	state.agents.set_destination(agent.id, Vector2i(4, 4))
	state.agents.tick(1.0)
	assert_near(agent.position.distance_to(_center(Vector2i(0, 0))), SPEED, "dos celdas de recorrido", 0.0001)
	assert_near(agent.position.x, agent.position.y, "sigue sobre la diagonal", 0.0001)


func test_destination_equal_to_current_cell_walks_to_its_center() -> void:
	var state := _open_state()
	var agent: Agent = state.agents.spawn(Vector2i(3, 3), 0)
	agent.position = Vector2(3.9, 3.1)
	assert_true(state.agents.set_destination(agent.id, Vector2i(3, 3)))
	state.agents.tick(1.0)
	assert_eq(agent.position, _center(Vector2i(3, 3)))
	assert_eq(agent.state, Agent.State.IDLE)


func test_stop_cancels_the_walk() -> void:
	var state := _open_state()
	var agent: Agent = state.agents.spawn(Vector2i(0, 0), 0)
	state.agents.set_destination(agent.id, Vector2i(8, 0))
	state.agents.tick(0.5)
	var stopped_at: Vector2 = agent.position
	state.agents.stop(agent.id)
	assert_eq(agent.state, Agent.State.IDLE)
	assert_false(agent.has_destination)
	state.agents.tick(5.0)
	assert_eq(agent.position, stopped_at)


func test_zero_or_negative_time_changes_nothing() -> void:
	var state := _open_state()
	var agent: Agent = state.agents.spawn(Vector2i(0, 0), 0)
	state.agents.set_destination(agent.id, Vector2i(5, 0))
	state.agents.tick(0.0)
	state.agents.tick(-3.0)
	assert_eq(agent.position, _center(Vector2i(0, 0)))


func test_walks_through_a_door_and_not_through_walls() -> void:
	var state := _open_state()
	var rect := Rect2i(Vector2i(4, 2), Vector2i(3, 3))
	state.build.outline_rect_walls(rect, 0)
	var door: Edge = Edge.from_side(Vector2i(5, 4), Edge.Side.SOUTH)
	state.build.place_door(door, 0)
	var agent: Agent = state.agents.spawn(Vector2i(5, 3), 0) # dentro de la habitación
	assert_true(state.agents.set_destination(agent.id, Vector2i(5, 7)))
	var crossed_door: bool = false
	var previous: Vector2i = agent.get_cell()
	for i in range(200):
		state.agents.tick(0.05)
		var cell: Vector2i = agent.get_cell()
		if cell != previous:
			var edge: Edge = Edge.between(previous, cell)
			if edge != null and edge.is_equal(door):
				crossed_door = true
			assert_true(Pathfinder.is_step_legal(state.grid, 0, previous, cell), "paso legal %s -> %s" % [str(previous), str(cell)])
			previous = cell
		if agent.state == Agent.State.IDLE:
			break
	assert_true(crossed_door, "sale por la puerta")
	assert_eq(agent.get_cell(), Vector2i(5, 7))


# --- Cambios del mapa ------------------------------------------------------------------------

func test_new_wall_across_the_path_makes_the_agent_detour() -> void:
	var state := _open_state(Vector2i(12, 5))
	var agent: Agent = state.agents.spawn(Vector2i(0, 2), 0)
	state.agents.set_destination(agent.id, Vector2i(11, 2))
	state.agents.tick(1.0) # avanza 2 celdas
	# Pared entre las columnas 5 y 6 con un hueco solo en la fila 4.
	for y in range(0, 4):
		state.build.place_wall(Edge.from_side(Vector2i(5, y), Edge.Side.EAST), 0)
	state.agents.tick(0.01)
	assert_eq(agent.state, Agent.State.WALKING, "recalculó y sigue")
	var steps: int = 0
	while agent.state == Agent.State.WALKING and steps < 2000:
		state.agents.tick(0.05)
		steps += 1
		assert_true(state.grid.is_walkable(agent.get_cell(), 0))
	assert_eq(agent.state, Agent.State.IDLE)
	assert_eq(agent.get_cell(), Vector2i(11, 2))


func test_destination_that_becomes_unreachable_blocks_and_then_resumes() -> void:
	var state := _open_state(Vector2i(12, 3))
	var agent: Agent = state.agents.spawn(Vector2i(0, 1), 0)
	state.agents.set_destination(agent.id, Vector2i(11, 1))
	state.agents.tick(0.5)
	for y in range(3):
		state.build.place_wall(Edge.from_side(Vector2i(6, y), Edge.Side.EAST), 0)
	var events: Array[int] = []
	state.agents.agent_state_changed.connect(func(changed: Agent) -> void: events.append(changed.state))
	state.agents.tick(0.1)
	assert_eq(agent.state, Agent.State.BLOCKED)
	assert_true(agent.has_destination, "recuerda el destino")
	var blocked_at: Vector2 = agent.position
	state.agents.tick(3.0)
	assert_eq(agent.position, blocked_at, "bloqueado no se mueve")
	assert_eq(events, [Agent.State.BLOCKED] as Array[int], "avisa una sola vez")

	# Se abre una puerta en la pared: reanuda sin que nadie le dé otra orden.
	state.build.place_door(Edge.from_side(Vector2i(6, 1), Edge.Side.EAST), 0)
	state.agents.tick(0.1)
	assert_eq(agent.state, Agent.State.WALKING)
	state.agents.tick(50.0)
	assert_eq(agent.state, Agent.State.IDLE)
	assert_eq(agent.get_cell(), Vector2i(11, 1))


func test_destination_that_loses_its_floor_blocks_the_agent() -> void:
	var state := _open_state()
	var agent: Agent = state.agents.spawn(Vector2i(0, 0), 0)
	state.agents.set_destination(agent.id, Vector2i(8, 4))
	state.agents.tick(0.2)
	state.build.remove_floor(Vector2i(8, 4), 0)
	state.agents.tick(0.1)
	assert_eq(agent.state, Agent.State.BLOCKED)
	state.build.place_floor(Vector2i(8, 4), 0)
	state.agents.tick(0.1)
	assert_eq(agent.state, Agent.State.WALKING, "al volver el suelo, reanuda")


func test_agent_standing_on_removed_floor_can_still_leave() -> void:
	var state := _open_state()
	var agent: Agent = state.agents.spawn(Vector2i(3, 3), 0)
	state.build.remove_floor(Vector2i(3, 3), 0)
	assert_true(state.agents.set_destination(agent.id, Vector2i(6, 3)))
	state.agents.tick(10.0)
	assert_eq(agent.get_cell(), Vector2i(6, 3))


func test_removing_an_agent_mid_walk_is_safe() -> void:
	var state := _open_state()
	var agent: Agent = state.agents.spawn(Vector2i(0, 0), 0)
	state.agents.set_destination(agent.id, Vector2i(9, 0))
	state.agents.tick(0.5)
	state.agents.remove(agent.id)
	state.agents.tick(5.0)
	assert_eq(state.agents.get_agents().size(), 0)


func test_unrelated_map_changes_do_not_replan() -> void:
	var state := _open_state()
	var agent: Agent = state.agents.spawn(Vector2i(0, 0), 0)
	state.agents.set_destination(agent.id, Vector2i(9, 0))
	var original_path: Array[Vector2i] = agent.path.duplicate()
	var events: Array[int] = []
	state.agents.agent_state_changed.connect(func(changed: Agent) -> void: events.append(changed.state))
	state.build.place_wall(Edge.from_side(Vector2i(4, 6), Edge.Side.EAST), 0) # lejos de la ruta
	state.agents.tick(0.1)
	assert_eq(events.size(), 0, "sin avisos: la ruta sigue siendo válida")
	assert_eq(agent.path.size(), original_path.size() - 0, "la ruta se conserva")


# --- Invariantes sobre mapas aleatorios ---------------------------------------------------------

func test_agents_never_leave_walkable_cells_or_cross_walls_on_random_maps() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 987654
	var arrivals: int = 0
	for map_index in range(8):
		var state: GameState = GridTestHelpers.random_state(rng, Vector2i(12, 10))
		var cells: Array[Vector2i] = GridTestHelpers.walkable_cells(state.grid)
		if cells.size() < 10:
			continue
		var agent: Agent = state.agents.spawn(cells[rng.randi_range(0, cells.size() - 1)], 0)
		for trip in range(10):
			var target: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
			var expected_path: Array[Vector2i] = Pathfinder.find_path(state.grid, 0, agent.get_cell(), target)
			if not state.agents.set_destination(agent.id, target):
				assert_eq(expected_path.size(), 0, "set_destination solo falla si no hay ruta")
				continue
			var expected_minutes: float = Pathfinder.path_cost(state.grid, 0, expected_path) / SPEED
			var previous: Vector2i = agent.get_cell()
			var elapsed: float = 0.0
			while agent.state == Agent.State.WALKING and elapsed < 100.0:
				state.agents.tick(0.05)
				elapsed += 0.05
				var cell: Vector2i = agent.get_cell()
				assert_true(state.grid.is_walkable(cell, 0), "mapa %d: pisa %s" % [map_index, str(cell)])
				if cell != previous:
					assert_true(Pathfinder.is_step_legal(state.grid, 0, previous, cell), "mapa %d: paso %s -> %s" % [map_index, str(previous), str(cell)])
					previous = cell
			assert_eq(agent.state, Agent.State.IDLE, "mapa %d: llegó" % map_index)
			assert_eq(agent.get_cell(), target)
			# Parte del centro de su celda, así que tarda justo coste/velocidad (con holgura de un tick).
			assert_true(absf(elapsed - expected_minutes) <= 0.051, "mapa %d: tardó %.2f y se esperaba %.2f" % [map_index, elapsed, expected_minutes])
			arrivals += 1
	assert_true(arrivals > 30, "se completaron suficientes viajes (%d)" % arrivals)
