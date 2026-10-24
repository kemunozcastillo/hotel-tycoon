class_name RoomOccupancy
extends RefCounted
## Qué huésped ocupa (o tiene reservada) cada habitación. Un huésped, una habitación; una
## habitación, un huésped. Solo guarda la relación: las reglas de a quién asignar viven en
## GuestRegistry.

## Una habitación se ocupó o quedó libre.
signal occupancy_changed

var _by_room: Dictionary = {} # id de habitación -> id de huésped
var _by_guest: Dictionary = {} # id de huésped -> id de habitación


## Reserva la habitación para el huésped. Falla si la habitación ya tiene ocupante o si el
## huésped ya tiene otra habitación.
func reserve(room_id: int, guest_id: int) -> bool:
	if _by_room.has(room_id) or _by_guest.has(guest_id):
		return false
	_by_room[room_id] = guest_id
	_by_guest[guest_id] = room_id
	occupancy_changed.emit()
	return true


## Libera la habitación del huésped. Devuelve el id de la habitación liberada (0 si no tenía).
func release_guest(guest_id: int) -> int:
	if not _by_guest.has(guest_id):
		return 0
	var room_id: int = _by_guest[guest_id]
	_by_guest.erase(guest_id)
	_by_room.erase(room_id)
	occupancy_changed.emit()
	return room_id


## El huésped que ocupa la habitación (0 = nadie).
func occupant_of(room_id: int) -> int:
	return _by_room.get(room_id, 0)


## La habitación del huésped (0 = ninguna).
func room_of(guest_id: int) -> int:
	return _by_guest.get(guest_id, 0)


func is_free(room_id: int) -> bool:
	return not _by_room.has(room_id)


func get_occupied_room_ids() -> Array[int]:
	var ids: Array[int] = []
	for room_id: int in _by_room.keys():
		ids.append(room_id)
	ids.sort()
	return ids


# --- Guardado -----------------------------------------------------------------------------------

## Parejas [habitación, huésped].
func serialize() -> Dictionary:
	var pairs: Array = []
	for room_id in get_occupied_room_ids():
		pairs.append([room_id, _by_room[room_id]])
	return {"pairs": pairs}


func restore(data: Dictionary, reader: SaveReader) -> void:
	_by_room.clear()
	_by_guest.clear()
	var pairs: Array = reader.read_array(data, "pairs", "ocupación")
	for i in range(pairs.size()):
		var where: String = "ocupación.pairs[%d]" % i
		if typeof(pairs[i]) != TYPE_ARRAY or (pairs[i] as Array).size() != 2:
			reader.fail("%s debe ser una pareja [habitación, huésped]" % where)
			continue
		var room_id: int = reader.as_int((pairs[i] as Array)[0], where + "[0]", 1)
		var guest_id: int = reader.as_int((pairs[i] as Array)[1], where + "[1]", 1)
		if _by_room.has(room_id) or _by_guest.has(guest_id):
			reader.fail("%s: habitación o huésped repetidos" % where)
			continue
		_by_room[room_id] = guest_id
		_by_guest[guest_id] = room_id


## Los ids de huésped con habitación (para comprobar que existen al restaurar).
func get_guest_ids() -> Array[int]:
	var ids: Array[int] = []
	for guest_id: int in _by_guest.keys():
		ids.append(guest_id)
	ids.sort()
	return ids
