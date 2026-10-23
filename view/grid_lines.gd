class_name GridLines
extends Node2D
## Rejilla tenue que marca el área construible del nivel (las celdas vacías no tienen tile).

const LINE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.10)
const BORDER_COLOR: Color = Color(1.0, 1.0, 1.0, 0.30)

var _size: Vector2i = Vector2i.ZERO


func setup(map_size: Vector2i) -> void:
	_size = map_size
	queue_redraw()


func _draw() -> void:
	for x in range(_size.x + 1):
		var color: Color = BORDER_COLOR if x == 0 or x == _size.x else LINE_COLOR
		draw_line(IsoProjection.grid_to_world(Vector2(x, 0)), IsoProjection.grid_to_world(Vector2(x, _size.y)), color)
	for y in range(_size.y + 1):
		var color: Color = BORDER_COLOR if y == 0 or y == _size.y else LINE_COLOR
		draw_line(IsoProjection.grid_to_world(Vector2(0, y)), IsoProjection.grid_to_world(Vector2(_size.x, y)), color)
