class_name RoomOverlay
extends Node2D
## Muestra las habitaciones detectadas: un tinte sobre su suelo y una etiqueta con su tipo y
## tamaño. Solo lee el RoomRegistry y reacciona a sus señales. El tinte se dibuja entre el suelo
## y las paredes (LevelView.add_ground_overlay) para no teñir las paredes; la etiqueta va
## encima de todo.
##
## Sin tipo, el tinte es un tono estable por id (naranja si falta suelo). Con tipo, es el color
## del tipo si cumple los requisitos y naranja si no (la etiqueta dice el motivo).

const TINT_ALPHA: float = 0.20
const INCOMPLETE_TINT: Color = Color(1.0, 0.6, 0.2, 0.22)
const HOVER_TINT: Color = Color(1.0, 1.0, 1.0, 0.12)
const LABEL_FONT_SIZE: int = 15
const LABEL_LINE_HEIGHT: float = 18.0
const LABEL_COLOR: Color = Color(1, 1, 1, 0.92)
const LABEL_WARNING_COLOR: Color = Color(1.0, 0.72, 0.45, 0.98)
const LABEL_OUTLINE: Color = Color(0, 0, 0, 0.85)

var _registry: RoomRegistry
var _level: int = 0
var _rooms: Array[Room] = []
var _hovered_id: int = 0
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
	registry.room_type_changed.connect(_on_rooms_changed)
	_reload()


## Resalta una habitación (la que está bajo el cursor); null para quitar el resalte.
func set_hovered_room(room: Room) -> void:
	var new_id: int = room.id if room != null else 0
	if new_id == _hovered_id:
		return
	_hovered_id = new_id
	queue_redraw()


## Texto de la etiqueta de una habitación sin tipo: "ancho×alto" si es rectangular, si no, el
## número de celdas; avisa si le falta suelo.
static func describe(room: Room) -> String:
	return RoomTexts.label_lines(room, null, null)[0]


## Color del tinte. Sin `type`: un tono estable por id (naranja si falta suelo). Con `type`
## (y su `status`): el color del tipo si cumple los requisitos, naranja si no.
static func tint_of(room: Room, type: RoomType = null, status: RoomStatus = null) -> Color:
	if type != null:
		if status != null and not status.is_operational():
			return INCOMPLETE_TINT
		return Color(type.color, TINT_ALPHA)
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
		var tint: Color = tint_of(room, _registry.get_type_of(room), _registry.get_status(room))
		for cell: Vector2i in room.cells:
			var diamond: PackedVector2Array = IsoProjection.cell_diamond(cell)
			draw_colored_polygon(diamond, tint)
			if room.id == _hovered_id:
				draw_colored_polygon(diamond, HOVER_TINT)


func _draw_labels() -> void:
	var font: Font = ThemeDB.fallback_font
	for room: Room in _rooms:
		var sum := Vector2.ZERO
		for cell: Vector2i in room.cells:
			sum += Vector2(cell) + Vector2(0.5, 0.5)
		var center: Vector2 = IsoProjection.grid_to_world(sum / float(room.cells.size()))
		var lines: Array[String] = RoomTexts.label_lines(room, _registry.get_type_of(room), _registry.get_status(room))
		# Flotando sobre la habitación para que las paredes frontales no la tapen; las líneas
		# adicionales (el problema) van debajo de la primera.
		var base: Vector2 = center - Vector2(0.0, TilesetFactory.WALL_HEIGHT + 4.0)
		for i in range(lines.size()):
			var text: String = lines[i]
			var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE)
			var origin: Vector2 = base + Vector2(-text_size.x * 0.5, i * LABEL_LINE_HEIGHT)
			var color: Color = LABEL_COLOR if i == 0 else LABEL_WARNING_COLOR
			_labels.draw_string_outline(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, 4, LABEL_OUTLINE)
			_labels.draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, color)
