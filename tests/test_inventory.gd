extends TestCase
## Pruebas del inventario de piezas.

const FLOOR := BuildItem.Kind.FLOOR
const WALL := BuildItem.Kind.WALL
const DOOR := BuildItem.Kind.DOOR
const NEW := BuildItem.Condition.NEW
const USED := BuildItem.Condition.USED


func test_starts_empty_and_counts_by_kind_and_condition() -> void:
	var inventory := Inventory.new()
	assert_eq(inventory.total_items(), 0)
	inventory.add(FLOOR, NEW, 5)
	inventory.add(FLOOR, USED, 3)
	inventory.add(WALL, NEW)
	assert_eq(inventory.count(FLOOR, NEW), 5)
	assert_eq(inventory.count(FLOOR, USED), 3)
	assert_eq(inventory.total(FLOOR), 8)
	assert_eq(inventory.total(WALL), 1)
	assert_eq(inventory.total(DOOR), 0)
	assert_eq(inventory.total_items(), 9)


func test_add_ignores_non_positive_amounts() -> void:
	var inventory := Inventory.new()
	var changes: Array[int] = [0]
	inventory.stock_changed.connect(func() -> void: changes[0] += 1)
	inventory.add(WALL, NEW, 0)
	inventory.add(WALL, NEW, -4)
	assert_eq(inventory.total_items(), 0)
	assert_eq(changes[0], 0)


func test_remove_stock_is_all_or_nothing() -> void:
	var inventory := Inventory.new()
	inventory.add(DOOR, USED, 2)
	assert_false(inventory.remove_stock(DOOR, USED, 3), "no hay suficientes")
	assert_eq(inventory.count(DOOR, USED), 2, "y no se toca nada")
	assert_false(inventory.remove_stock(DOOR, NEW, 1), "de otro estado")
	assert_true(inventory.remove_stock(DOOR, USED, 2))
	assert_eq(inventory.total(DOOR), 0)
	assert_false(inventory.remove_stock(DOOR, USED, 0), "cantidad no positiva")


func test_building_takes_used_pieces_first_then_new_ones() -> void:
	var inventory := Inventory.new()
	inventory.add(WALL, NEW, 2)
	inventory.add(WALL, USED, 1)
	assert_eq(inventory.take_for_building(WALL), USED, "primero la usada")
	assert_eq(inventory.take_for_building(WALL), NEW)
	assert_eq(inventory.take_for_building(WALL), NEW)
	assert_eq(inventory.take_for_building(WALL), -1, "ya no quedan")
	assert_eq(inventory.take_for_building(FLOOR), -1, "de otro tipo nunca hubo")
	assert_eq(inventory.total_items(), 0)


func test_stock_changed_signal_fires_on_real_changes() -> void:
	var inventory := Inventory.new()
	var changes: Array[int] = [0]
	inventory.stock_changed.connect(func() -> void: changes[0] += 1)
	inventory.add(FLOOR, NEW, 2)
	inventory.take_for_building(FLOOR)
	inventory.remove_stock(FLOOR, NEW, 1)
	inventory.remove_stock(FLOOR, NEW, 1) # ya no hay: sin cambio
	inventory.take_for_building(FLOOR) # tampoco
	assert_eq(changes[0], 3)


func test_removal_mode_defaults_to_selling_and_signals_only_on_change() -> void:
	var inventory := Inventory.new()
	assert_eq(inventory.removal_mode, Inventory.RemovalMode.SELL)
	var modes: Array[int] = []
	inventory.removal_mode_changed.connect(func(mode: Inventory.RemovalMode) -> void: modes.append(mode))
	inventory.removal_mode = Inventory.RemovalMode.SELL
	inventory.removal_mode = Inventory.RemovalMode.STORE
	inventory.removal_mode = Inventory.RemovalMode.STORE
	inventory.removal_mode = Inventory.RemovalMode.SELL
	assert_eq(modes, [Inventory.RemovalMode.STORE, Inventory.RemovalMode.SELL] as Array[int])


func test_capacity_is_unlimited_until_a_provider_limits_it() -> void:
	var inventory := Inventory.new()
	assert_eq(inventory.capacity_left(FLOOR), Inventory.UNLIMITED)
	assert_true(inventory.can_store(FLOOR, 100000))
	# El almacén futuro: 10 suelos y nada más.
	inventory.capacity_provider = func(kind: BuildItem.Kind) -> int: return 10 if kind == FLOOR else 0
	assert_eq(inventory.capacity_left(FLOOR), 10)
	inventory.add(FLOOR, USED, 4)
	assert_eq(inventory.capacity_left(FLOOR), 6)
	assert_true(inventory.can_store(FLOOR, 6))
	assert_false(inventory.can_store(FLOOR, 7))
	assert_false(inventory.can_store(WALL), "este tipo no tiene sitio")
	inventory.add(FLOOR, NEW, 20) # pasarse de capacidad no rompe nada: solo no deja guardar más
	assert_eq(inventory.capacity_left(FLOOR), 0)
