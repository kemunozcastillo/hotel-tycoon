class_name Ledger
extends RefCounted
## El dinero del hotel: el saldo y el libro de movimientos, con totales por día y por categoría.
## Los importes son enteros con signo (positivo entra, negativo sale). Cada movimiento se anota
## con el día y el minuto del reloj del juego.

## En qué se gasta o de dónde viene el dinero.
enum Category {
	BUILD, ## Compra de piezas para construir (sale).
	SALE, ## Venta de piezas demolidas o del inventario (entra).
	STAY_DEPOSIT, ## Anticipo de una estancia, al hacer el check-in (entra).
	STAY_FINAL, ## Resto de una estancia, al terminarla (entra).
	DEPOSIT_REFUND, ## Anticipo devuelto por una estancia que no se completó (sale).
	UPKEEP, ## Mantenimiento diario de las habitaciones (sale).
}

const CATEGORY_COUNT: int = 6
## Cuántos movimientos recientes se conservan (los totales por día se conservan todos).
const MAX_TRANSACTIONS: int = 300
## Cota de cordura para los importes al cargar una partida.
const BIG_AMOUNT: int = 1000000000000

## El saldo cambió.
signal balance_changed(balance: int)
## Se anotó un movimiento: {day, minute, category, amount, note}.
signal transaction_recorded(transaction: Dictionary)

var balance: int = 0

var _clock: GameClock
var _transactions: Array[Dictionary] = []
var _days: Dictionary = {} # día -> PackedInt64Array con el total de cada categoría


func _init(start_money: int, clock: GameClock) -> void:
	balance = start_money
	_clock = clock


## Anota un movimiento (importe con signo). Un importe 0 no se anota. Se archiva en el día actual
## del reloj, salvo que se indique otro `day` (para cobros atrasados que se saltaron varios días).
func record(category: Category, amount: int, note: String = "", day_override: int = -1) -> void:
	if amount == 0:
		return
	balance += amount
	var day: int = day_override if day_override > 0 else _clock.get_day()
	if not _days.has(day):
		var totals := PackedInt64Array()
		totals.resize(CATEGORY_COUNT)
		_days[day] = totals
	var totals_of_day: PackedInt64Array = _days[day]
	totals_of_day[category] += amount
	_days[day] = totals_of_day

	var transaction: Dictionary = {
		"day": day, "minute": _clock.total_minutes, "category": category, "amount": amount, "note": note,
	}
	_transactions.append(transaction)
	if _transactions.size() > MAX_TRANSACTIONS:
		_transactions.pop_front()
	transaction_recorded.emit(transaction)
	balance_changed.emit(balance)


## true si se puede pagar ese importe sin quedar en negativo. Lo que no cuesta nada (o es un
## ingreso) siempre se puede, aunque el saldo ya esté en negativo.
func can_afford(cost: int) -> bool:
	return cost <= 0 or cost <= balance


## Total (con signo) de una categoría en un día.
func get_day_total(day: int, category: Category) -> int:
	if not _days.has(day):
		return 0
	return (_days[day] as PackedInt64Array)[category]


## Todo lo que entró ese día (suma de las categorías con total positivo).
func get_day_income(day: int) -> int:
	var income: int = 0
	for category in range(CATEGORY_COUNT):
		income += maxi(get_day_total(day, category as Category), 0)
	return income


## Todo lo que salió ese día, como número positivo.
func get_day_expenses(day: int) -> int:
	var expenses: int = 0
	for category in range(CATEGORY_COUNT):
		expenses += maxi(-get_day_total(day, category as Category), 0)
	return expenses


## Resultado neto del día (entradas menos salidas).
func get_day_net(day: int) -> int:
	return get_day_income(day) - get_day_expenses(day)


## Los días con algún movimiento, de menor a mayor.
func get_days() -> Array[int]:
	var days: Array[int] = []
	for day: int in _days.keys():
		days.append(day)
	days.sort()
	return days


## Los últimos movimientos, el más reciente primero.
func get_recent(count: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(_transactions.size() - 1, maxi(_transactions.size() - 1 - count, -1), -1):
		result.append(_transactions[i])
	return result


# --- Guardado -----------------------------------------------------------------------------------

func serialize() -> Dictionary:
	var days: Dictionary = {}
	for day: int in _days.keys():
		var totals: Array = []
		for total: int in (_days[day] as PackedInt64Array):
			totals.append(total)
		days[str(day)] = totals
	var transactions: Array = []
	for transaction in _transactions:
		var row: Dictionary = transaction.duplicate()
		row["minute"] = SaveReader.float_data(transaction["minute"])
		transactions.append(row)
	return {"balance": balance, "transactions": transactions, "days": days}


func restore(data: Dictionary, reader: SaveReader) -> void:
	balance = reader.read_int(data, "balance", "libro", -BIG_AMOUNT, BIG_AMOUNT)
	_transactions.clear()
	var transactions: Array = reader.read_array(data, "transactions", "libro")
	for i in range(transactions.size()):
		var where: String = "libro.transactions[%d]" % i
		var raw: Dictionary = reader.as_dict(transactions[i], where)
		if raw.is_empty():
			continue
		_transactions.append({
			"day": reader.read_int(raw, "day", where, 1),
			"minute": reader.read_float(raw, "minute", where, 0.0),
			"category": reader.read_enum(raw, "category", where, CATEGORY_COUNT),
			"amount": reader.read_int(raw, "amount", where, -BIG_AMOUNT, BIG_AMOUNT),
			"note": reader.read_string(raw, "note", where),
		})
	_days.clear()
	var days: Dictionary = reader.read_dict(data, "days", "libro")
	for key: Variant in days.keys():
		if typeof(key) != TYPE_STRING or not (key as String).is_valid_int() or (key as String).to_int() < 1:
			reader.fail("libro.days: día inválido '%s'" % str(key))
			continue
		var totals_raw: Variant = days[key]
		if typeof(totals_raw) != TYPE_ARRAY or (totals_raw as Array).size() != CATEGORY_COUNT:
			reader.fail("libro.days[%s] debe tener %d totales" % [str(key), CATEGORY_COUNT])
			continue
		var totals := PackedInt64Array()
		totals.resize(CATEGORY_COUNT)
		for i in range(CATEGORY_COUNT):
			totals[i] = reader.as_int((totals_raw as Array)[i], "libro.days[%s][%d]" % [str(key), i], -BIG_AMOUNT, BIG_AMOUNT)
		_days[(key as String).to_int()] = totals
