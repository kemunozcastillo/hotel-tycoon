extends Node2D
## Escena principal: crea la simulación y la conecta con la vista. Se construye por código.

const LEVEL: int = 0
const BACKGROUND_COLOR: Color = Color(0.09, 0.10, 0.12)
const CAMERA_MARGIN: float = 200.0 # cuánto puede salirse la cámara del mapa
const HUD_MARGIN: float = 8.0

var state: GameState
var level_view: LevelView
var camera: IsoCamera
var cursor: CellCursor
var build_controller: BuildController
var hud: CanvasLayer
var toolbar: BuildToolbar


func _ready() -> void:
	RenderingServer.set_default_clear_color(BACKGROUND_COLOR)
	state = GameState.new()

	level_view = LevelView.new()
	add_child(level_view)
	level_view.setup(state.grid, LEVEL)

	cursor = CellCursor.new()
	add_child(cursor)
	cursor.setup(state.grid, LEVEL)

	build_controller = BuildController.new()
	add_child(build_controller)
	build_controller.setup(state, cursor, LEVEL)

	camera = IsoCamera.new()
	camera.position = IsoProjection.grid_to_world(Vector2(state.grid.size) * 0.5)
	add_child(camera)
	camera.set_bounds(IsoProjection.map_world_bounds(state.grid.size).grow(CAMERA_MARGIN))

	hud = CanvasLayer.new()
	add_child(hud)
	toolbar = BuildToolbar.new()
	toolbar.position = Vector2(HUD_MARGIN, HUD_MARGIN)
	hud.add_child(toolbar)
	toolbar.setup(build_controller)
