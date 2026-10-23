class_name RoomRegistry
extends RefCounted
## Mantiene las habitaciones de todos los niveles y avisa de sus cambios.
##
## El mapa solo marca los niveles como "sucios" cuando cambia algo; las habitaciones se
## recalculan en refresh() (GameState.tick lo llama cada fotograma) o al consultarlas. Así una
## orden de forma que toca decenas de celdas provoca un solo recálculo y un solo aviso.
##
## Cada habitación conserva su `id` mientras solape con su versión anterior: al ampliarla, o al
## dividirla, la parte con más celdas en común mantiene el id y la otra es nueva.

## Apareció una habitación nueva.
signal room_created(room: Room)
## Una habitación existente cambió de celdas, puertas o estado de suelo.
signal room_changed(room: Room)
## Una habitación dejó de existir (el objeto conserva su último estado y su id).
signal room_removed(room: Room)

var _grid: GridMap2D
var _rooms: Dictionary = {} # id -> Room
var _dirty_levels: Dictionary = {} # level -> true
var _next_id: int = 1


func _init(grid: GridMap2D) -> void:
	_grid = grid
	grid.cell_changed.connect(_on_cell_changed)
	grid.edge_changed.connect(_on_edge_changed)
	grid.level_added.connect(_mark_dirty)
	for level: int in grid.get_levels():
		_dirty_levels[level] = true


## Habitaciones de un nivel, ordenadas por id. Recalcula antes si hace falta.
func get_rooms(level: int) -> Array[Room]:
	refresh()
	var result: Array[Room] = []
	for room: Room in _rooms.values():
		if room.level == level:
			result.append(room)
	result.sort_custom(func(a: Room, b: Room) -> bool: return a.id < b.id)
	return result


func get_room(id: int) -> Room:
	refresh()
	return _rooms.get(id) as Room


## Habitación que contiene la celda, o null.
func get_room_at(cell: Vector2i, level: int) -> Room:
	refresh()
	for room: Room in _rooms.values():
		if room.level == level and room.contains(cell):
			return room
	return null


## Recalcula los niveles modificados y emite las señales (primero removed, luego changed y
## por último created). No hace nada si no cambió el mapa.
func refresh() -> void:
	if _dirty_levels.is_empty():
		return
	var levels: Array = _dirty_levels.keys()
	_dirty_levels.clear()
	var removed: Array[Room] = []
	var changed: Array[Room] = []
	var created: Array[Room] = []
	for level: int in levels:
		_refresh_level(level, removed, changed, created)
	for room: Room in removed:
		room_removed.emit(room)
	for room: Room in changed:
		room_changed.emit(room)
	for room: Room in created:
		room_created.emit(room)


func _on_cell_changed(_cell: Vector2i, level: int) -> void:
	_mark_dirty(level)


func _on_edge_changed(_edge: Edge, level: int) -> void:
	_mark_dirty(level)


func _mark_dirty(level: int) -> void:
	_dirty_levels[level] = true


func _refresh_level(level: int, removed: Array[Room], changed: Array[Room], created: Array[Room]) -> void:
	var old_rooms: Dictionary = {} # id -> Room, solo de este nivel
	var owner: Dictionary = {} # celda -> id de la habitación anterior
	for room: Room in _rooms.values():
		if room.level == level:
			old_rooms[room.id] = room
			for cell: Vector2i in room.cells:
				owner[cell] = room.id
	var new_rooms: Array[Room] = RoomDetector.detect(_grid, level)

	# Emparejar cada habitación nueva con la anterior con la que más celdas comparte.
	var pairs: Array = [] # [solape, índice nuevo, id viejo]
	for i in range(new_rooms.size()):
		var overlap: Dictionary = {}
		for cell: Vector2i in new_rooms[i].cells:
			if owner.has(cell):
				var old_id: int = owner[cell]
				overlap[old_id] = int(overlap.get(old_id, 0)) + 1
		for old_id: int in overlap.keys():
			pairs.append([overlap[old_id], i, old_id])
	pairs.sort_custom(_compare_pairs)

	var matched_new: Dictionary = {} # índice nuevo -> id viejo
	var used_old: Dictionary = {}
	for pair: Array in pairs:
		if not matched_new.has(pair[1]) and not used_old.has(pair[2]):
			matched_new[pair[1]] = pair[2]
			used_old[pair[2]] = true

	for i in range(new_rooms.size()):
		var room: Room = new_rooms[i]
		if matched_new.has(i):
			var old: Room = old_rooms[matched_new[i]]
			if old.is_same_as(room):
				continue # sin cambios: se conserva el objeto anterior
			room.id = old.id
			_rooms[room.id] = room
			changed.append(room)
		else:
			room.id = _next_id
			_next_id += 1
			_rooms[room.id] = room
			created.append(room)
	for old_id: int in old_rooms.keys():
		if not used_old.has(old_id):
			removed.append(old_rooms[old_id])
			_rooms.erase(old_id)


## Más solape primero; en empate, el id viejo menor y luego el índice nuevo menor (determinista).
func _compare_pairs(a: Array, b: Array) -> bool:
	if a[0] != b[0]:
		return a[0] > b[0]
	if a[2] != b[2]:
		return a[2] < b[2]
	return a[1] < b[1]
