class_name ShapePreview
extends Node2D
## Vista previa de un rectángulo mientras se arrastra (celdas, perímetro y tamaño).
## Solo dibuja lo que le indica el BuildController; no toca la simulación.

enum Kind { FILL, OUTLINE, ROOM }

const ADD_COLOR: Color = Color(0.45, 1.0, 0.55)
const REMOVE_COLOR: Color = Color(1.0, 0.42, 0.42)
const CELL_ALPHA: float = 0.25
const PANEL_ALPHA: float = 0.22
const LINE_WIDTH: float = 3.0
const FONT_SIZE: int = 18

var _rect: Rect2i = Rect2i()
var _kind: Kind = Kind.FILL
var _removing: bool = false
var _active: bool = false


func _ready() -> void:
	z_index = 9


func show_shape(rect: Rect2i, kind: Kind, removing: bool) -> void:
	_rect = rect
	_kind = kind
	_removing = removing
	_active = true
	queue_redraw()


func is_active() -> bool:
	return _active


func get_rect() -> Rect2i:
	return _rect


func clear() -> void:
	if _active:
		_active = false
		queue_redraw()


func _draw() -> void:
	if not _active:
		return
	var color: Color = REMOVE_COLOR if _removing else ADD_COLOR
	if _kind != Kind.OUTLINE:
		var fill := Color(color, CELL_ALPHA)
		for cell: Vector2i in GridShapes.rect_cells(_rect):
			draw_colored_polygon(IsoProjection.cell_diamond(cell), fill)
	var up := Vector2(0, -TilesetFactory.WALL_HEIGHT)
	var panel := Color(color, PANEL_ALPHA)
	for edge: Edge in GridShapes.rect_perimeter(_rect):
		var ends: PackedVector2Array = IsoProjection.edge_endpoints(edge)
		if _kind != Kind.FILL:
			draw_colored_polygon(PackedVector2Array([ends[0], ends[1], ends[1] + up, ends[0] + up]), panel)
		draw_line(ends[0], ends[1], color, LINE_WIDTH)
	_draw_size_label(color)


## Etiqueta "ancho×alto" centrada sobre el rectángulo.
func _draw_size_label(color: Color) -> void:
	var text: String = "%d×%d" % [_rect.size.x, _rect.size.y]
	var font: Font = ThemeDB.fallback_font
	var center: Vector2 = IsoProjection.grid_to_world(Vector2(_rect.position) + Vector2(_rect.size) * 0.5)
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	var origin: Vector2 = center - Vector2(text_size.x * 0.5, 0.0) - Vector2(0, TilesetFactory.WALL_HEIGHT)
	draw_string_outline(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 4, Color(0, 0, 0, 0.85))
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color.lightened(0.35))
