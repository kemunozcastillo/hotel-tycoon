class_name CellCursor
extends Node2D
## Resalta la celda bajo el cursor y, en modo arista, la arista más cercana (con una vista
## previa de la pared). Solo lee el ratón y el mapa; no modifica nada de la simulación.

## Se emite cuando cambia la celda o la arista señaladas, o si el cursor entra/sale del mapa.
signal hover_changed

const CELL_FILL: Color = Color(1.0, 1.0, 1.0, 0.16)
const CELL_OUTLINE: Color = Color(1.0, 0.92, 0.45, 0.95)
const EDGE_COLOR: Color = Color(0.35, 0.85, 1.0, 1.0)
const EDGE_PREVIEW: Color = Color(0.35, 0.85, 1.0, 0.28)
const OUTLINE_WIDTH: float = 2.0
const EDGE_WIDTH: float = 4.0

## Celda señalada (solo válida si is_hovering).
var hover_cell: Vector2i = Vector2i.ZERO
## Arista señalada (solo válida si has_hover_edge).
var hover_edge: Edge = null
var is_hovering: bool = false
var has_hover_edge: bool = false

## En modo arista se resalta la arista más cercana en vez del rombo de la celda.
var edge_mode: bool = false:
	set(value):
		edge_mode = value
		queue_redraw()

var _grid: GridMap2D
var _level: int = 0
# Última posición del ratón en coordenadas de pantalla (del viewport). Se guarda en vez de
# consultar el ratón cada fotograma para que el resaltado también siga a la cámara en movimiento.
var _mouse_screen: Vector2 = Vector2.ZERO


func setup(grid: GridMap2D, level: int) -> void:
	_grid = grid
	_level = level
	z_index = 10
	_mouse_screen = get_viewport().get_mouse_position()


func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_mouse_screen = (event as InputEventMouse).position


func _process(_delta: float) -> void:
	var over_ui: bool = get_viewport().gui_get_hovered_control() != null
	var world_pos: Vector2 = get_canvas_transform().affine_inverse() * _mouse_screen
	var grid_pos: Vector2 = IsoProjection.world_to_grid(world_pos)
	var new_cell := Vector2i(floori(grid_pos.x), floori(grid_pos.y))
	var new_hovering: bool = not over_ui and _grid.in_bounds(new_cell)
	var new_edge: Edge = Edge.nearest(grid_pos)
	var new_has_edge: bool = not over_ui and _grid.is_edge_valid(new_edge, _level)

	var changed: bool = new_hovering != is_hovering or new_has_edge != has_hover_edge
	if new_hovering and new_cell != hover_cell:
		changed = true
	if new_has_edge and not new_edge.is_equal(hover_edge):
		changed = true
	if not changed:
		return

	is_hovering = new_hovering
	has_hover_edge = new_has_edge
	if new_hovering:
		hover_cell = new_cell
	if new_has_edge:
		hover_edge = new_edge
	queue_redraw()
	hover_changed.emit()


func _draw() -> void:
	if edge_mode:
		if has_hover_edge:
			_draw_edge(hover_edge)
	elif is_hovering:
		_draw_cell(hover_cell)


func _draw_cell(cell: Vector2i) -> void:
	var diamond: PackedVector2Array = IsoProjection.cell_diamond(cell)
	draw_colored_polygon(diamond, CELL_FILL)
	var outline: PackedVector2Array = diamond.duplicate()
	outline.append(diamond[0])
	draw_polyline(outline, CELL_OUTLINE, OUTLINE_WIDTH)


func _draw_edge(edge: Edge) -> void:
	var ends: PackedVector2Array = IsoProjection.edge_endpoints(edge)
	var up := Vector2(0, -TilesetFactory.WALL_HEIGHT)
	draw_colored_polygon(PackedVector2Array([ends[0], ends[1], ends[1] + up, ends[0] + up]), EDGE_PREVIEW)
	draw_line(ends[0], ends[1], EDGE_COLOR, EDGE_WIDTH)
