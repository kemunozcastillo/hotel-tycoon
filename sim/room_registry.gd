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
##
## El tipo de habitación (dormitorio, baño...) lo asigna el jugador y se guarda en la propia
## habitación (`Room.type_id`): sigue al id, así que lo conserva la parte que conserva el id, la
## parte nueva de una división queda sin tipo y al derribar la habitación se pierde.

## Apareció una habitación nueva.
signal room_created(room: Room)
## Una habitación existente cambió de celdas, puertas o estado de suelo.
signal room_changed(room: Room)
## Una habitación dejó de existir (el objeto conserva su último estado y su id).
signal room_removed(room: Room)
## El jugador asignó o quitó el tipo de una habitación.
signal room_type_changed(room: Room)

var _grid: GridMap2D
var _catalog: RoomTypeCatalog
var _rooms: Dictionary = {} # id -> Room
var _dirty_levels: Dictionary = {} # level -> true
var _next_id: int = 1


func _init(grid: GridMap2D, catalog: RoomTypeCatalog) -> void:
	_grid = grid
	_catalog = catalog
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


## Asigna un tipo a una habitación (&"" lo quita). Devuelve false si la habitación o el tipo no
## existen, o si ya tenía ese tipo.
func set_room_type(room_id: int, type_id: StringName) -> bool:
	refresh()
	var room: Room = _rooms.get(room_id) as Room
	if room == null:
		return false
	if type_id != &"" and not _catalog.has_type(type_id):
		return false
	if room.type_id == type_id:
		return false
	room.type_id = type_id
	room_type_changed.emit(room)
	return true


## El tipo de una habitación, o null si no tiene.
func get_type_of(room: Room) -> RoomType:
	return _catalog.get_type(room.type_id)


## Estado de la habitación frente a los requisitos de su tipo, o null si no tiene tipo.
func get_status(room: Room) -> RoomStatus:
	var type: RoomType = get_type_of(room)
	if type == null:
		return null
	return RoomValidator.evaluate(room, type)


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
			room.type_id = old.type_id
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


# --- Guardado -----------------------------------------------------------------------------------

## Las habitaciones son un dato derivado del mapa; solo se guardan lo que no se deduce de él: el id
## estable y el tipo de cada una (identificada por una celda suya) y el siguiente id libre.
func serialize() -> Dictionary:
	refresh()
	var rows: Array = []
	for level: int in _grid.get_levels():
		for room: Room in get_rooms(level):
			rows.append({
				"id": room.id, "level": room.level, "anchor": SaveReader.vec2i_data(room.cells[0]),
				"type_id": str(room.type_id),
			})
	return {"next_id": _next_id, "rooms": rows}


## Recalcula las habitaciones del mapa ya restaurado y les devuelve su id y su tipo. No emite
## señales (se usa sobre un estado recién creado). Un tipo que ya no existe se descarta con un aviso.
func restore(data: Dictionary, reader: SaveReader) -> void:
	var saved_next: int = reader.read_int(data, "next_id", "habitaciones", 1)
	var rows: Array = reader.read_array(data, "rooms", "habitaciones")
	var detected: Array[Room] = []
	for level: int in _grid.get_levels():
		detected.append_array(RoomDetector.detect(_grid, level))
	var assigned: Dictionary = {} # índice detectado -> true
	var used_ids: Dictionary = {}
	_rooms.clear()
	for i in range(rows.size()):
		var where: String = "habitaciones.rooms[%d]" % i
		var row: Dictionary = reader.as_dict(rows[i], where)
		if row.is_empty():
			continue
		var id: int = reader.read_int(row, "id", where, 1)
		var level: int = reader.read_int(row, "level", where, -64, 64)
		var anchor: Vector2i = reader.read_vec2i(row, "anchor", where)
		var type_id := StringName(reader.read_string(row, "type_id", where))
		if used_ids.has(id):
			reader.fail("%s: el id %d está repetido" % [where, id])
			continue
		for j in range(detected.size()):
			if not assigned.has(j) and detected[j].level == level and detected[j].contains(anchor):
				assigned[j] = true
				used_ids[id] = true
				detected[j].id = id
				if type_id != &"" and not _catalog.has_type(type_id):
					reader.warn("la habitación %d tenía el tipo '%s', que ya no existe" % [id, str(type_id)])
					type_id = &""
				detected[j].type_id = type_id
				_rooms[id] = detected[j]
				break
	_next_id = maxi(saved_next, 1)
	for id: int in used_ids.keys():
		_next_id = maxi(_next_id, id + 1)
	for j in range(detected.size()):
		if not assigned.has(j): # un cambio que el archivo no recoge: id nuevo
			detected[j].id = _next_id
			_next_id += 1
			_rooms[detected[j].id] = detected[j]
	_dirty_levels.clear()
