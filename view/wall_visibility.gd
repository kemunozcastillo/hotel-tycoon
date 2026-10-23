class_name WallVisibility
extends RefCounted
## Con qué altura se dibuja una pared o puerta según el modo de visualización. Lógica pura sobre el
## mapa, sin nodos.
##
## Modo CUTAWAY: cada arista separa una celda "de atrás" (la del norte o la del oeste, la más
## lejana a la cámara) de una "de delante". Si la de atrás tiene suelo, la pared le tapa algo y se
## baja; si no, es una pared del fondo y se deja entera. Solo se mira la celda inmediatamente
## detrás: una estructura muy cercana por detrás podría seguir tapando algo en casos raros.


## Altura con la que se dibuja la arista en el modo dado.
static func height_for(grid: GridMap2D, level: int, edge: Edge, mode: WallViewMode.Mode) -> WallStyle.Height:
	match mode:
		WallViewMode.Mode.UP:
			return WallStyle.Height.FULL
		WallViewMode.Mode.LOW:
			return WallStyle.Height.LOW
		WallViewMode.Mode.DOWN:
			return WallStyle.Height.FLAT
		_:
			var behind: Vector2i = cell_behind(edge)
			if grid.get_floor_type(behind, level) != CellTypes.FloorType.NONE:
				return WallStyle.Height.LOW
			return WallStyle.Height.FULL


## La celda que queda detrás de la arista, vista desde la cámara: la del norte para una arista X
## y la del oeste para una Y.
static func cell_behind(edge: Edge) -> Vector2i:
	if edge.axis == Edge.Axis.X:
		return edge.cell + Vector2i(0, -1)
	return edge.cell + Vector2i(-1, 0)


## Las celdas cuyas paredes (las que poseen: norte y oeste) dependen del suelo de `cell` en el modo
## CUTAWAY: aquellas cuya arista tiene a `cell` detrás. Hay que redibujarlas si cambia su suelo.
static func dependent_wall_cells(cell: Vector2i) -> Array[Vector2i]:
	return [cell + Vector2i(0, 1), cell + Vector2i(1, 0)]
