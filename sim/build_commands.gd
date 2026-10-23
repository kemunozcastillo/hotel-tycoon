class_name BuildCommands
extends RefCounted
## Órdenes de construcción. Es la única vía para modificar el mapa desde el juego.
##
## Cada orden se planifica como una lista de operaciones (plan_*), de la que se saca el
## presupuesto (quote) y la ejecución (execute). Construir cuesta dinero, salvo las piezas que haya
## en el inventario, que se usan primero y salen gratis. Lo que se retira se vende o se guarda en
## el inventario según `Inventory.removal_mode`; la venta vale el 100% si la pieza es nueva y menos
## si es usada (EconomyRules.sale_value).
##
## Una lista se ejecuta entera o no se ejecuta: si no hay dinero para todo, no se construye nada y
## se emite `funds_insufficient`. Construir nunca deja el saldo en negativo.
##
## Los comandos individuales devuelven true solo si el mapa realmente cambió; los de forma
## (rectángulos) devuelven cuántas celdas o aristas cambiaron.

## Una orden se rechazó por falta de dinero: hace falta `required_balance` y hay `balance`.
signal funds_insufficient(required_balance: int, balance: int)

var _grid: GridMap2D
var _rules: EconomyRules
var _ledger: Ledger
var _inventory: Inventory
var _pieces: PlacedPieces


func _init(grid: GridMap2D, rules: EconomyRules, ledger: Ledger, inventory: Inventory, pieces: PlacedPieces) -> void:
	_grid = grid
	_rules = rules
	_ledger = ledger
	_inventory = inventory
	_pieces = pieces


# --- Comandos individuales --------------------------------------------------------------

func place_floor(cell: Vector2i, level: int, type: CellTypes.FloorType = CellTypes.FloorType.BASIC) -> bool:
	return execute(plan_place_floor(cell, level, type)) > 0


func remove_floor(cell: Vector2i, level: int) -> bool:
	return execute(plan_remove_floor(cell, level)) > 0


## Pone una pared; si había una puerta, la sustituye.
func place_wall(edge: Edge, level: int) -> bool:
	return execute(plan_place_wall(edge, level)) > 0


## Quita una pared. No toca las puertas.
func remove_wall(edge: Edge, level: int) -> bool:
	return execute(plan_remove_wall(edge, level)) > 0


## Pone una puerta; si había una pared, la sustituye.
func place_door(edge: Edge, level: int) -> bool:
	return execute(plan_place_door(edge, level)) > 0


## Quita una puerta dejando la arista abierta. No toca las paredes.
func remove_door(edge: Edge, level: int) -> bool:
	return execute(plan_remove_door(edge, level)) > 0


## Quita lo que haya en la arista, sea pared o puerta.
func clear_edge(edge: Edge, level: int) -> bool:
	return execute(plan_clear_edge(edge, level)) > 0


# --- Comandos de forma (rectángulos) ----------------------------------------------------

## Pone suelo en todas las celdas del rectángulo. Devuelve cuántas cambiaron.
func fill_rect_floor(rect: Rect2i, level: int) -> int:
	return execute(plan_fill_rect_floor(rect, level))


## Quita el suelo de todas las celdas del rectángulo. Devuelve cuántas cambiaron.
func clear_rect_floor(rect: Rect2i, level: int) -> int:
	return execute(plan_clear_rect_floor(rect, level))


## Pone paredes en el perímetro del rectángulo, respetando las puertas que ya hubiera.
## Devuelve cuántas aristas cambiaron.
func outline_rect_walls(rect: Rect2i, level: int) -> int:
	return execute(plan_outline_rect_walls(rect, level))


## Quita las paredes del perímetro del rectángulo (las puertas se quedan).
## Devuelve cuántas aristas cambiaron.
func clear_outline_walls(rect: Rect2i, level: int) -> int:
	return execute(plan_clear_outline_walls(rect, level))


## Construye una habitación: suelo en el interior y paredes en el perímetro. Solo añade lo
## que falta; no quita nada existente. Devuelve el total de cambios.
func build_room(rect: Rect2i, level: int) -> int:
	return execute(plan_build_room(rect, level))


## Derriba una habitación: quita el suelo interior y todo el perímetro (paredes y puertas).
func demolish_room(rect: Rect2i, level: int) -> int:
	return execute(plan_demolish_room(rect, level))


# --- Planes (listas de operaciones) -----------------------------------------------------------

func plan_place_floor(cell: Vector2i, level: int, type: CellTypes.FloorType = CellTypes.FloorType.BASIC) -> Array[BuildOp]:
	return _single(_floor_op(cell, level, type))


func plan_remove_floor(cell: Vector2i, level: int) -> Array[BuildOp]:
	return _single(_floor_op(cell, level, CellTypes.FloorType.NONE))


func plan_place_wall(edge: Edge, level: int) -> Array[BuildOp]:
	return _single(_edge_op(edge, level, CellTypes.EdgeType.WALL))


func plan_remove_wall(edge: Edge, level: int) -> Array[BuildOp]:
	if not _grid.has_wall(edge, level):
		return []
	return _single(_edge_op(edge, level, CellTypes.EdgeType.NONE))


func plan_place_door(edge: Edge, level: int) -> Array[BuildOp]:
	return _single(_edge_op(edge, level, CellTypes.EdgeType.DOOR))


func plan_remove_door(edge: Edge, level: int) -> Array[BuildOp]:
	if not _grid.has_door(edge, level):
		return []
	return _single(_edge_op(edge, level, CellTypes.EdgeType.NONE))


func plan_clear_edge(edge: Edge, level: int) -> Array[BuildOp]:
	return _single(_edge_op(edge, level, CellTypes.EdgeType.NONE))


func plan_fill_rect_floor(rect: Rect2i, level: int) -> Array[BuildOp]:
	var ops: Array[BuildOp] = []
	for cell: Vector2i in GridShapes.rect_cells(rect):
		_append(ops, _floor_op(cell, level, CellTypes.FloorType.BASIC))
	return ops


func plan_clear_rect_floor(rect: Rect2i, level: int) -> Array[BuildOp]:
	var ops: Array[BuildOp] = []
	for cell: Vector2i in GridShapes.rect_cells(rect):
		_append(ops, _floor_op(cell, level, CellTypes.FloorType.NONE))
	return ops


func plan_outline_rect_walls(rect: Rect2i, level: int) -> Array[BuildOp]:
	var ops: Array[BuildOp] = []
	for edge: Edge in GridShapes.rect_perimeter(rect):
		if _grid.has_door(edge, level):
			continue
		_append(ops, _edge_op(edge, level, CellTypes.EdgeType.WALL))
	return ops


func plan_clear_outline_walls(rect: Rect2i, level: int) -> Array[BuildOp]:
	var ops: Array[BuildOp] = []
	for edge: Edge in GridShapes.rect_perimeter(rect):
		if _grid.has_wall(edge, level):
			_append(ops, _edge_op(edge, level, CellTypes.EdgeType.NONE))
	return ops


func plan_build_room(rect: Rect2i, level: int) -> Array[BuildOp]:
	return plan_fill_rect_floor(rect, level) + plan_outline_rect_walls(rect, level)


func plan_demolish_room(rect: Rect2i, level: int) -> Array[BuildOp]:
	var ops: Array[BuildOp] = plan_clear_rect_floor(rect, level)
	for edge: Edge in GridShapes.rect_perimeter(rect):
		_append(ops, _edge_op(edge, level, CellTypes.EdgeType.NONE))
	return ops


# --- Presupuesto y ejecución ----------------------------------------------------------------

## El presupuesto de una lista de operaciones con el estado actual del dinero y del inventario.
func quote(ops: Array[BuildOp]) -> BuildQuote:
	return BuildQuote.evaluate(ops, _inventory, _rules, _ledger.balance)


## Ejecuta una lista entera o nada. Devuelve cuántas operaciones se hicieron (0 si no había nada que
## hacer o si no alcanza el dinero, caso en que además emite `funds_insufficient`).
func execute(ops: Array[BuildOp]) -> int:
	if ops.is_empty():
		return 0
	var budget: BuildQuote = quote(ops)
	if not budget.affordable:
		funds_insufficient.emit(budget.required_balance, _ledger.balance)
		return 0

	var spent: int = 0
	var earned: int = 0
	var bought: PackedInt32Array = _zero_counts()
	var sold: PackedInt32Array = _zero_counts()
	var done: int = 0
	for op in ops:
		# 1. Se retira la pieza antigua: se guarda o se vende.
		if op.freed_kind >= 0:
			var freed: BuildItem.Kind = op.freed_kind as BuildItem.Kind
			if _inventory.removal_mode == Inventory.RemovalMode.STORE and _inventory.can_store(freed):
				_inventory.add(freed, op.freed_condition)
			else:
				earned += _rules.sale_value(freed, op.freed_condition)
				sold[freed] += 1
		# 2. Se toma la pieza nueva: del inventario si queda, si no se compra.
		var taken: int = -1
		if op.needed_kind >= 0:
			var needed: BuildItem.Kind = op.needed_kind as BuildItem.Kind
			taken = _inventory.take_for_building(needed)
			if taken < 0:
				spent += _rules.price_of(needed)
				bought[needed] += 1
		# 3. Se cambia el mapa.
		if not _apply_to_grid(op):
			continue
		done += 1
		# 4. Una pieza de segunda mano sigue siéndolo.
		if taken == BuildItem.Condition.USED:
			_mark_used(op)

	_ledger.record(Ledger.Category.BUILD, -spent, "Construcción: %s" % _describe(bought))
	_ledger.record(Ledger.Category.SALE, earned, "Venta de piezas: %s" % _describe(sold))
	return done


# --- Interno ---------------------------------------------------------------------------------

func _floor_op(cell: Vector2i, level: int, type: CellTypes.FloorType) -> BuildOp:
	if not _grid.has_level(level) or not _grid.in_bounds(cell):
		return null
	var old: CellTypes.FloorType = _grid.get_floor_type(cell, level)
	if old == type:
		return null
	var op := BuildOp.new()
	op.level = level
	op.is_floor = true
	op.cell = cell
	op.new_floor = type
	if old != CellTypes.FloorType.NONE:
		op.freed_kind = BuildItem.Kind.FLOOR
		op.freed_condition = _pieces.floor_condition(cell, level)
	if type != CellTypes.FloorType.NONE:
		op.needed_kind = BuildItem.Kind.FLOOR
	return op


func _edge_op(edge: Edge, level: int, type: CellTypes.EdgeType) -> BuildOp:
	if not _grid.is_edge_valid(edge, level):
		return null
	var old: CellTypes.EdgeType = _grid.get_edge_type(edge, level)
	if old == type:
		return null
	var op := BuildOp.new()
	op.level = level
	op.is_floor = false
	op.edge = edge
	op.new_edge = type
	op.freed_kind = BuildItem.kind_of_edge(old)
	if op.freed_kind >= 0:
		op.freed_condition = _pieces.edge_condition(edge, level)
	op.needed_kind = BuildItem.kind_of_edge(type)
	return op


func _apply_to_grid(op: BuildOp) -> bool:
	if op.is_floor:
		return _grid.set_floor_type(op.cell, op.level, op.new_floor)
	return _grid.set_edge_type(op.edge, op.level, op.new_edge)


func _mark_used(op: BuildOp) -> void:
	if op.is_floor:
		_pieces.mark_floor_used(op.cell, op.level)
	else:
		_pieces.mark_edge_used(op.edge, op.level)


func _single(op: BuildOp) -> Array[BuildOp]:
	var ops: Array[BuildOp] = []
	_append(ops, op)
	return ops


func _append(ops: Array[BuildOp], op: BuildOp) -> void:
	if op != null:
		ops.append(op)


func _zero_counts() -> PackedInt32Array:
	var counts := PackedInt32Array()
	counts.resize(BuildItem.KIND_COUNT)
	return counts


## "6 suelos, 10 paredes" (solo los tipos con alguna pieza).
func _describe(counts: PackedInt32Array) -> String:
	var parts: Array[String] = []
	for kind in range(BuildItem.KIND_COUNT):
		if counts[kind] > 0:
			parts.append(BuildItem.describe_count(kind as BuildItem.Kind, counts[kind]))
	return ", ".join(parts)
