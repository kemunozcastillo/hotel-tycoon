class_name Inventory
extends RefCounted
## Las piezas guardadas (suelo, pared, puerta), contadas por tipo y por estado (nueva o usada).
## Al construir se usan primero las del inventario, así que salen gratis. Es global y sin límite
## salvo que haya un `capacity_provider` (las habitaciones almacén).
##
## También guarda qué se hace con lo que se quita: venderlo (SELL) o guardarlo aquí (STORE).

enum RemovalMode { SELL, STORE }

## "Sin límite" para la capacidad.
const UNLIMITED: int = 2147483647

## Cambió alguna existencia.
signal stock_changed
## El jugador cambió el modo "al quitar".
signal removal_mode_changed(mode: Inventory.RemovalMode)

## Qué se hace con lo que se quita al demoler.
var removal_mode: Inventory.RemovalMode = RemovalMode.SELL:
	set(value):
		if removal_mode != value:
			removal_mode = value
			removal_mode_changed.emit(value)

## Gancho del almacén: Callable() -> int con cuántas piezas caben en total (un fondo compartido
## por todos los tipos de pieza; lo da `StorageCapacity`). Vacío = sin límite.
var capacity_provider: Callable = Callable()

var _stock: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	_stock.resize(BuildItem.KIND_COUNT * BuildItem.CONDITION_COUNT)


func count(kind: BuildItem.Kind, condition: BuildItem.Condition) -> int:
	return _stock[_index(kind, condition)]


## Piezas de ese tipo, nuevas y usadas.
func total(kind: BuildItem.Kind) -> int:
	return count(kind, BuildItem.Condition.NEW) + count(kind, BuildItem.Condition.USED)


func total_items() -> int:
	var sum: int = 0
	for kind in range(BuildItem.KIND_COUNT):
		sum += total(kind as BuildItem.Kind)
	return sum


## Cuántas piezas caben en total (UNLIMITED si no hay `capacity_provider`).
func get_capacity() -> int:
	if not capacity_provider.is_valid():
		return UNLIMITED
	return maxi(int(capacity_provider.call()), 0)


## Cuántas piezas más caben, del tipo que sean. Con más existencias que capacidad (por ejemplo,
## tras derribar el almacén) es 0: no se pierde nada, solo no se puede guardar más.
func capacity_left() -> int:
	return maxi(get_capacity() - total_items(), 0)


func can_store(amount: int = 1) -> bool:
	return capacity_left() >= amount


func add(kind: BuildItem.Kind, condition: BuildItem.Condition, amount: int = 1) -> void:
	if amount <= 0:
		return
	_stock[_index(kind, condition)] += amount
	stock_changed.emit()


## Quita piezas del inventario (para venderlas). Falla sin cambiar nada si no hay suficientes.
func remove_stock(kind: BuildItem.Kind, condition: BuildItem.Condition, amount: int) -> bool:
	if amount <= 0 or count(kind, condition) < amount:
		return false
	_stock[_index(kind, condition)] -= amount
	stock_changed.emit()
	return true


## Saca una pieza para construir con ella: primero una usada y, si no hay, una nueva. Devuelve su
## estado (BuildItem.Condition) o -1 si no queda ninguna de ese tipo.
func take_for_building(kind: BuildItem.Kind) -> int:
	for condition: BuildItem.Condition in [BuildItem.Condition.USED, BuildItem.Condition.NEW]:
		if count(kind, condition) > 0:
			_stock[_index(kind, condition)] -= 1
			stock_changed.emit()
			return condition
	return -1


func _index(kind: BuildItem.Kind, condition: BuildItem.Condition) -> int:
	return kind * BuildItem.CONDITION_COUNT + condition


# --- Guardado -----------------------------------------------------------------------------------

func serialize() -> Dictionary:
	var stock: Array = []
	for amount: int in _stock:
		stock.append(amount)
	return {"stock": stock, "removal_mode": removal_mode}


func restore(data: Dictionary, reader: SaveReader) -> void:
	var stock: Array = reader.read_array(data, "stock", "inventario")
	if stock.size() != _stock.size():
		reader.fail("inventario: 'stock' debe tener %d cifras" % _stock.size())
	else:
		for i in range(stock.size()):
			_stock[i] = reader.as_int(stock[i], "inventario.stock[%d]" % i, 0, BuildItem.MAX_STOCK)
	removal_mode = reader.read_enum(data, "removal_mode", "inventario", RemovalMode.size()) as RemovalMode
	stock_changed.emit()
