extends Node2D
## Escena principal: crea la simulación y la conecta con la vista. Se construye por código.

const LEVEL: int = 0
const BACKGROUND_COLOR: Color = Color(0.09, 0.10, 0.12)
const CAMERA_MARGIN: float = 200.0 # cuánto puede salirse la cámara del mapa

var state: GameState
var level_view: LevelView
var camera: IsoCamera
var cursor: CellCursor


func _ready() -> void:
	RenderingServer.set_default_clear_color(BACKGROUND_COLOR)
	state = GameState.new()

	level_view = LevelView.new()
	add_child(level_view)
	level_view.setup(state.grid, LEVEL)

	cursor = CellCursor.new()
	add_child(cursor)
	cursor.setup(state.grid, LEVEL)

	camera = IsoCamera.new()
	camera.position = IsoProjection.grid_to_world(Vector2(state.grid.size) * 0.5)
	add_child(camera)
	camera.set_bounds(IsoProjection.map_world_bounds(state.grid.size).grow(CAMERA_MARGIN))
