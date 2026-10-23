extends Node2D
## Escena principal: crea la simulación y la conecta con la vista. Se construye por código.

const LEVEL: int = 0
const BACKGROUND_COLOR: Color = Color(0.09, 0.10, 0.12)
const CAMERA_MARGIN: float = 200.0 # cuánto puede salirse la cámara del mapa
const HUD_MARGIN: float = 8.0
const CLOCK_LABEL_WIDTH: float = 240.0

var state: GameState
var level_view: LevelView
var camera: IsoCamera
var room_overlay: RoomOverlay
var cursor: CellCursor
var agents_layer: AgentsLayer
var agent_info_panel: AgentInfoPanel
var shape_preview: ShapePreview
var build_controller: BuildController
var hud: CanvasLayer
var toolbar: BuildToolbar
var room_info_panel: RoomInfoPanel
var clock_label: ClockLabel


func _ready() -> void:
	RenderingServer.set_default_clear_color(BACKGROUND_COLOR)
	state = GameState.new()

	level_view = LevelView.new()
	add_child(level_view)
	level_view.setup(state.grid, LEVEL)

	room_overlay = RoomOverlay.new()
	level_view.add_ground_overlay(room_overlay)
	room_overlay.setup(state.rooms, LEVEL)

	cursor = CellCursor.new()
	add_child(cursor)
	cursor.setup(state.grid, LEVEL)

	agents_layer = AgentsLayer.new()
	add_child(agents_layer)
	agents_layer.setup(state.agents, level_view.get_entities_root())

	shape_preview = ShapePreview.new()
	add_child(shape_preview)

	build_controller = BuildController.new()
	add_child(build_controller)
	build_controller.setup(state, cursor, shape_preview, LEVEL)

	camera = IsoCamera.new()
	camera.position = IsoProjection.grid_to_world(Vector2(state.grid.size) * 0.5)
	add_child(camera)
	camera.set_bounds(IsoProjection.map_world_bounds(state.grid.size).grow(CAMERA_MARGIN))

	hud = CanvasLayer.new()
	add_child(hud)
	toolbar = BuildToolbar.new()
	toolbar.position = Vector2(HUD_MARGIN, HUD_MARGIN)
	hud.add_child(toolbar)
	toolbar.setup(build_controller, state.room_types)

	room_info_panel = RoomInfoPanel.new()
	hud.add_child(room_info_panel)
	room_info_panel.setup(state.rooms)

	agent_info_panel = AgentInfoPanel.new()
	hud.add_child(agent_info_panel)
	agent_info_panel.setup(state.agents)
	build_controller.agent_selected.connect(_on_agent_selected)

	# La habitación bajo el cursor se resalta y se describe en el panel.
	cursor.hover_changed.connect(_refresh_hovered_room)
	state.rooms.room_created.connect(_on_room_event)
	state.rooms.room_changed.connect(_on_room_event)
	state.rooms.room_removed.connect(_on_room_event)
	state.rooms.room_type_changed.connect(_on_room_event)

	clock_label = ClockLabel.new()
	clock_label.anchor_left = 1.0
	clock_label.anchor_right = 1.0
	clock_label.offset_left = -CLOCK_LABEL_WIDTH - HUD_MARGIN
	clock_label.offset_right = -HUD_MARGIN
	clock_label.offset_top = HUD_MARGIN
	hud.add_child(clock_label)
	clock_label.setup(state.clock)


func _process(delta: float) -> void:
	state.tick(delta)


func _on_agent_selected(agent_id: int) -> void:
	agents_layer.set_selected(agent_id)
	agent_info_panel.show_agent(agent_id)


func _on_room_event(_room: Room) -> void:
	_refresh_hovered_room()


func _refresh_hovered_room() -> void:
	var room: Room = null
	if cursor.is_hovering:
		room = state.rooms.get_room_at(cursor.hover_cell, LEVEL)
	room_overlay.set_hovered_room(room)
	room_info_panel.show_room(room)


## Atajos del reloj: Espacio pausa/reanuda; 1, 2 y 3 eligen la velocidad.
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_SPACE:
			state.clock.toggle_pause()
		KEY_1:
			state.clock.set_speed(GameClock.Speed.X1)
		KEY_2:
			state.clock.set_speed(GameClock.Speed.X2)
		KEY_3:
			state.clock.set_speed(GameClock.Speed.X3)
