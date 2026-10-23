class_name IsoProjection
extends RefCounted
## Única pieza que conoce la proyección isométrica 2:1 (rombo de 64x32).
## Coincide con un TileMapLayer en modo TILE_LAYOUT_DIAMOND_DOWN: la caja de la celda (0, 0)
## empieza en el origen (su centro queda en (32, 16)), X crece hacia abajo-derecha e Y hacia
## abajo-izquierda.
##
## "Coordenadas de cuadrícula fraccionarias" (grid): la celda (x, y) ocupa [x, x+1) x [y, y+1),
## de modo que su centro es (x + 0.5, y + 0.5) y su vértice superior es (x, y).

const TILE_SIZE: Vector2i = Vector2i(64, 32)
const HALF_W: float = 32.0
const HALF_H: float = 16.0


## Centro de la celda en coordenadas del mundo (igual que TileMapLayer.map_to_local).
static func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2((cell.x - cell.y) * HALF_W + HALF_W, (cell.x + cell.y) * HALF_H + HALF_H)


## Punto fraccionario de la cuadrícula a coordenadas del mundo.
static func grid_to_world(grid_pos: Vector2) -> Vector2:
	return Vector2((grid_pos.x - grid_pos.y) * HALF_W + HALF_W, (grid_pos.x + grid_pos.y) * HALF_H)


## Coordenadas del mundo a punto fraccionario de la cuadrícula (inversa de grid_to_world).
static func world_to_grid(world_pos: Vector2) -> Vector2:
	var sx: float = (world_pos.x - HALF_W) / HALF_W
	var sy: float = world_pos.y / HALF_H
	return Vector2((sx + sy) * 0.5, (sy - sx) * 0.5)


## Celda que contiene un punto del mundo.
static func world_to_cell(world_pos: Vector2) -> Vector2i:
	var grid_pos: Vector2 = world_to_grid(world_pos)
	return Vector2i(floori(grid_pos.x), floori(grid_pos.y))


## Los dos extremos de una arista en coordenadas del mundo.
static func edge_endpoints(edge: Edge) -> PackedVector2Array:
	var start := Vector2(edge.cell)
	var end: Vector2 = start + (Vector2(1, 0) if edge.axis == Edge.Axis.X else Vector2(0, 1))
	return PackedVector2Array([grid_to_world(start), grid_to_world(end)])


## Los cuatro vértices del rombo de una celda, empezando por el superior y en sentido horario.
static func cell_diamond(cell: Vector2i) -> PackedVector2Array:
	var origin := Vector2(cell)
	return PackedVector2Array([
		grid_to_world(origin),
		grid_to_world(origin + Vector2(1, 0)),
		grid_to_world(origin + Vector2(1, 1)),
		grid_to_world(origin + Vector2(0, 1)),
	])
