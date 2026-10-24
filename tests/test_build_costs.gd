extends TestCase
## Pruebas de los costes de construcción: compra, inventario primero, venta (nueva o usada),
## guardar, formas de todo o nada, y las propiedades que no pueden romperse nunca.

const MAP_SIZE := Vector2i(12, 10)
const NEW := BuildItem.Condition.NEW
const USED := BuildItem.Condition.USED
const FLOOR := BuildItem.Kind.FLOOR
const WALL := BuildItem.Kind.WALL
const DOOR := BuildItem.Kind.DOOR


## Reglas con los precios por defecto (suelo 10, pared 8, puerta 25; venta 100% nueva, 85% usada;
## 60 min de margen) y el dinero inicial indicado.
func _rules(start: int) -> EconomyRules:
	var rules := EconomyRules.new()
	rules.start_money = start
	return rules


func _state(start: int = 1000) -> GameState:
	return GameState.new(MAP_SIZE, null, _rules(start))


func _age(state: GameState, minutes: float) -> void:
	state.clock.total_minutes += minutes


# --- Comprar ---------------------------------------------------------------------------------

func test_buying_costs_the_price_and_creates_a_new_piece() -> void:
	var state := _state()
	assert_true(state.build.place_floor(Vector2i(2, 2), 0))
	assert_eq(state.ledger.balance, 990)
	var last: Dictionary = state.ledger.get_recent(1)[0]
	assert_eq(last["category"], Ledger.Category.BUILD)
	assert_eq(last["amount"], -10)
	assert_eq(state.pieces.floor_condition(Vector2i(2, 2), 0), NEW)
	assert_false(state.build.place_floor(Vector2i(2, 2), 0), "ya estaba")
	assert_eq(state.ledger.balance, 990, "y no se cobra otra vez")


func test_every_piece_has_its_own_price() -> void:
	var state := _state()
	state.build.place_wall(Edge.from_side(Vector2i(3, 3), Edge.Side.NORTH), 0)
	assert_eq(state.ledger.balance, 992)
	state.build.place_door(Edge.from_side(Vector2i(5, 3), Edge.Side.NORTH), 0)
	assert_eq(state.ledger.balance, 967)


func test_without_enough_money_nothing_is_built_and_the_signal_says_how_much() -> void:
	var state := _state(5)
	var warnings: Array[Vector2i] = []
	state.build.funds_insufficient.connect(func(required: int, balance: int) -> void: warnings.append(Vector2i(required, balance)))
	assert_false(state.build.place_floor(Vector2i(2, 2), 0))
	assert_eq(state.grid.get_floor_type(Vector2i(2, 2), 0), CellTypes.FloorType.NONE)
	assert_eq(state.ledger.balance, 5)
	assert_eq(warnings, [Vector2i(10, 5)] as Array[Vector2i])


func test_exactly_enough_money_is_enough() -> void:
	var state := _state(10)
	assert_true(state.build.place_floor(Vector2i(1, 1), 0))
	assert_eq(state.ledger.balance, 0)
	assert_false(state.build.place_floor(Vector2i(2, 1), 0), "ya no queda nada")


func test_an_empty_order_does_nothing_and_stays_silent() -> void:
	var state := _state(0)
	var warnings: Array[int] = [0]
	state.build.funds_insufficient.connect(func(_required: int, _balance: int) -> void: warnings[0] += 1)
	assert_eq(state.build.execute([] as Array[BuildOp]), 0)
	assert_eq(state.build.fill_rect_floor(Rect2i(Vector2i(50, 50), Vector2i(2, 2)), 0), 0, "fuera del mapa no hay operaciones")
	assert_eq(warnings[0], 0)


# --- Vender ---------------------------------------------------------------------------------

func test_selling_a_new_piece_returns_the_full_price() -> void:
	var state := _state()
	state.build.place_floor(Vector2i(2, 2), 0)
	assert_true(state.build.remove_floor(Vector2i(2, 2), 0))
	assert_eq(state.ledger.balance, 1000, "deshacer dentro del margen no cuesta nada")
	assert_eq(state.ledger.get_recent(1)[0]["category"], Ledger.Category.SALE)


func test_selling_a_used_piece_returns_85_percent() -> void:
	var state := _state()
	state.build.place_floor(Vector2i(2, 2), 0)
	state.build.place_wall(Edge.from_side(Vector2i(4, 4), Edge.Side.NORTH), 0)
	state.build.place_door(Edge.from_side(Vector2i(6, 4), Edge.Side.NORTH), 0)
	assert_eq(state.ledger.balance, 1000 - 10 - 8 - 25)
	_age(state, 61.0)
	state.build.remove_floor(Vector2i(2, 2), 0)
	assert_eq(state.ledger.balance, 957 + 9, "suelo usado: 10 x 0,85 = 8,5 -> 9")
	state.build.remove_wall(Edge.from_side(Vector2i(4, 4), Edge.Side.NORTH), 0)
	assert_eq(state.ledger.balance, 966 + 7, "pared usada: 6,8 -> 7")
	state.build.remove_door(Edge.from_side(Vector2i(6, 4), Edge.Side.NORTH), 0)
	assert_eq(state.ledger.balance, 973 + 21, "puerta usada: 21,25 -> 21")


func test_the_margin_to_undo_a_mistake_is_the_new_window() -> void:
	var state := _state()
	state.build.place_floor(Vector2i(1, 1), 0)
	state.build.place_floor(Vector2i(2, 1), 0)
	_age(state, 59.0)
	state.build.remove_floor(Vector2i(1, 1), 0)
	assert_eq(state.ledger.balance, 980 + 10, "a los 59 min todavía es nueva")
	_age(state, 2.0)
	state.build.remove_floor(Vector2i(2, 1), 0)
	assert_eq(state.ledger.balance, 990 + 9, "a los 61 min ya es usada")


func test_replacing_a_wall_with_a_door_sells_the_wall_and_buys_the_door() -> void:
	var edge: Edge = Edge.from_side(Vector2i(3, 3), Edge.Side.WEST)
	var fresh := _state()
	fresh.build.place_wall(edge, 0)
	fresh.build.place_door(edge, 0)
	assert_eq(fresh.ledger.balance, 1000 - 8 + 8 - 25, "la pared nueva se vende entera")
	var old := _state()
	old.build.place_wall(edge, 0)
	_age(old, 100.0)
	old.build.place_door(edge, 0)
	assert_eq(old.ledger.balance, 1000 - 8 + 7 - 25, "la vieja, al 85%")
	assert_true(old.grid.has_door(edge, 0))


func test_the_ledger_notes_are_aggregated_per_order() -> void:
	var state := _state()
	state.build.build_room(Rect2i(Vector2i(2, 2), Vector2i(2, 2)), 0)
	var recent: Array[Dictionary] = state.ledger.get_recent(10)
	assert_eq(recent.size(), 1, "un solo movimiento por orden, no uno por pieza")
	assert_eq(recent[0]["amount"], -(4 * 10 + 8 * 8))
	assert_true(String(recent[0]["note"]).contains("4 suelos") and String(recent[0]["note"]).contains("8 paredes"))
	state.build.demolish_room(Rect2i(Vector2i(2, 2), Vector2i(2, 2)), 0)
	var after: Array[Dictionary] = state.ledger.get_recent(10)
	assert_eq(after.size(), 2)
	assert_eq(after[0]["category"], Ledger.Category.SALE)


func test_free_rules_never_touch_the_ledger() -> void:
	var state := GameState.new(MAP_SIZE)
	state.build.build_room(Rect2i(Vector2i(2, 2), Vector2i(3, 3)), 0)
	state.build.demolish_room(Rect2i(Vector2i(2, 2), Vector2i(3, 3)), 0)
	assert_eq(state.ledger.balance, 0)
	assert_eq(state.ledger.get_recent(10).size(), 0)


# --- Guardar e inventario ------------------------------------------------------------------------

func test_storing_keeps_the_piece_with_its_condition_and_pays_nothing() -> void:
	var state := _state()
	state.inventory.removal_mode = Inventory.RemovalMode.STORE
	state.build.place_floor(Vector2i(1, 1), 0)
	state.build.place_floor(Vector2i(2, 1), 0)
	_age(state, 30.0)
	state.build.remove_floor(Vector2i(1, 1), 0)
	_age(state, 40.0)
	state.build.remove_floor(Vector2i(2, 1), 0)
	assert_eq(state.ledger.balance, 980, "no se recibe dinero")
	assert_eq(state.inventory.count(FLOOR, NEW), 1, "la primera, a los 30 min, era nueva")
	assert_eq(state.inventory.count(FLOOR, USED), 1, "la segunda, a los 70 min, ya era usada")


func test_building_uses_the_inventory_first_and_only_pays_for_the_rest() -> void:
	var state := _state()
	state.inventory.add(FLOOR, USED, 3)
	assert_eq(state.build.fill_rect_floor(Rect2i(Vector2i(1, 1), Vector2i(5, 1)), 0), 5)
	assert_eq(state.ledger.balance, 1000 - 2 * 10, "tres salen gratis y dos se compran")
	assert_eq(state.inventory.total(FLOOR), 0)
	assert_eq(state.pieces.floor_condition(Vector2i(1, 1), 0), USED, "las del inventario usado siguen siendo usadas")
	assert_eq(state.pieces.floor_condition(Vector2i(5, 1), 0), NEW, "las compradas son nuevas")


func test_a_used_piece_from_the_inventory_sells_as_used_and_a_new_one_as_new() -> void:
	var used := _state()
	used.inventory.add(FLOOR, USED, 1)
	used.build.place_floor(Vector2i(2, 2), 0)
	assert_eq(used.ledger.balance, 1000, "salió gratis")
	used.build.remove_floor(Vector2i(2, 2), 0)
	assert_eq(used.ledger.balance, 1009, "vendida enseguida, al 85%")

	var fresh := _state()
	fresh.inventory.add(FLOOR, NEW, 1)
	fresh.build.place_floor(Vector2i(2, 2), 0)
	assert_eq(fresh.pieces.floor_condition(Vector2i(2, 2), 0), NEW)
	fresh.build.remove_floor(Vector2i(2, 2), 0)
	assert_eq(fresh.ledger.balance, 1010, "una pieza nueva del inventario vale el 100%")


func test_a_stored_then_reused_piece_never_gets_a_better_price_than_it_cost() -> void:
	var state := _state()
	state.inventory.removal_mode = Inventory.RemovalMode.STORE
	state.build.place_floor(Vector2i(3, 3), 0) # -10
	_age(state, 200.0)
	state.build.remove_floor(Vector2i(3, 3), 0) # a la reserva, usada
	state.build.place_floor(Vector2i(3, 3), 0) # gratis, usada
	state.inventory.removal_mode = Inventory.RemovalMode.SELL
	state.build.remove_floor(Vector2i(3, 3), 0) # +9
	assert_eq(state.ledger.balance, 1000 - 10 + 9, "el ciclo completo cuesta 1")


func test_capacity_decides_what_fits_and_the_rest_is_sold() -> void:
	var state := _state()
	state.inventory.removal_mode = Inventory.RemovalMode.STORE
	state.inventory.capacity_provider = func() -> int: return 2
	var rect := Rect2i(Vector2i(1, 1), Vector2i(5, 1))
	state.build.fill_rect_floor(rect, 0) # -50
	var budget: BuildQuote = state.build.quote(state.build.plan_clear_rect_floor(rect, 0))
	assert_eq(budget.stored, 2)
	assert_eq(budget.sold, 3)
	assert_eq(budget.income, 30)
	state.build.clear_rect_floor(rect, 0)
	assert_eq(state.inventory.total(FLOOR), 2, "caben dos")
	assert_eq(state.ledger.balance, 1000 - 50 + 30, "las otras tres se venden")
	state.build.place_wall(Edge.from_side(Vector2i(4, 4), Edge.Side.NORTH), 0)
	state.build.remove_wall(Edge.from_side(Vector2i(4, 4), Edge.Side.NORTH), 0)
	assert_eq(state.inventory.total(WALL), 0, "el almacén está lleno de suelos: la pared se vende")


# --- Formas de todo o nada ---------------------------------------------------------------------

func test_shapes_are_all_or_nothing() -> void:
	var state := _state(50)
	var warnings: Array[Vector2i] = []
	state.build.funds_insufficient.connect(func(required: int, balance: int) -> void: warnings.append(Vector2i(required, balance)))
	assert_eq(state.build.fill_rect_floor(Rect2i(Vector2i(1, 1), Vector2i(3, 3)), 0), 0, "9 suelos cuestan 90")
	assert_eq(state.ledger.balance, 50)
	assert_eq(state.grid.get_floor_type(Vector2i(1, 1), 0), CellTypes.FloorType.NONE, "no se construye ni una celda")
	assert_eq(warnings, [Vector2i(90, 50)] as Array[Vector2i])
	assert_eq(state.build.fill_rect_floor(Rect2i(Vector2i(1, 1), Vector2i(5, 1)), 0), 5, "cinco cuestan justo 50")
	assert_eq(state.ledger.balance, 0)


func test_build_room_is_atomic_across_floor_and_walls() -> void:
	var rect := Rect2i(Vector2i(3, 3), Vector2i(2, 2)) # 4 suelos (40) y 8 paredes (64)
	var poor := _state(100)
	assert_eq(poor.build.build_room(rect, 0), 0)
	assert_eq(poor.grid.get_floor_type(Vector2i(3, 3), 0), CellTypes.FloorType.NONE)
	assert_false(poor.grid.has_wall(Edge.from_side(Vector2i(3, 3), Edge.Side.NORTH), 0), "tampoco paredes")
	assert_eq(poor.ledger.balance, 100)
	var enough := _state(104)
	assert_eq(enough.build.build_room(rect, 0), 12)
	assert_eq(enough.ledger.balance, 0)


func test_demolishing_new_pieces_gives_everything_back_and_old_ones_85_percent() -> void:
	var rect := Rect2i(Vector2i(3, 3), Vector2i(2, 2))
	var quick := _state()
	quick.build.build_room(rect, 0)
	quick.build.demolish_room(rect, 0)
	assert_eq(quick.ledger.balance, 1000, "construir y derribar enseguida no cuesta nada")

	var slow := _state()
	slow.build.build_room(rect, 0)
	_age(slow, 90.0)
	slow.build.demolish_room(rect, 0)
	assert_eq(slow.ledger.balance, 1000 - 104 + 4 * 9 + 8 * 7, "al 85%: 4 suelos a 9 y 8 paredes a 7")


func test_demolishing_a_room_with_a_door_sells_the_door_too() -> void:
	var rect := Rect2i(Vector2i(3, 3), Vector2i(2, 2))
	var state := _state()
	state.build.build_room(rect, 0)
	state.build.place_door(Edge.from_side(rect.position, Edge.Side.NORTH), 0)
	_age(state, 90.0)
	var before: int = state.ledger.balance
	state.build.demolish_room(rect, 0)
	assert_eq(state.ledger.balance - before, 4 * 9 + 7 * 7 + 21, "suelos, siete paredes y la puerta, todo usado")


func test_demolishing_in_store_mode_fills_the_inventory() -> void:
	var rect := Rect2i(Vector2i(3, 3), Vector2i(2, 2))
	var state := _state()
	state.build.build_room(rect, 0)
	state.build.place_door(Edge.from_side(rect.position, Edge.Side.NORTH), 0)
	var balance: int = state.ledger.balance
	state.inventory.removal_mode = Inventory.RemovalMode.STORE
	state.build.demolish_room(rect, 0)
	assert_eq(state.ledger.balance, balance, "no entra dinero")
	assert_eq(state.inventory.total(FLOOR), 4)
	assert_eq(state.inventory.total(WALL), 7)
	assert_eq(state.inventory.total(DOOR), 1)
	# Y todo sirve para reconstruir sin pagar (la puerta primero: así la habitación no pone una
	# pared en su arista y se usan exactamente las siete paredes guardadas).
	state.build.place_door(Edge.from_side(rect.position, Edge.Side.NORTH), 0)
	state.build.build_room(rect, 0)
	assert_eq(state.ledger.balance, balance, "reconstruir con lo guardado sale gratis")
	assert_eq(state.inventory.total_items(), 0)


# --- Propiedades que no pueden romperse ----------------------------------------------------------------

## Una orden aleatoria sobre el mapa (rectángulos, aristas sueltas, derribos).
func _random_plan(state: GameState, rng: RandomNumberGenerator) -> Array[BuildOp]:
	var a := Vector2i(rng.randi_range(0, MAP_SIZE.x - 1), rng.randi_range(0, MAP_SIZE.y - 1))
	var b := Vector2i(clampi(a.x + rng.randi_range(0, 3), 0, MAP_SIZE.x - 1), clampi(a.y + rng.randi_range(0, 3), 0, MAP_SIZE.y - 1))
	var rect: Rect2i = GridShapes.rect_between(a, b)
	var edge := Edge.new(Vector2i(rng.randi_range(0, MAP_SIZE.x), rng.randi_range(0, MAP_SIZE.y)),
			Edge.Axis.X if rng.randf() < 0.5 else Edge.Axis.Y)
	match rng.randi_range(0, 9):
		0:
			return state.build.plan_fill_rect_floor(rect, 0)
		1:
			return state.build.plan_clear_rect_floor(rect, 0)
		2:
			return state.build.plan_outline_rect_walls(rect, 0)
		3:
			return state.build.plan_clear_outline_walls(rect, 0)
		4:
			return state.build.plan_build_room(rect, 0)
		5:
			return state.build.plan_demolish_room(rect, 0)
		6:
			return state.build.plan_place_door(edge, 0)
		7:
			return state.build.plan_place_wall(edge, 0)
		8:
			return state.build.plan_clear_edge(edge, 0)
		_:
			return state.build.plan_remove_door(edge, 0)


func _random_environment(state: GameState, rng: RandomNumberGenerator) -> void:
	if rng.randf() < 0.2:
		state.inventory.removal_mode = Inventory.RemovalMode.STORE if state.inventory.removal_mode == Inventory.RemovalMode.SELL else Inventory.RemovalMode.SELL
	if rng.randf() < 0.3:
		_age(state, rng.randf_range(0.0, 90.0))
	if rng.randf() < 0.1:
		state.inventory.add(rng.randi_range(0, 2) as BuildItem.Kind, rng.randi_range(0, 1) as BuildItem.Condition, rng.randi_range(1, 6))


func test_the_quote_always_matches_what_really_happens() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31337
	var executed: int = 0
	var rejected: int = 0
	for round_index in range(5):
		var state := _state(rng.randi_range(100, 700))
		if round_index == 4:
			state.inventory.capacity_provider = func() -> int: return 6
		for step in range(150):
			_random_environment(state, rng)
			var ops: Array[BuildOp] = _random_plan(state, rng)
			var budget: BuildQuote = state.build.quote(ops)
			var balance_before: int = state.ledger.balance
			var stock_before: int = state.inventory.total_items()
			var done: int = state.build.execute(ops)
			if ops.is_empty():
				assert_eq(done, 0)
			elif budget.affordable:
				executed += 1
				assert_eq(done, budget.ops_count, "ronda %d paso %d: se hicieron todas las operaciones" % [round_index, step])
				assert_eq(state.ledger.balance - balance_before, budget.income - budget.cost, "ronda %d paso %d: el dinero coincide con el presupuesto" % [round_index, step])
				assert_eq(state.inventory.total_items() - stock_before, budget.stored - budget.from_stock, "ronda %d paso %d: el inventario coincide" % [round_index, step])
				assert_true(state.ledger.balance >= 0, "construir nunca deja el saldo en negativo")
			else:
				rejected += 1
				assert_eq(done, 0)
				assert_eq(state.ledger.balance, balance_before, "una orden rechazada no cuesta nada")
				assert_eq(state.inventory.total_items(), stock_before)
	assert_true(executed > 200 and rejected > 20, "la muestra mezcla órdenes ejecutadas (%d) y rechazadas (%d)" % [executed, rejected])


## El valor de todo lo que se tiene a precio de compra: el dinero, lo que está construido y lo
## que hay en el inventario.
func _assets(state: GameState, rules: EconomyRules) -> int:
	var total: int = state.ledger.balance
	for y in range(MAP_SIZE.y):
		for x in range(MAP_SIZE.x):
			if state.grid.get_floor_type(Vector2i(x, y), 0) != CellTypes.FloorType.NONE:
				total += rules.floor_price
	for y in range(MAP_SIZE.y + 1):
		for x in range(MAP_SIZE.x + 1):
			for axis: Edge.Axis in [Edge.Axis.X, Edge.Axis.Y]:
				var edge := Edge.new(Vector2i(x, y), axis)
				if not state.grid.is_edge_valid(edge, 0):
					continue
				match state.grid.get_edge_type(edge, 0):
					CellTypes.EdgeType.WALL:
						total += rules.wall_price
					CellTypes.EdgeType.DOOR:
						total += rules.door_price
	for kind in range(BuildItem.KIND_COUNT):
		total += state.inventory.total(kind as BuildItem.Kind) * rules.price_of(kind as BuildItem.Kind)
	return total


func test_building_and_demolishing_can_never_make_money() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	for round_index in range(4):
		var rules: EconomyRules = _rules(rng.randi_range(200, 900))
		var state := GameState.new(MAP_SIZE, null, rules)
		var start: int = rules.start_money
		var lowest_loss: int = 0
		for step in range(250):
			# El entorno aleatorio no añade piezas gratis al inventario: eso sí sería dinero regalado.
			if rng.randf() < 0.2:
				state.inventory.removal_mode = Inventory.RemovalMode.STORE if state.inventory.removal_mode == Inventory.RemovalMode.SELL else Inventory.RemovalMode.SELL
			if rng.randf() < 0.3:
				_age(state, rng.randf_range(0.0, 90.0))
			state.build.execute(_random_plan(state, rng))
			var assets: int = _assets(state, rules)
			assert_true(assets <= start, "ronda %d paso %d: se tienen %d y se empezó con %d" % [round_index, step, assets, start])
			assert_true(state.ledger.balance >= 0)
			lowest_loss = mini(lowest_loss, assets - start)
		assert_true(lowest_loss < 0, "alguna venta de pieza usada tuvo que perder dinero (ronda %d)" % round_index)
