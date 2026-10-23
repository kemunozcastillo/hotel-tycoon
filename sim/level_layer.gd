class_name LevelLayer
extends RefCounted
## Datos de un nivel (piso) del edificio: suelo por celda y paredes por arista.
## Estructura de almacenamiento pura; las reglas viven en GridMap2D / BuildCommands.

var size: Vector2i

var _floor: PackedByteArray
# Aristas norte (Axis.X) y oeste (Axis.Y). Tamaño (ancho+1) x (alto+1) para
# poder cerrar el borde sur y este del mapa.
var _walls_x: PackedByteArray
var _walls_y: PackedByteArray


func _init(p_size: Vector2i) -> void:
	size = p_size
	_floor.resize(size.x * size.y)
	_walls_x.resize((size.x + 1) * (size.y + 1))
	_walls_y.resize((size.x + 1) * (size.y + 1))


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


func has_wall(edge: Edge) -> bool:
	if not in_bounds_edge(edge):
		return false
	var index: int = _edge_index(edge)
	if edge.axis == Edge.Axis.X:
		return _walls_x[index] != 0
	return _walls_y[index] != 0


## Devuelve true si el valor cambió.
func set_wall(edge: Edge, on: bool) -> bool:
	if not in_bounds_edge(edge):
		return false
	var index: int = _edge_index(edge)
	var value: int = 1 if on else 0
	if edge.axis == Edge.Axis.X:
		if _walls_x[index] == value:
			return false
		_walls_x[index] = value
	else:
		if _walls_y[index] == value:
			return false
		_walls_y[index] = value
	return true


func _edge_index(edge: Edge) -> int:
	return edge.cell.y * (size.x + 1) + edge.cell.x
