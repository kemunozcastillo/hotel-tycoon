class_name BuildQuote
extends RefCounted
## El presupuesto de una lista de operaciones de construcción, calculado igual que se ejecutará:
## una a una, retirando primero la pieza antigua (que se vende o se guarda) y colocando después la
## nueva (del inventario si queda, si no comprándola). Así lo que se ve antes de ordenar es lo que
## se cobra después.

## Cuántas operaciones cambian algo.
var ops_count: int = 0
## Dinero que se paga por piezas que hay que comprar.
var cost: int = 0
## Dinero que se recibe por piezas retiradas que se venden.
var income: int = 0
## Piezas del inventario que se usan (salen gratis).
var from_stock: int = 0
## Piezas retiradas que se guardan en el inventario.
var stored: int = 0
## Piezas retiradas que se venden (con "Guardar" también las que no caben en el inventario).
var sold: int = 0
## Piezas que se querían guardar (modo "Guardar") pero no caben en el almacén y se venden; ya
## están contadas en `sold`.
var no_room: int = 0
## Piezas que hay que comprar.
var bought: int = 0
## Saldo mínimo con el que se puede hacer toda la lista sin quedar en negativo en ningún paso.
var required_balance: int = 0
## true si el saldo actual alcanza.
var affordable: bool = true


## Resultado neto en dinero (positivo si se gana).
func net_money() -> int:
	return income - cost


func is_empty() -> bool:
	return ops_count == 0


static func evaluate(ops: Array[BuildOp], inventory: Inventory, rules: EconomyRules, balance: int) -> BuildQuote:
	var quote := BuildQuote.new()
	quote.ops_count = ops.size()
	var stock: Array[int] = []
	for kind in range(BuildItem.KIND_COUNT):
		stock.append(inventory.total(kind as BuildItem.Kind))
	# La capacidad es un fondo compartido por todos los tipos de pieza.
	var capacity: int = inventory.get_capacity()
	var stored_total: int = inventory.total_items()
	var storing: bool = inventory.removal_mode == Inventory.RemovalMode.STORE

	var running: int = 0 # dinero acumulado por la lista, sin contar el saldo inicial
	var lowest: int = 0
	for op in ops:
		if op.freed_kind >= 0:
			var freed: int = op.freed_kind
			if storing and capacity > stored_total:
				stored_total += 1
				stock[freed] += 1
				quote.stored += 1
			else:
				var value: int = rules.sale_value(freed as BuildItem.Kind, op.freed_condition)
				quote.income += value
				quote.sold += 1
				if storing:
					quote.no_room += 1
				running += value
		if op.needed_kind >= 0:
			var needed: int = op.needed_kind
			if stock[needed] > 0:
				stock[needed] -= 1
				stored_total -= 1
				quote.from_stock += 1
			else:
				var price: int = rules.price_of(needed as BuildItem.Kind)
				quote.cost += price
				quote.bought += 1
				running -= price
				lowest = mini(lowest, running)
	quote.required_balance = -lowest
	quote.affordable = balance >= quote.required_balance
	return quote
