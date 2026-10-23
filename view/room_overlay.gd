class_name RoomOverlay
extends Node2D
## Muestra las habitaciones detectadas: un tinte sobre su suelo y una etiqueta con su tamaño.
## Solo lee el RoomRegistry y reacciona a sus señales. El tinte se dibuja entre el suelo y las
## paredes (LevelView.add_ground_overlay) para no teñir las paredes; la etiqueta va encima de todo.

const TINT_ALPHA: float = 0.20
const INCOMPLETE_TINT: Color = Color(1.0, 0.6, 0.2, 0.22)
const LABEL_FONT_SIZE: int = 15
const LABEL_COLOR: Color = Color(1, 1, 1, 0.92)
const LABEL_OUTLINE: Color = Color(0, 0, 0, 0.85)

var _registry: RoomRegistry
var _level: int = 0
var _rooms: Array[Room] = []
var _labels: Node2D


func setup(registry: RoomRegistry, level: int) -> void:
	_registry = registry
	_level = level
	_labels = Node2D.new()
	_labels.z_index = 5
	_labels.draw.connect(_draw_labels)
	add_child(_labels)
	registry.room_created.connect(_on_rooms_changed)
	registry.room_changed.connect(_on_rooms_changed)
	registry.room_removed.connect(_on_rooms_changed)
	_reload()


## Texto de la etiqueta de una habitación: "ancho×alto" si es rectangular, si no, el número de
## celdas; avisa si le falta suelo.
static func describe(room: Room) -> String:
	var text: String
	if room.is_rectangular():
		var size: Vector2i = room.get_bounds().size
		text = "%d×%d" % [size.x, size.y]
	else:
		text = "%d celdas" % room.get_area()
	if not room.has_complete_floor:
		text += " · falta suelo"
	return text


## Color del tinte de una habitación (un tono estable por id; naranja si le falta suelo).
static func tint_of(room: Room) -> Color:
	if not room.has_complete_floor:
		return INCOMPLETE_TINT
	return Color.from_hsv(fmod(room.id * 0.17, 1.0), 0.45, 0.95, TINT_ALPHA)


func get_room_count() -> int:
	return _rooms.size()


func _on_rooms_changed(_room: Room) -> void:
	_reload()


func _reload() -> void:
	_rooms = _registry.get_rooms(_level)
	queue_redraw()
	_labels.queue_redraw()


func _draw() -> void:
	for room: Room in _rooms:
		var tint: Color = tint_of(room)
		for cell: Vector2i in room.cells:
			draw_colored_polygon(IsoProjection.cell_diamond(cell), tint)


func _draw_labels() -> void:
	var font: Font = ThemeDB.fallback_font
	for room: Room in _rooms:
		var sum := Vector2.ZERO
		for cell: Vector2i in room.cells:
			sum += Vector2(cell) + Vector2(0.5, 0.5)
		var center: Vector2 = IsoProjection.grid_to_world(sum / float(room.cells.size()))
		var text: String = describe(room)
		var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE)
		# Se coloca flotando sobre la habitación para que las paredes frontales no la tapen.
		var origin: Vector2 = center - Vector2(text_size.x * 0.5, TilesetFactory.WALL_HEIGHT + 4.0)
		_labels.draw_string_outline(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, 4, LABEL_OUTLINE)
		_labels.draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, LABEL_COLOR)
