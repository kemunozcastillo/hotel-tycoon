class_name MinHeap
extends RefCounted
## Cola de prioridad (montículo binario de mínimos). GDScript no trae una.
## Ante prioridades iguales sale primero lo que entró antes, así los resultados son
## deterministas.

var _values: Array = []
var _priorities: PackedFloat64Array = PackedFloat64Array()
var _orders: PackedInt64Array = PackedInt64Array()
var _counter: int = 0


func size() -> int:
	return _values.size()


func is_empty() -> bool:
	return _values.is_empty()


func clear() -> void:
	_values.clear()
	_priorities.clear()
	_orders.clear()
	_counter = 0


func push(value: Variant, priority: float) -> void:
	_values.append(value)
	_priorities.append(priority)
	_orders.append(_counter)
	_counter += 1
	_sift_up(_values.size() - 1)


## Prioridad del elemento que saldría ahora (la menor).
func peek_priority() -> float:
	return _priorities[0]


## Saca el elemento de menor prioridad. La cola no debe estar vacía.
func pop() -> Variant:
	var top: Variant = _values[0]
	var last: int = _values.size() - 1
	_swap(0, last)
	_values.pop_back()
	_priorities.resize(last)
	_orders.resize(last)
	if last > 0:
		_sift_down(0)
	return top


func _less(a: int, b: int) -> bool:
	if _priorities[a] != _priorities[b]:
		return _priorities[a] < _priorities[b]
	return _orders[a] < _orders[b]


func _swap(a: int, b: int) -> void:
	var value: Variant = _values[a]
	_values[a] = _values[b]
	_values[b] = value
	var priority: float = _priorities[a]
	_priorities[a] = _priorities[b]
	_priorities[b] = priority
	var order: int = _orders[a]
	_orders[a] = _orders[b]
	_orders[b] = order


func _sift_up(index: int) -> void:
	while index > 0:
		var parent: int = (index - 1) >> 1
		if not _less(index, parent):
			return
		_swap(index, parent)
		index = parent


func _sift_down(index: int) -> void:
	var count: int = _values.size()
	while true:
		var left: int = index * 2 + 1
		var right: int = left + 1
		var smallest: int = index
		if left < count and _less(left, smallest):
			smallest = left
		if right < count and _less(right, smallest):
			smallest = right
		if smallest == index:
			return
		_swap(index, smallest)
		index = smallest
