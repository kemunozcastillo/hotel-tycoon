class_name Inventory
extends RefCounted
## Las piezas guardadas (suelo, pared, puerta), contadas por tipo y por estado (nueva o usada).
## Al construir se usan primero las del inventario, así que salen gratis. Es global y sin límite
## por ahora; más adelante la habitación almacén fijará la capacidad a través de
## `capacity_provider`.
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

## Gancho para el almacén futuro: Callable(kind: BuildItem.Kind) -> int con cuántas piezas de ese
## tipo caben en total. Vacío = sin límite.
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


## Cuántas piezas más de ese tipo caben.
func capacity_left(kind: BuildItem.Kind) -> int:
	if not capacity_provider.is_valid():
		return UNLIMITED
	return maxi(int(capacity_provider.call(kind)) - total(kind), 0)


func can_store(kind: BuildItem.Kind, amount: int = 1) -> bool:
	return capacity_left(kind) >= amount


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
