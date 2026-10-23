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
