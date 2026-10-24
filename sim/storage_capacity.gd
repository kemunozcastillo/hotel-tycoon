class_name StorageCapacity
extends RefCounted
## Cuántas piezas caben en el inventario: la suma, sobre todas las habitaciones de tipo almacén
## que están operativas, de su área por `RoomType.storage_capacity_per_cell`. Es un fondo
## compartido por todos los tipos de pieza. Se calcula al consultarlo (hay pocas habitaciones) y
## avisa cuando cambia, para que la interfaz se actualice.

## La capacidad total cambió (se construyó, amplió, derribó o estropeó un almacén).
signal capacity_changed(capacity: int)

var _rooms: RoomRegistry
var _catalog: RoomTypeCatalog
var _grid: GridMap2D
var _last: int = 0


func _init(rooms: RoomRegistry, catalog: RoomTypeCatalog, grid: GridMap2D) -> void:
	_rooms = rooms
	_catalog = catalog
	_grid = grid
	rooms.room_created.connect(_on_rooms_changed)
	rooms.room_changed.connect(_on_rooms_changed)
	rooms.room_removed.connect(_on_rooms_changed)
	rooms.room_type_changed.connect(_on_rooms_changed)
	_last = get_capacity()


## Piezas que caben ahora mismo en total.
func get_capacity() -> int:
	var total: int = 0
	for level: int in _grid.get_levels():
		for room: Room in _rooms.get_rooms(level):
			total += capacity_of(room)
	return total


## Lo que aporta una habitación: 0 si no es un almacén o no es operativa.
func capacity_of(room: Room) -> int:
	var type: RoomType = _catalog.get_type(room.type_id)
	if type == null or type.storage_capacity_per_cell <= 0:
		return 0
	if not _rooms.get_status(room).is_operational():
		return 0
	return room.get_area() * type.storage_capacity_per_cell


func _on_rooms_changed(_room: Room) -> void:
	var now: int = get_capacity()
	if now != _last:
		_last = now
		capacity_changed.emit(now)
