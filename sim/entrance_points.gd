class_name EntrancePoints
extends RefCounted
## Celdas por las que llegan (y se van) los huéspedes. Son marcadores que coloca el jugador sobre
## celdas con suelo. Es provisional: cuando exista un exterior caminable (calle, acera), los
## huéspedes llegarán desde la calle y la entrada pasará a ser una puerta del edificio.
##
## Una entrada se conserva aunque la celda pierda el suelo, pero deja de ser válida (get_valid) y
## no admite llegadas hasta que vuelva a serlo.

## Se añadió o quitó una entrada.
signal entrances_changed

var _grid: GridMap2D
var _cells: Dictionary = {} # nivel -> Array[Vector2i], en orden de colocación


func _init(grid: GridMap2D) -> void:
	_grid = grid


## Marca una entrada. Falla si la celda no se puede pisar o ya lo era.
func add(cell: Vector2i, level: int) -> bool:
	if not _grid.is_walkable(cell, level) or has(cell, level):
		return false
	if not _cells.has(level):
		var list: Array[Vector2i] = []
		_cells[level] = list
	(_cells[level] as Array[Vector2i]).append(cell)
	entrances_changed.emit()
	return true


func remove(cell: Vector2i, level: int) -> bool:
	if not has(cell, level):
		return false
	(_cells[level] as Array[Vector2i]).erase(cell)
	entrances_changed.emit()
	return true


func has(cell: Vector2i, level: int) -> bool:
	return _cells.has(level) and (_cells[level] as Array[Vector2i]).has(cell)


## Todas las entradas del nivel, también las que hayan perdido el suelo.
func get_all(level: int) -> Array[Vector2i]:
	if not _cells.has(level):
		return []
	return (_cells[level] as Array[Vector2i]).duplicate()


## Las entradas del nivel que ahora mismo se pueden pisar.
func get_valid(level: int) -> Array[Vector2i]:
	var valid: Array[Vector2i] = []
	for cell: Vector2i in get_all(level):
		if _grid.is_walkable(cell, level):
			valid.append(cell)
	return valid


# --- Guardado -----------------------------------------------------------------------------------

func serialize() -> Dictionary:
	var levels: Dictionary = {}
	for level: int in _cells.keys():
		levels[str(level)] = SaveReader.vec2i_list_data(_cells[level] as Array[Vector2i])
	return {"levels": levels}


func restore(data: Dictionary, reader: SaveReader) -> void:
	_cells.clear()
	var levels: Dictionary = reader.read_dict(data, "levels", "entradas")
	for key: Variant in levels.keys():
		if typeof(key) != TYPE_STRING or not (key as String).is_valid_int():
			reader.fail("entradas: nivel inválido '%s'" % str(key))
			continue
		var level: int = (key as String).to_int()
		var raw: Variant = levels[key]
		if typeof(raw) != TYPE_ARRAY:
			reader.fail("entradas[%d] debe ser una lista" % level)
			continue
		var list: Array[Vector2i] = []
		for i in range((raw as Array).size()):
			var cell: Vector2i = reader.as_vec2i((raw as Array)[i], "entradas[%d][%d]" % [level, i])
			if _grid.in_bounds(cell) and not list.has(cell):
				list.append(cell)
		_cells[level] = list
	entrances_changed.emit()
