extends TestCase
## Pruebas del almacén: la capacidad del inventario sale de las habitaciones de tipo almacén
## operativas (12 piezas por celda, fondo compartido entre todos los tipos de pieza).

const PER_CELL: int = 12


func _state(limited: bool = true) -> GameState:
	var rules := EconomyRules.new()
	rules.start_money = 100000
	rules.limited_storage = limited
	return GameState.new(Vector2i(24, 16), null, rules)


## Construye una habitación con puerta al norte y le asigna el tipo. Devuelve su id.
func _room(state: GameState, rect: Rect2i, type_id: StringName = &"storage") -> int:
	state.build.build_room(rect, 0)
	state.build.place_door(Edge.from_side(rect.position, Edge.Side.NORTH), 0)
	var room: Room = state.rooms.get_room_at(rect.position, 0)
	if type_id != &"":
		state.rooms.set_room_type(room.id, type_id)
	return room.id


# --- Capacidad -----------------------------------------------------------------------------------

func test_without_a_storage_room_nothing_fits() -> void:
	var state := _state()
	assert_eq(state.storage.get_capacity(), 0)
	assert_eq(state.inventory.get_capacity(), 0)
	assert_false(state.inventory.can_store())


func test_an_operational_storage_gives_twelve_pieces_per_cell() -> void:
	var state := _state()
	var id: int = _room(state, Rect2i(Vector2i(2, 2), Vector2i(2, 2)))
	assert_eq(state.storage.get_capacity(), 4 * PER_CELL)
	assert_eq(state.storage.capacity_of(state.rooms.get_room(id)), 48)
	assert_eq(state.inventory.capacity_left(), 48)


func test_storages_add_up_and_other_room_types_give_nothing() -> void:
	var state := _state()
	_room(state, Rect2i(Vector2i(2, 2), Vector2i(2, 2)))
	_room(state, Rect2i(Vector2i(8, 2), Vector2i(3, 2)))
	_room(state, Rect2i(Vector2i(14, 2), Vector2i(2, 2)), &"bathroom")
	_room(state, Rect2i(Vector2i(18, 2), Vector2i(2, 2)), &"")
	assert_eq(state.storage.get_capacity(), (4 + 6) * PER_CELL)


func test_a_storage_that_is_not_operational_gives_nothing_but_keeps_its_type() -> void:
	var state := _state()
	var rect := Rect2i(Vector2i(2, 2), Vector2i(2, 1)) # 2 celdas: menos del mínimo de 4
	var id: int = _room(state, rect)
	assert_eq(state.rooms.get_room(id).type_id, &"storage")
	assert_eq(state.storage.get_capacity(), 0)


func test_unlimited_when_the_rule_is_off() -> void:
	var state := _state(false)
	assert_eq(state.inventory.get_capacity(), Inventory.UNLIMITED)
	assert_true(state.inventory.can_store(100000))


func test_capacity_changed_is_emitted_only_when_the_total_changes() -> void:
	var state := _state()
	var seen: Array[int] = []
	state.storage.capacity_changed.connect(func(capacity: int) -> void: seen.append(capacity))
	var rect := Rect2i(Vector2i(2, 2), Vector2i(2, 2))
	var id: int = _room(state, rect, &"")
	state.rooms.refresh()
	assert_eq(seen, [] as Array[int], "una habitación sin tipo no cambia nada")
	state.rooms.set_room_type(id, &"storage")
	assert_eq(seen, [48] as Array[int])
	state.rooms.set_room_type(id, &"bathroom")
	assert_eq(seen, [48, 0] as Array[int])
	state.rooms.set_room_type(id, &"storage")
	state.build.demolish_room(rect, 0)
	state.rooms.refresh()
	assert_eq(seen, [48, 0, 48, 0] as Array[int], "derribarlo también avisa")


# --- El inventario y las órdenes de construcción ----------------------------------------------------

func test_removing_with_store_mode_without_a_storage_sells_everything() -> void:
	var state := _state()
	state.inventory.removal_mode = Inventory.RemovalMode.STORE
	var rect := Rect2i(Vector2i(10, 8), Vector2i(3, 1))
	state.build.fill_rect_floor(rect, 0)
	var balance: int = state.ledger.balance
	var budget: BuildQuote = state.build.quote(state.build.plan_clear_rect_floor(rect, 0))
	assert_eq(budget.stored, 0)
	assert_eq(budget.sold, 3)
	state.build.clear_rect_floor(rect, 0)
	assert_eq(state.inventory.total_items(), 0)
	assert_eq(state.ledger.balance, balance + 30, "se vende al 100% porque eran nuevas")


func test_the_pool_is_shared_between_kinds_and_the_excess_is_sold() -> void:
	var state := _state()
	_room(state, Rect2i(Vector2i(2, 2), Vector2i(2, 2))) # 48 piezas
	state.inventory.removal_mode = Inventory.RemovalMode.STORE
	state.inventory.add(BuildItem.Kind.WALL, BuildItem.Condition.USED, 40)
	assert_eq(state.inventory.capacity_left(), 8)
	var rect := Rect2i(Vector2i(10, 8), Vector2i(10, 1))
	state.build.fill_rect_floor(rect, 0) # compra 10 suelos... salvo que haya en el inventario (no hay)
	var budget: BuildQuote = state.build.quote(state.build.plan_clear_rect_floor(rect, 0))
	assert_eq(budget.stored, 8, "caben ocho")
	assert_eq(budget.sold, 2, "los otros dos se venden")
	state.build.clear_rect_floor(rect, 0)
	assert_eq(state.inventory.total_items(), 48)
	assert_eq(state.inventory.capacity_left(), 0)


func test_demolishing_the_storage_keeps_the_stock_and_blocks_more() -> void:
	var state := _state()
	var rect := Rect2i(Vector2i(2, 2), Vector2i(2, 2))
	_room(state, rect)
	state.inventory.add(BuildItem.Kind.FLOOR, BuildItem.Condition.NEW, 30)
	state.build.demolish_room(rect, 0)
	state.rooms.refresh()
	assert_eq(state.storage.get_capacity(), 0)
	assert_eq(state.inventory.total_items(), 30 + 0, "no se pierde ninguna pieza")
	assert_eq(state.inventory.capacity_left(), 0)
	assert_false(state.inventory.can_store())
	# Con más existencias que capacidad se puede seguir construyendo con ellas.
	var used_before: int = state.inventory.total_items()
	state.build.place_floor(Vector2i(12, 8), 0)
	assert_eq(state.inventory.total_items(), used_before - 1)
	assert_eq(state.inventory.capacity_left(), 0, "sigue por encima de la capacidad")


func test_the_quote_still_matches_when_the_stock_exceeds_the_capacity() -> void:
	var state := _state()
	state.inventory.removal_mode = Inventory.RemovalMode.STORE
	state.inventory.add(BuildItem.Kind.FLOOR, BuildItem.Condition.USED, 5) # sin almacén: de más
	var rect := Rect2i(Vector2i(10, 8), Vector2i(4, 1))
	var ops: Array[BuildOp] = state.build.plan_fill_rect_floor(rect, 0)
	var budget: BuildQuote = state.build.quote(ops)
	assert_eq(budget.from_stock, 4)
	assert_eq(budget.bought, 0)
	var balance: int = state.ledger.balance
	state.build.execute(ops)
	assert_eq(state.ledger.balance, balance, "todo salió del inventario")
	assert_eq(state.inventory.total_items(), 1)
	var removal: Array[BuildOp] = state.build.plan_clear_rect_floor(rect, 0)
	var removal_quote: BuildQuote = state.build.quote(removal)
	assert_eq(removal_quote.stored, 0, "quedan 1 pieza y 0 de capacidad: no cabe nada")
	assert_eq(removal_quote.sold, 4)


func test_demolishing_a_storage_in_store_mode_stores_what_the_quote_said() -> void:
	var state := _state()
	var rect := Rect2i(Vector2i(2, 2), Vector2i(2, 2))
	_room(state, rect)
	state.inventory.removal_mode = Inventory.RemovalMode.STORE
	var ops: Array[BuildOp] = state.build.plan_demolish_room(rect, 0)
	var budget: BuildQuote = state.build.quote(ops)
	assert_true(budget.stored > 0 and budget.no_room == 0, "la capacidad de antes de derribar es la que cuenta")
	var balance: int = state.ledger.balance
	state.build.execute(ops)
	assert_eq(state.inventory.total_items(), budget.stored, "se guarda lo previsto aunque el almacén desaparezca")
	assert_eq(state.ledger.balance - balance, budget.income)
	state.rooms.refresh()
	assert_eq(state.storage.get_capacity(), 0)
	assert_true(state.inventory.total_items() > state.inventory.get_capacity(), "queda por encima de la capacidad")
