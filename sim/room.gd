class_name Room
extends RefCounted
## Una habitación: región cerrada de celdas delimitada por paredes y puertas.
## Es un dato derivado del mapa (lo calcula RoomDetector); no se modifica a mano.

## Identificador estable asignado por RoomRegistry (0 = todavía sin asignar).
var id: int = 0
var level: int = 0
var cells: Array[Vector2i] = []
## Puertas en el perímetro de la habitación (también las que dan al exterior).
var doors: Array[Edge] = []
## true si todas las celdas tienen suelo.
var has_complete_floor: bool = false

var _cell_set: Dictionary = {}


func _init(p_level: int, p_cells: Array[Vector2i], p_doors: Array[Edge], p_complete_floor: bool) -> void:
	level = p_level
	cells = p_cells
	doors = p_doors
	has_complete_floor = p_complete_floor
	for cell: Vector2i in cells:
		_cell_set[cell] = true


func contains(cell: Vector2i) -> bool:
	return _cell_set.has(cell)


func get_area() -> int:
	return cells.size()


## Rectángulo mínimo que contiene la habitación.
func get_bounds() -> Rect2i:
	var min_cell: Vector2i = cells[0]
	var max_cell: Vector2i = cells[0]
	for cell: Vector2i in cells:
		min_cell = Vector2i(mini(min_cell.x, cell.x), mini(min_cell.y, cell.y))
		max_cell = Vector2i(maxi(max_cell.x, cell.x), maxi(max_cell.y, cell.y))
	return Rect2i(min_cell, max_cell - min_cell + Vector2i.ONE)


## true si la habitación llena exactamente su rectángulo (sin formas en L, etc.).
func is_rectangular() -> bool:
	var bounds: Rect2i = get_bounds()
	return bounds.size.x * bounds.size.y == cells.size()


## true si tiene las mismas celdas, puertas y estado de suelo (ignora id y nivel).
func is_same_as(other: Room) -> bool:
	if cells.size() != other.cells.size() or doors.size() != other.doors.size():
		return false
	if has_complete_floor != other.has_complete_floor:
		return false
	for cell: Vector2i in cells:
		if not other.contains(cell):
			return false
	var keys: Dictionary = {}
	for door: Edge in doors:
		keys[_door_key(door)] = true
	for door: Edge in other.doors:
		if not keys.has(_door_key(door)):
			return false
	return true


static func _door_key(edge: Edge) -> Vector3i:
	return Vector3i(edge.cell.x, edge.cell.y, edge.axis)
