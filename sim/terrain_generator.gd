class_name TerrainGenerator
extends RefCounted
## El trazado inicial del exterior: una calle de 2 celdas a lo largo del borde sur (el más cercano a
## la cámara), una acera de 1 celda junto a ella y césped en el resto. Función pura: solo escribe en
## el mapa que se le da. Los huéspedes llegan por los dos extremos de la acera.
##
## Necesita que el catálogo tenga los terrenos `street`, `sidewalk` y `grass` (data/terrain_types.json).

const STREET: StringName = &"street"
const SIDEWALK: StringName = &"sidewalk"
const GRASS: StringName = &"grass"

## Filas de calle (las del borde sur).
const STREET_ROWS: int = 2


## Rellena el nivel con el trazado inicial. Devuelve false (sin cambiar nada) si falta algún
## terreno en el catálogo o el mapa es demasiado pequeño.
static func apply_default_layout(grid: GridMap2D, level: int) -> bool:
	var street: int = grid.terrain.index_of(STREET)
	var sidewalk: int = grid.terrain.index_of(SIDEWALK)
	var grass: int = grid.terrain.index_of(GRASS)
	if street < 0 or sidewalk < 0 or grass < 0 or not grid.has_level(level) or grid.size.y < STREET_ROWS + 4:
		return false
	var sidewalk_row: int = sidewalk_row_of(grid.size)
	for y in range(grid.size.y):
		var index: int = grass
		if y > sidewalk_row:
			index = street
		elif y == sidewalk_row:
			index = sidewalk
		for x in range(grid.size.x):
			grid.set_terrain_index(Vector2i(x, y), level, index)
	return true


## La fila de la acera.
static func sidewalk_row_of(size: Vector2i) -> int:
	return size.y - STREET_ROWS - 1


## Las celdas por las que llegan los huéspedes: los dos extremos de la acera.
static func arrival_cells(size: Vector2i) -> Array[Vector2i]:
	var row: int = sidewalk_row_of(size)
	return [Vector2i(0, row), Vector2i(size.x - 1, row)]
