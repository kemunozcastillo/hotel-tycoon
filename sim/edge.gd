class_name Edge
extends RefCounted
## Arista de la cuadrícula, siempre en forma canónica.
##
## Cada celda (x, y) "posee" dos aristas:
##   - Axis.X: su arista norte, que va a lo largo del eje X y separa (x, y-1) de (x, y).
##   - Axis.Y: su arista oeste, que va a lo largo del eje Y y separa (x-1, y) de (x, y).
## Las aristas sur y este de una celda son las norte y oeste de su vecina, así que
## cada arista física tiene una única representación (cell, axis).
##
## Las celdas del borde sur/este del mapa usan índices x == ancho o y == alto
## para cerrar el perímetro.

enum Axis { X, Y }
enum Side { NORTH, EAST, SOUTH, WEST }

var cell: Vector2i
var axis: Edge.Axis


func _init(p_cell: Vector2i = Vector2i.ZERO, p_axis: Edge.Axis = Edge.Axis.X) -> void:
	cell = p_cell
	axis = p_axis


## Arista de `p_cell` por el lado indicado, normalizada.
static func from_side(p_cell: Vector2i, side: Edge.Side) -> Edge:
	match side:
		Side.NORTH:
			return Edge.new(p_cell, Axis.X)
		Side.SOUTH:
			return Edge.new(p_cell + Vector2i(0, 1), Axis.X)
		Side.WEST:
			return Edge.new(p_cell, Axis.Y)
		_:
			return Edge.new(p_cell + Vector2i(1, 0), Axis.Y)


## Arista compartida por dos celdas contiguas, o null si no son contiguas.
static func between(a: Vector2i, b: Vector2i) -> Edge:
	var delta: Vector2i = b - a
	if delta == Vector2i.UP:
		return from_side(a, Side.NORTH)
	if delta == Vector2i.DOWN:
		return from_side(a, Side.SOUTH)
	if delta == Vector2i.LEFT:
		return from_side(a, Side.WEST)
	if delta == Vector2i.RIGHT:
		return from_side(a, Side.EAST)
	return null


## Arista más cercana a un punto en coordenadas fraccionarias de la cuadrícula
## (la celda (x, y) ocupa [x, x+1) x [y, y+1)).
static func nearest(grid_pos: Vector2) -> Edge:
	var p_cell := Vector2i(floori(grid_pos.x), floori(grid_pos.y))
	var u: float = grid_pos.x - p_cell.x
	var v: float = grid_pos.y - p_cell.y
	var best_side: Edge.Side = Edge.Side.NORTH
	var best_dist: float = v
	if 1.0 - v < best_dist:
		best_dist = 1.0 - v
		best_side = Side.SOUTH
	if u < best_dist:
		best_dist = u
		best_side = Side.WEST
	if 1.0 - u < best_dist:
		best_side = Side.EAST
	return from_side(p_cell, best_side)


## Las dos celdas que separa esta arista (la de atrás y la de delante).
func cells() -> Array[Vector2i]:
	if axis == Axis.X:
		return [cell + Vector2i(0, -1), cell]
	return [cell + Vector2i(-1, 0), cell]


func is_equal(other: Edge) -> bool:
	return other != null and cell == other.cell and axis == other.axis
