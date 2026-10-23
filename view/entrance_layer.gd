class_name EntranceLayer
extends Node2D
## Dibuja los marcadores de entrada de huéspedes: una baldosa con una flecha hacia el interior.
## Verde si la entrada es válida; roja si la celda perdió el suelo. Solo lee EntrancePoints.

const VALID_COLOR: Color = Color(0.35, 0.9, 0.5)
const INVALID_COLOR: Color = Color(1.0, 0.4, 0.35)
const FILL_ALPHA: float = 0.3

var _entrances: EntrancePoints
var _level: int = 0


func setup(entrances: EntrancePoints, grid: GridMap2D, level: int) -> void:
	_entrances = entrances
	_level = level
	z_index = 7
	entrances.entrances_changed.connect(queue_redraw)
	# La validez depende del suelo: se redibuja cuando cambia el suelo de una celda marcada.
	grid.cell_changed.connect(_on_cell_changed)


func _on_cell_changed(cell: Vector2i, level: int) -> void:
	if level == _level and _entrances.has(cell, level):
		queue_redraw()


func _draw() -> void:
	var valid: Array[Vector2i] = _entrances.get_valid(_level)
	for cell: Vector2i in _entrances.get_all(_level):
		var color: Color = VALID_COLOR if valid.has(cell) else INVALID_COLOR
		var diamond: PackedVector2Array = IsoProjection.cell_diamond(cell)
		draw_colored_polygon(diamond, Color(color, FILL_ALPHA))
		var outline: PackedVector2Array = diamond.duplicate()
		outline.append(diamond[0])
		draw_polyline(outline, color, 2.0)
		_draw_arrow(IsoProjection.cell_to_world(cell), color)


## Flecha que apunta hacia abajo-derecha en pantalla (hacia el interior del mapa).
func _draw_arrow(center: Vector2, color: Color) -> void:
	var points := PackedVector2Array([
		center + Vector2(-10, -5),
		center + Vector2(4, 2),
		center + Vector2(0, 7),
	])
	draw_colored_polygon(points, color)
	draw_line(center + Vector2(-10, -5), center + Vector2(-2, 0), color, 3.0)
