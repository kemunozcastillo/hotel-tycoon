class_name GridShapes
extends RefCounted
## Formas geométricas sobre la cuadrícula (rectángulos de celdas y su perímetro de aristas).
## Funciones puras, sin estado.


## Rectángulo (inclusivo en ambas esquinas) que cubre dos celdas, en cualquier orden.
static func rect_between(a: Vector2i, b: Vector2i) -> Rect2i:
	var top_left := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	var bottom_right := Vector2i(maxi(a.x, b.x), maxi(a.y, b.y))
	return Rect2i(top_left, bottom_right - top_left + Vector2i.ONE)


## Todas las celdas del rectángulo, fila a fila.
static func rect_cells(rect: Rect2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			cells.append(Vector2i(x, y))
	return cells


## Las aristas que rodean el rectángulo: 2 * (ancho + alto), sin repetir ninguna.
static func rect_perimeter(rect: Rect2i) -> Array[Edge]:
	var edges: Array[Edge] = []
	var last_row: int = rect.end.y - 1
	var last_column: int = rect.end.x - 1
	for x in range(rect.position.x, rect.end.x):
		edges.append(Edge.from_side(Vector2i(x, rect.position.y), Edge.Side.NORTH))
		edges.append(Edge.from_side(Vector2i(x, last_row), Edge.Side.SOUTH))
	for y in range(rect.position.y, rect.end.y):
		edges.append(Edge.from_side(Vector2i(rect.position.x, y), Edge.Side.WEST))
		edges.append(Edge.from_side(Vector2i(last_column, y), Edge.Side.EAST))
	return edges
