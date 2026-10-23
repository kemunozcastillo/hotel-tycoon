class_name BuildCommands
extends RefCounted
## Órdenes de construcción. Es la única vía para modificar el mapa desde el juego:
## aquí vivirán las reglas (costes, permisos, colisiones). Cada método devuelve
## true solo si el mapa realmente cambió.

var _grid: GridMap2D


func _init(grid: GridMap2D) -> void:
	_grid = grid


func place_floor(cell: Vector2i, level: int, type: CellTypes.FloorType = CellTypes.FloorType.BASIC) -> bool:
	if type == CellTypes.FloorType.NONE:
		return remove_floor(cell, level)
	return _grid.set_floor_type(cell, level, type)


func remove_floor(cell: Vector2i, level: int) -> bool:
	return _grid.set_floor_type(cell, level, CellTypes.FloorType.NONE)


func place_wall(edge: Edge, level: int) -> bool:
	return _grid.set_wall(edge, level, true)


func remove_wall(edge: Edge, level: int) -> bool:
	return _grid.set_wall(edge, level, false)
