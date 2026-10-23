class_name BuildCommands
extends RefCounted
## Órdenes de construcción. Es la única vía para modificar el mapa desde el juego:
## aquí vivirán las reglas (costes, permisos, colisiones). Los comandos individuales
## devuelven true solo si el mapa realmente cambió; los de forma (rectángulos) devuelven
## cuántas celdas o aristas cambiaron.

var _grid: GridMap2D


func _init(grid: GridMap2D) -> void:
	_grid = grid


# --- Comandos individuales --------------------------------------------------------------

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


# --- Comandos de forma (rectángulos) ----------------------------------------------------

## Pone suelo en todas las celdas del rectángulo. Devuelve cuántas cambiaron.
func fill_rect_floor(rect: Rect2i, level: int) -> int:
	var changed: int = 0
	for cell: Vector2i in GridShapes.rect_cells(rect):
		if place_floor(cell, level):
			changed += 1
	return changed


## Quita el suelo de todas las celdas del rectángulo. Devuelve cuántas cambiaron.
func clear_rect_floor(rect: Rect2i, level: int) -> int:
	var changed: int = 0
	for cell: Vector2i in GridShapes.rect_cells(rect):
		if remove_floor(cell, level):
			changed += 1
	return changed


## Pone paredes en el perímetro del rectángulo. Devuelve cuántas aristas cambiaron.
func outline_rect_walls(rect: Rect2i, level: int) -> int:
	var changed: int = 0
	for edge: Edge in GridShapes.rect_perimeter(rect):
		if place_wall(edge, level):
			changed += 1
	return changed


## Quita las paredes del perímetro del rectángulo. Devuelve cuántas aristas cambiaron.
func clear_outline_walls(rect: Rect2i, level: int) -> int:
	var changed: int = 0
	for edge: Edge in GridShapes.rect_perimeter(rect):
		if remove_wall(edge, level):
			changed += 1
	return changed


## Construye una habitación: suelo en el interior y paredes en el perímetro. Solo añade lo
## que falta; no quita nada existente. Devuelve el total de cambios.
func build_room(rect: Rect2i, level: int) -> int:
	return fill_rect_floor(rect, level) + outline_rect_walls(rect, level)


## Derriba una habitación: quita el suelo interior y las paredes del perímetro.
func demolish_room(rect: Rect2i, level: int) -> int:
	return clear_rect_floor(rect, level) + clear_outline_walls(rect, level)
