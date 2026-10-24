class_name PlacedPieces
extends RefCounted
## Cuándo se colocó cada suelo, pared y puerta del mapa y si es una pieza usada. Con eso se sabe
## si una pieza está "nueva" (vale el 100% al venderla) o "usada" (vale menos).
##
## Una pieza es NUEVA si lleva colocada menos de `EconomyRules.new_window_minutes` minutos de
## juego y no es de segunda mano. Es USADA si lleva más tiempo, si se colocó sacándola del
## inventario siendo usada (BuildCommands la marca con mark_*_used) o si no se sabe de ella nada
## (por ejemplo, colocada saltándose BuildCommands).
##
## Se mantiene sola escuchando al mapa: cuando aparece una pieza anota la hora actual y cuando
## desaparece borra su registro.

class Record:
	var placed_at: float = 0.0
	var used: bool = false


var _clock: GameClock
var _rules: EconomyRules
var _records: Dictionary = {} # clave -> Record


func _init(grid: GridMap2D, clock: GameClock, rules: EconomyRules) -> void:
	_clock = clock
	_rules = rules
	grid.cell_changed.connect(_on_cell_changed.bind(grid))
	grid.edge_changed.connect(_on_edge_changed.bind(grid))


## Estado del suelo de la celda (USADA si no hay registro).
func floor_condition(cell: Vector2i, level: int) -> BuildItem.Condition:
	return _condition_of(_floor_key(cell, level))


## Estado de la pared o puerta de la arista (USADA si no hay registro).
func edge_condition(edge: Edge, level: int) -> BuildItem.Condition:
	return _condition_of(_edge_key(edge, level))


func mark_floor_used(cell: Vector2i, level: int) -> void:
	_mark_used(_floor_key(cell, level))


func mark_edge_used(edge: Edge, level: int) -> void:
	_mark_used(_edge_key(edge, level))


## Cuántas piezas tienen registro (para pruebas).
func record_count() -> int:
	return _records.size()


func _condition_of(key: Vector4i) -> BuildItem.Condition:
	var record: Record = _records.get(key) as Record
	if record == null or record.used:
		return BuildItem.Condition.USED
	if _clock.total_minutes - record.placed_at < _rules.new_window_minutes:
		return BuildItem.Condition.NEW
	return BuildItem.Condition.USED


func _mark_used(key: Vector4i) -> void:
	var record: Record = _records.get(key) as Record
	if record != null:
		record.used = true


func _floor_key(cell: Vector2i, level: int) -> Vector4i:
	return Vector4i(level, cell.x, cell.y, 0)


## Una arista solo tiene una pieza a la vez (pared o puerta), así que el tipo no entra en la clave.
func _edge_key(edge: Edge, level: int) -> Vector4i:
	return Vector4i(level, edge.cell.x, edge.cell.y, 1 + edge.axis)


func _on_cell_changed(cell: Vector2i, level: int, grid: GridMap2D) -> void:
	var key: Vector4i = _floor_key(cell, level)
	if grid.get_floor_type(cell, level) == CellTypes.FloorType.NONE:
		_records.erase(key)
	elif not _records.has(key):
		_stamp(key)


func _on_edge_changed(edge: Edge, level: int, grid: GridMap2D) -> void:
	var key: Vector4i = _edge_key(edge, level)
	_records.erase(key) # cambiar de pared a puerta (o al revés) es una pieza nueva
	if grid.get_edge_type(edge, level) != CellTypes.EdgeType.NONE:
		_stamp(key)


func _stamp(key: Vector4i) -> void:
	var record := Record.new()
	record.placed_at = _clock.total_minutes
	_records[key] = record


# --- Guardado -----------------------------------------------------------------------------------

## Una fila por pieza: [nivel, x, y, código, momento en que se colocó, usada].
func serialize() -> Dictionary:
	var rows: Array = []
	var keys: Array = _records.keys()
	keys.sort_custom(func(a: Vector4i, b: Vector4i) -> bool:
		return [a.x, a.y, a.z, a.w] < [b.x, b.y, b.z, b.w])
	for key: Vector4i in keys:
		var record: Record = _records[key] as Record
		rows.append([key.x, key.y, key.z, key.w, SaveReader.float_data(record.placed_at), record.used])
	return {"records": rows}


func restore(data: Dictionary, reader: SaveReader) -> void:
	_records.clear()
	var rows: Array = reader.read_array(data, "records", "piezas")
	for i in range(rows.size()):
		var where: String = "piezas.records[%d]" % i
		if typeof(rows[i]) != TYPE_ARRAY or (rows[i] as Array).size() != 6:
			reader.fail("%s debe tener 6 valores" % where)
			continue
		var row: Array = rows[i] as Array
		var record := Record.new()
		record.placed_at = reader.as_float(row[4], where + "[4]")
		if typeof(row[5]) != TYPE_BOOL:
			reader.fail("%s[5] debe ser true o false" % where)
			continue
		record.used = row[5] as bool
		var key := Vector4i(
			reader.as_int(row[0], where + "[0]", -64, 64), reader.as_int(row[1], where + "[1]", 0, 4096),
			reader.as_int(row[2], where + "[2]", 0, 4096), reader.as_int(row[3], where + "[3]", 0, 2))
		_records[key] = record
