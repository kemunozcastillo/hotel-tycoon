class_name LevelLayer
extends RefCounted
## Datos de un nivel (piso) del edificio: suelo por celda y paredes por arista.
## Estructura de almacenamiento pura; las reglas viven en GridMap2D / BuildCommands.

var size: Vector2i

var _floor: PackedByteArray
# Tipo (CellTypes.EdgeType) de las aristas norte (Axis.X) y oeste (Axis.Y). Tamaño
# (ancho+1) x (alto+1) para poder cerrar el borde sur y este del mapa.
var _edges_x: PackedByteArray
var _edges_y: PackedByteArray


func _init(p_size: Vector2i) -> void:
	size = p_size
	_floor.resize(size.x * size.y)
	_edges_x.resize((size.x + 1) * (size.y + 1))
	_edges_y.resize((size.x + 1) * (size.y + 1))


func in_bounds_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


## Una arista X necesita x en [0, ancho) e y en [0, alto]; una Y, al revés.
func in_bounds_edge(edge: Edge) -> bool:
	var c: Vector2i = edge.cell
	if c.x < 0 or c.y < 0:
		return false
	if edge.axis == Edge.Axis.X:
		return c.x < size.x and c.y <= size.y
	return c.x <= size.x and c.y < size.y


func get_floor_type(cell: Vector2i) -> CellTypes.FloorType:
	if not in_bounds_cell(cell):
		return CellTypes.FloorType.NONE
	return _floor[cell.y * size.x + cell.x] as CellTypes.FloorType


## Devuelve true si el valor cambió.
func set_floor_type(cell: Vector2i, type: CellTypes.FloorType) -> bool:
	if not in_bounds_cell(cell):
		return false
	var index: int = cell.y * size.x + cell.x
	if _floor[index] == type:
		return false
	_floor[index] = type
	return true


func get_edge_type(edge: Edge) -> CellTypes.EdgeType:
	if not in_bounds_edge(edge):
		return CellTypes.EdgeType.NONE
	var index: int = _edge_index(edge)
	if edge.axis == Edge.Axis.X:
		return _edges_x[index] as CellTypes.EdgeType
	return _edges_y[index] as CellTypes.EdgeType


## Devuelve true si el tipo cambió.
func set_edge_type(edge: Edge, type: CellTypes.EdgeType) -> bool:
	if not in_bounds_edge(edge):
		return false
	var index: int = _edge_index(edge)
	if edge.axis == Edge.Axis.X:
		if _edges_x[index] == type:
			return false
		_edges_x[index] = type
	else:
		if _edges_y[index] == type:
			return false
		_edges_y[index] = type
	return true


func _edge_index(edge: Edge) -> int:
	return edge.cell.y * (size.x + 1) + edge.cell.x


# --- Guardado -----------------------------------------------------------------------------------

## Los tres arrays de bytes, en base64.
func serialize() -> Dictionary:
	return {
		"floor": Marshalls.raw_to_base64(_floor),
		"edges_x": Marshalls.raw_to_base64(_edges_x),
		"edges_y": Marshalls.raw_to_base64(_edges_y),
	}


## Sustituye el contenido por el guardado. Si algo no cuadra (tamaño o valores fuera de rango),
## anota el error y no cambia nada.
func restore(data: Dictionary, reader: SaveReader, where: String) -> void:
	var floor_bytes: PackedByteArray = _read_bytes(data, "floor", where, _floor.size(), CellTypes.FloorType.size(), reader)
	var edges_x: PackedByteArray = _read_bytes(data, "edges_x", where, _edges_x.size(), CellTypes.EdgeType.size(), reader)
	var edges_y: PackedByteArray = _read_bytes(data, "edges_y", where, _edges_y.size(), CellTypes.EdgeType.size(), reader)
	if not reader.is_ok():
		return
	_floor = floor_bytes
	_edges_x = edges_x
	_edges_y = edges_y


func _read_bytes(data: Dictionary, key: String, where: String, expected_size: int, value_count: int, reader: SaveReader) -> PackedByteArray:
	var text: String = reader.read_string(data, key, where)
	var bytes: PackedByteArray = Marshalls.base64_to_raw(text)
	if bytes.size() != expected_size:
		reader.fail("%s.%s: tiene %d bytes y se esperaban %d" % [where, key, bytes.size(), expected_size])
		return PackedByteArray()
	for value: int in bytes:
		if value >= value_count:
			reader.fail("%s.%s: contiene un valor inválido (%d)" % [where, key, value])
			return PackedByteArray()
	return bytes
