extends TestCase
## Pruebas del paseo provisional y de la integración de los agentes con el reloj de GameState.

const MAP_SIZE := Vector2i(14, 12)


func _open_state(seed_value: int = 1) -> GameState:
	var state := GameState.new(MAP_SIZE)
	state.build.fill_rect_floor(Rect2i(Vector2i.ZERO, MAP_SIZE), 0)
	state.wander.set_seed(seed_value)
	return state


## Avanza `minutes` minutos de juego a x1 en pasos de 0.1 s reales.
func _run(state: GameState, minutes: float) -> void:
	var steps: int = roundi(minutes / 0.1)
	for i in range(steps):
		state.tick(0.1)


# --- Paseo -------------------------------------------------------------------------------

func test_idle_agent_waits_before_its_first_walk() -> void:
	var state := _open_state()
	var agent: Agent = state.agents.spawn(Vector2i(6, 6), 0)
	_run(state, WanderBehavior.MIN_WAIT - 0.2)
	assert_eq(agent.state, Agent.State.IDLE, "todavía espera")
	assert_eq(agent.position, Vector2(6.5, 6.5))


func test_agent_wanders_to_many_places_and_stays_on_floor() -> void:
	var state := _open_state()
	var agent: Agent = state.agents.spawn(Vector2i(6, 6), 0)
	var visited: Dictionary = {}
	var walking_seen: bool = false
	for i in range(3000):
		state.tick(0.1)
		visited[agent.get_cell()] = true
		walking_seen = walking_seen or agent.state == Agent.State.WALKING
		assert_true(state.grid.is_walkable(agent.get_cell(), 0), "siempre sobre suelo")
	assert_true(walking_seen)
	assert_true(visited.size() > 40, "recorre muchas celdas distintas (%d)" % visited.size())


func test_wander_is_reproducible_with_the_same_seed() -> void:
	var first := _open_state(42)
	var second := _open_state(42)
	var a: Agent = first.agents.spawn(Vector2i(3, 3), 0)
	var b: Agent = second.agents.spawn(Vector2i(3, 3), 0)
	for i in range(800):
		first.tick(0.1)
		second.tick(0.1)
	assert_eq(a.position, b.position)
	assert_eq(a.state, b.state)
	var different := _open_state(7)
	var c: Agent = different.agents.spawn(Vector2i(3, 3), 0)
	for i in range(800):
		different.tick(0.1)
	assert_true(c.position != a.position, "otra semilla, otro recorrido")


func test_agent_that_does_not_wander_stays_put() -> void:
	var state := _open_state()
	var agent: Agent = state.agents.spawn(Vector2i(6, 6), 0)
	agent.wanders = false
	_run(state, 60.0)
	assert_eq(agent.position, Vector2(6.5, 6.5))
	assert_eq(agent.state, Agent.State.IDLE)


func test_wander_respects_the_maximum_distance() -> void:
	var state := GameState.new(Vector2i(60, 3))
	state.build.fill_rect_floor(Rect2i(Vector2i.ZERO, Vector2i(60, 3)), 0)
	state.wander.set_seed(5)
	var agent: Agent = state.agents.spawn(Vector2i(30, 1), 0)
	# Al emitirse la orden, el agente todavía está en el origen del viaje.
	var trip_lengths: Array[int] = []
	state.agents.agent_state_changed.connect(func(changed: Agent) -> void:
		if changed.state == Agent.State.WALKING:
			var offset: Vector2i = changed.destination - changed.get_cell()
			trip_lengths.append(maxi(absi(offset.x), absi(offset.y))))
	_run(state, 80.0)
	assert_true(trip_lengths.size() >= 5, "hizo varios viajes (%d)" % trip_lengths.size())
	for length: int in trip_lengths:
		assert_true(length <= WanderBehavior.MAX_DISTANCE, "viaje de %d celdas" % length)
	assert_true(agent.get_cell().x >= 0)


func test_agent_with_nowhere_to_go_does_not_break() -> void:
	var state := GameState.new(MAP_SIZE)
	state.build.place_floor(Vector2i(5, 5), 0) # una sola celda con suelo
	state.wander.set_seed(3)
	var agent: Agent = state.agents.spawn(Vector2i(5, 5), 0)
	_run(state, 30.0)
	assert_eq(agent.state, Agent.State.IDLE)
	assert_eq(agent.get_cell(), Vector2i(5, 5))


func test_agent_enclosed_by_walls_never_leaves() -> void:
	var state := _open_state()
	var rect := Rect2i(Vector2i(4, 4), Vector2i(2, 2))
	state.build.outline_rect_walls(rect, 0)
	state.wander.set_seed(11)
	var agent: Agent = state.agents.spawn(Vector2i(4, 4), 0)
	for i in range(2000):
		state.tick(0.1)
		assert_true(rect.has_point(agent.get_cell()), "no sale de la habitación cerrada")


func test_wander_does_not_override_a_manual_order() -> void:
	var state := _open_state()
	var agent: Agent = state.agents.spawn(Vector2i(0, 0), 0)
	state.agents.set_destination(agent.id, Vector2i(12, 0))
	state.tick(0.5)
	assert_eq(agent.destination, Vector2i(12, 0), "sigue yendo adonde se le mandó")


func test_removed_agent_is_forgotten() -> void:
	var state := _open_state()
	var agent: Agent = state.agents.spawn(Vector2i(2, 2), 0)
	_run(state, 0.3)
	state.agents.remove(agent.id)
	_run(state, 20.0)
	assert_eq(state.agents.get_agents().size(), 0)


# --- Integración con el reloj ----------------------------------------------------------------

func test_clock_speed_scales_walking_and_pause_stops_it() -> void:
	var normal := GameState.new(Vector2i(40, 1))
	normal.build.fill_rect_floor(Rect2i(Vector2i.ZERO, Vector2i(40, 1)), 0)
	var fast := GameState.new(Vector2i(40, 1))
	fast.build.fill_rect_floor(Rect2i(Vector2i.ZERO, Vector2i(40, 1)), 0)
	var paused := GameState.new(Vector2i(40, 1))
	paused.build.fill_rect_floor(Rect2i(Vector2i.ZERO, Vector2i(40, 1)), 0)
	var walkers: Array[Agent] = []
	for state: GameState in [normal, fast, paused]:
		state.wander.set_seed(1)
		var agent: Agent = state.agents.spawn(Vector2i(0, 0), 0)
		agent.wanders = false
		state.agents.set_destination(agent.id, Vector2i(39, 0))
		walkers.append(agent)
	fast.clock.set_speed(GameClock.Speed.X3)
	paused.clock.set_speed(GameClock.Speed.PAUSED)
	for i in range(10):
		normal.tick(0.1)
		fast.tick(0.1)
		paused.tick(0.1)
	# 1 segundo real: x1 = 1 minuto de juego = 2 celdas; x3 = 6 celdas; en pausa, 0.
	assert_near(walkers[0].position.x - 0.5, 2.0, "x1", 0.0001)
	assert_near(walkers[1].position.x - 0.5, 6.0, "x3", 0.0001)
	assert_near(walkers[2].position.x - 0.5, 0.0, "pausa", 0.0001)


func test_game_state_tick_refreshes_rooms_and_moves_agents_together() -> void:
	var state := _open_state()
	state.build.build_room(Rect2i(Vector2i(8, 8), Vector2i(2, 2)), 0)
	var created: Array[Room] = []
	state.rooms.room_created.connect(func(room: Room) -> void: created.append(room))
	var agent: Agent = state.agents.spawn(Vector2i(0, 0), 0)
	agent.wanders = false
	state.agents.set_destination(agent.id, Vector2i(5, 0))
	state.tick(1.0)
	assert_eq(created.size(), 1)
	assert_eq(agent.state, Agent.State.WALKING)
