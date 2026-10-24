extends TestCase
## Pruebas de guardar y cargar la partida: ida y vuelta exacta, determinismo tras cargar,
## archivos rotos y ranuras en disco.

const TEST_DIR: String = "user://test_saves"


func _rules() -> EconomyRules:
	var rules := EconomyRules.new()
	rules.start_money = 100000
	return rules


## Un hotel con huéspedes en distintos puntos de su estancia y un par de agentes paseando.
func _busy_hotel(seed_value: int = 5) -> GameState:
	var state := HotelFixture.build(3, seed_value, true, _rules())
	state.inventory.add(BuildItem.Kind.WALL, BuildItem.Condition.USED, 3)
	state.inventory.removal_mode = Inventory.RemovalMode.STORE
	state.agents.spawn(Vector2i(20, 5), 0)
	state.agents.spawn(Vector2i(22, 12), 0)
	HotelFixture.run(state, 150.0)
	return state


func _text(state: GameState) -> String:
	return SaveGame.to_text(SaveGame.serialize(state))


func _reload(state: GameState) -> GameState:
	var errors: Array[String] = []
	var data: Dictionary = SaveGame.parse_text(_text(state), errors)
	assert_eq(errors, [] as Array[String], "el texto guardado se puede leer")
	var result: SaveGame.LoadResult = SaveGame.restore(data, _rules())
	assert_eq(result.errors, [] as Array[String], "se restaura sin errores")
	return result.state


func _clean_dir() -> void:
	if DirAccess.dir_exists_absolute(TEST_DIR):
		for file_name: String in DirAccess.get_files_at(TEST_DIR):
			DirAccess.remove_absolute(TEST_DIR + "/" + file_name)
		DirAccess.remove_absolute(TEST_DIR)


# --- Ida y vuelta ------------------------------------------------------------------------------------

func test_the_scenario_really_has_everything_to_save() -> void:
	var state := _busy_hotel()
	assert_true(state.guests.get_guest_count() >= 2, "hay huéspedes")
	assert_true(state.guests.total_checked_in >= 1, "alguno ya tiene dormitorio")
	assert_true(state.agents.get_agents().size() >= 4, "huéspedes y paseantes")
	assert_true(state.ledger.get_days().size() >= 1 and state.ledger.balance != 100000)
	assert_true(state.pieces.record_count() > 0)
	assert_eq(state.inventory.total_items(), 3)


func test_save_and_load_gives_an_identical_game() -> void:
	var state := _busy_hotel()
	var first: String = _text(state)
	var loaded: GameState = _reload(state)
	assert_true(loaded != null)
	var again: String = _text(loaded)
	assert_true(again == first, "guardar lo cargado da exactamente el mismo archivo: " + _diff(first, again))


func test_decimals_survive_the_text_exactly() -> void:
	var state := _busy_hotel()
	state.clock.total_minutes += 1.0 / 3.0
	var loaded: GameState = _reload(state)
	assert_eq(loaded.clock.total_minutes, state.clock.total_minutes, "sin perder ni un decimal")
	for agent: Agent in state.agents.get_agents():
		assert_eq(loaded.agents.get_agent(agent.id).position, agent.position)


func test_the_loaded_game_keeps_the_hotel_working() -> void:
	var state := _busy_hotel()
	var loaded: GameState = _reload(state)
	assert_eq(loaded.ledger.balance, state.ledger.balance)
	assert_eq(loaded.guests.get_guest_count(), state.guests.get_guest_count())
	assert_eq(loaded.rooms.get_rooms(0).size(), state.rooms.get_rooms(0).size())
	for room: Room in state.rooms.get_rooms(0):
		var twin: Room = loaded.rooms.get_room(room.id)
		assert_true(twin != null, "la habitación %d conserva su id" % room.id)
		assert_eq(twin.type_id, room.type_id)
		assert_eq(twin.cells, room.cells)
	assert_eq(loaded.inventory.count(BuildItem.Kind.WALL, BuildItem.Condition.USED), 3)
	assert_eq(loaded.inventory.removal_mode, Inventory.RemovalMode.STORE)
	assert_eq(loaded.entrances.get_all(0), state.entrances.get_all(0))
	assert_eq(loaded.clock.total_minutes, state.clock.total_minutes)


func test_a_loaded_game_continues_exactly_like_the_original() -> void:
	var state := _busy_hotel(11)
	var loaded: GameState = _reload(state)
	for step in range(60):
		state.tick(2.5)
		loaded.tick(2.5)
		if step % 10 == 9:
			assert_true(_text(loaded) == _text(state), "paso %d: siguen idénticas: %s" % [step, _diff(_text(state), _text(loaded))])
	assert_eq(loaded.ledger.balance, state.ledger.balance)
	assert_true(state.guests.total_arrived > 0)


func test_the_money_still_adds_up_after_loading() -> void:
	var state := _busy_hotel(21)
	var loaded: GameState = _reload(state)
	HotelFixture.run(loaded, 400.0)
	# El saldo es el inicial más todos los movimientos de todos los días.
	var total: int = 0
	for day: int in loaded.ledger.get_days():
		for category in range(Ledger.CATEGORY_COUNT):
			total += loaded.ledger.get_day_total(day, category as Ledger.Category)
	assert_eq(loaded.ledger.balance, 100000 + total)


func test_building_after_loading_works_and_pieces_keep_their_age() -> void:
	var state := HotelFixture.build(1, 1, false, _rules())
	var old_cell := Vector2i(15, 12)
	state.build.remove_floor(old_cell, 0)
	state.build.place_floor(old_cell, 0)
	state.clock.total_minutes += 500.0 # esa pieza queda vieja
	state.build.remove_floor(Vector2i(16, 12), 0)
	state.build.place_floor(Vector2i(16, 12), 0) # esta, nueva
	var loaded: GameState = _reload(state)
	assert_eq(loaded.pieces.floor_condition(old_cell, 0), BuildItem.Condition.USED)
	assert_eq(loaded.pieces.floor_condition(Vector2i(16, 12), 0), BuildItem.Condition.NEW)
	var balance: int = loaded.ledger.balance
	assert_eq(loaded.build.remove_floor(Vector2i(16, 12), 0), true)
	assert_eq(loaded.ledger.balance, balance + 10, "la nueva se vende al 100%")
	assert_true(loaded.build.place_floor(Vector2i(16, 12), 0))


func test_an_empty_new_game_round_trips() -> void:
	var state := GameState.new(Vector2i(10, 8), null, _rules())
	var loaded: GameState = _reload(state)
	assert_eq(_text(loaded), _text(state))


func test_other_levels_and_map_sizes_are_kept() -> void:
	var state := GameState.new(Vector2i(12, 9), null, _rules())
	state.grid.add_level(-1)
	state.grid.set_floor_type(Vector2i(2, 2), -1, CellTypes.FloorType.BASIC)
	var loaded: GameState = _reload(state)
	assert_eq(loaded.grid.size, Vector2i(12, 9))
	assert_true(loaded.grid.has_level(-1))
	assert_eq(loaded.grid.get_floor_type(Vector2i(2, 2), -1), CellTypes.FloorType.BASIC)


func test_storage_capacity_is_recomputed_on_load() -> void:
	var rules := _rules()
	rules.limited_storage = true
	var state := GameState.new(Vector2i(14, 10), null, rules)
	state.build.build_room(Rect2i(Vector2i(2, 2), Vector2i(2, 2)), 0)
	state.build.place_door(Edge.from_side(Vector2i(2, 2), Edge.Side.NORTH), 0)
	state.rooms.set_room_type(state.rooms.get_room_at(Vector2i(2, 2), 0).id, &"storage")
	var errors: Array[String] = []
	var result: SaveGame.LoadResult = SaveGame.restore(SaveGame.parse_text(_text(state), errors), rules)
	assert_eq(result.state.storage.get_capacity(), 48)
	assert_eq(result.state.inventory.get_capacity(), 48)
	var changes: Array[int] = []
	result.state.storage.capacity_changed.connect(func(capacity: int) -> void: changes.append(capacity))
	result.state.rooms.set_room_type(result.state.rooms.get_room_at(Vector2i(2, 2), 0).id, &"")
	assert_eq(changes, [0] as Array[int], "los cambios posteriores avisan bien")


# --- Datos que ya no encajan -------------------------------------------------------------------------

func test_an_unknown_room_type_is_dropped_with_a_warning() -> void:
	var state := _busy_hotel()
	var data: Dictionary = JSON.parse_string(_text(state))
	var rooms: Array = (data["rooms"] as Dictionary)["rooms"]
	(rooms[0] as Dictionary)["type_id"] = "casino"
	var result: SaveGame.LoadResult = SaveGame.restore(data, _rules())
	assert_true(result.is_ok(), "no impide cargar")
	assert_eq(result.warnings.size(), 1)
	assert_true(result.warnings[0].contains("casino"))
	var room_id: int = int((rooms[0] as Dictionary)["id"])
	assert_eq(result.state.rooms.get_room(room_id).type_id, &"")


# --- Archivos rotos ----------------------------------------------------------------------------------

func _expect_rejected(data: Dictionary, why: String) -> void:
	var result: SaveGame.LoadResult = SaveGame.restore(data, _rules())
	assert_false(result.is_ok(), "se rechaza: %s" % why)
	assert_true(result.errors.size() >= 1, "y explica por qué: %s" % why)


func test_files_that_are_not_a_game_are_rejected() -> void:
	_expect_rejected({}, "vacío")
	_expect_rejected({"game": "otro", "version": 1}, "otro juego")
	_expect_rejected({"game": SaveGame.GAME_ID}, "sin versión")
	var errors: Array[String] = []
	assert_eq(SaveGame.parse_text("{ esto no es json", errors), {})
	assert_eq(errors.size(), 1)
	errors.clear()
	assert_eq(SaveGame.parse_text("[1, 2]", errors), {})
	assert_eq(errors.size(), 1)


func test_a_newer_version_is_rejected() -> void:
	var data: Dictionary = JSON.parse_string(_text(_busy_hotel()))
	data["version"] = SaveGame.VERSION + 1
	var result: SaveGame.LoadResult = SaveGame.restore(data, _rules())
	assert_false(result.is_ok())
	assert_true(result.errors[0].contains("versión más nueva"))


func test_broken_sections_are_rejected() -> void:
	var good: Dictionary = JSON.parse_string(_text(_busy_hotel()))
	var broken: Dictionary = good.duplicate(true)
	broken.erase("clock")
	_expect_rejected(broken, "falta el reloj")
	broken = good.duplicate(true)
	((broken["grid"] as Dictionary)["levels"] as Dictionary)["0"]["floor"] = "AAAA"
	_expect_rejected(broken, "el suelo no tiene el tamaño del mapa")
	broken = good.duplicate(true)
	broken["map_size"] = [9999, 4]
	_expect_rejected(broken, "mapa enorme")
	broken = good.duplicate(true)
	broken["map_size"] = [10, 10]
	_expect_rejected(broken, "el tamaño no coincide con el mapa guardado")
	broken = good.duplicate(true)
	(((broken["agents"] as Dictionary)["agents"] as Array)[0] as Dictionary)["state"] = 77
	_expect_rejected(broken, "estado de agente inexistente")
	broken = good.duplicate(true)
	(((broken["guests"] as Dictionary)["guests"] as Array)[0] as Dictionary)["agent_id"] = 9999
	_expect_rejected(broken, "un huésped sin cuerpo")
	broken = good.duplicate(true)
	(broken["ledger"] as Dictionary)["balance"] = "mucho"
	_expect_rejected(broken, "saldo que no es un número")
	broken = good.duplicate(true)
	((broken["inventory"] as Dictionary)["stock"] as Array).append(1)
	_expect_rejected(broken, "inventario con cifras de más")


func test_random_damage_never_crashes_and_always_ends_clean() -> void:
	var good: Dictionary = JSON.parse_string(_text(_busy_hotel()))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var rejected: int = 0
	var accepted: int = 0
	for attempt in range(120):
		var damaged: Dictionary = good.duplicate(true)
		_damage(damaged, rng, 0)
		var result: SaveGame.LoadResult = SaveGame.restore(damaged, _rules())
		assert_eq(result.is_ok(), result.errors.is_empty(), "o hay partida o hay errores, nunca ambas cosas")
		if result.is_ok():
			accepted += 1
			HotelFixture.run(result.state, 5.0) # una partida aceptada también tiene que poder seguir
		else:
			rejected += 1
	assert_true(rejected > 20, "muchos daños se detectan (%d rechazados, %d aceptados)" % [rejected, accepted])


## Estropea al azar un valor del árbol (lo borra o lo cambia por otro tipo).
func _damage(node: Variant, rng: RandomNumberGenerator, depth: int) -> void:
	var keys: Array = []
	if typeof(node) == TYPE_DICTIONARY:
		keys = (node as Dictionary).keys()
	elif typeof(node) == TYPE_ARRAY:
		keys = range((node as Array).size())
	if keys.is_empty():
		return
	var key: Variant = keys[rng.randi_range(0, keys.size() - 1)]
	var child: Variant = node[key]
	var container: bool = typeof(child) == TYPE_DICTIONARY or typeof(child) == TYPE_ARRAY
	if container and depth < 4 and rng.randf() < 0.75:
		_damage(child, rng, depth + 1)
		return
	match rng.randi_range(0, 4):
		0:
			if typeof(node) == TYPE_DICTIONARY:
				(node as Dictionary).erase(key)
			else:
				(node as Array).remove_at(key as int)
		1:
			node[key] = "basura"
		2:
			node[key] = -7
		3:
			node[key] = 1.0e30
		_:
			node[key] = null


# --- Archivos en disco -------------------------------------------------------------------------------

func test_slots_save_and_load_from_disk() -> void:
	_clean_dir()
	var state := _busy_hotel()
	assert_false(SaveGame.has_slot(SaveGame.MANUAL_SLOT, TEST_DIR))
	assert_eq(SaveGame.save_slot(state, SaveGame.MANUAL_SLOT, TEST_DIR), "")
	assert_true(SaveGame.has_slot(SaveGame.MANUAL_SLOT, TEST_DIR))
	assert_false(FileAccess.file_exists(SaveGame.slot_path(SaveGame.MANUAL_SLOT, TEST_DIR) + ".tmp"), "no queda el temporal")
	var result: SaveGame.LoadResult = SaveGame.load_slot(SaveGame.MANUAL_SLOT, _rules(), null, TEST_DIR)
	assert_true(result.is_ok())
	assert_eq(_text(result.state), _text(state))
	# Guardar encima reemplaza la partida anterior.
	HotelFixture.run(state, 30.0)
	assert_eq(SaveGame.save_slot(state, SaveGame.MANUAL_SLOT, TEST_DIR), "")
	assert_eq(_text(SaveGame.load_slot(SaveGame.MANUAL_SLOT, _rules(), null, TEST_DIR).state), _text(state))
	# Las ranuras son independientes.
	assert_false(SaveGame.has_slot(SaveGame.AUTO_SLOT, TEST_DIR))
	_clean_dir()


func test_loading_a_missing_or_damaged_file_reports_an_error() -> void:
	_clean_dir()
	var missing: SaveGame.LoadResult = SaveGame.load_slot(SaveGame.MANUAL_SLOT, _rules(), null, TEST_DIR)
	assert_false(missing.is_ok())
	assert_eq(missing.errors.size(), 1)
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	var file: FileAccess = FileAccess.open(SaveGame.slot_path(SaveGame.MANUAL_SLOT, TEST_DIR), FileAccess.WRITE)
	var text: String = _text(_busy_hotel())
	file.store_string(text.substr(0, text.length() / 2)) # un archivo cortado por la mitad
	file.close()
	var damaged: SaveGame.LoadResult = SaveGame.load_slot(SaveGame.MANUAL_SLOT, _rules(), null, TEST_DIR)
	assert_false(damaged.is_ok())
	assert_true(damaged.errors.size() >= 1)
	_clean_dir()


## Dónde empiezan a diferir dos textos (para mensajes de fallo cortos).
func _diff(a: String, b: String) -> String:
	var lines_a: PackedStringArray = a.split("\n")
	var lines_b: PackedStringArray = b.split("\n")
	for i in range(mini(lines_a.size(), lines_b.size())):
		if lines_a[i] != lines_b[i]:
			var context: Array[String] = []
			for j in range(maxi(i - 6, 0), i):
				context.append(lines_a[j].strip_edges())
			return "línea %d: '%s' != '%s' (antes: %s)" % [i, lines_a[i].strip_edges(), lines_b[i].strip_edges(), " ".join(context)]
	return "longitudes distintas: %d y %d líneas" % [lines_a.size(), lines_b.size()]
