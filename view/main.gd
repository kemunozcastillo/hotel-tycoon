extends Node2D
## Escena principal: crea la simulación y la conecta con la vista. Se construye por código.

const LEVEL: int = 0
const BACKGROUND_COLOR: Color = Color(0.09, 0.10, 0.12)
const CAMERA_MARGIN: float = 200.0 # cuánto puede salirse la cámara del mapa
const HUD_MARGIN: float = 8.0
const CLOCK_LABEL_WIDTH: float = 240.0
const STATUS_LABEL_WIDTH: float = 520.0
const MONEY_ROW_HEIGHT: float = 30.0 # la fila del saldo, entre el reloj y el resumen del hotel

var state: GameState
var level_view: LevelView
var camera: IsoCamera
var room_overlay: RoomOverlay
var cursor: CellCursor
var entrance_layer: EntranceLayer
var agents_layer: AgentsLayer
var agent_info_panel: AgentInfoPanel
var shape_preview: ShapePreview
var build_controller: BuildController
var hud: CanvasLayer
var toolbar: BuildToolbar
var room_info_panel: RoomInfoPanel
var clock_label: ClockLabel
var hotel_status_label: HotelStatusLabel
var wall_mode_bar: WallModeBar
var money_button: MoneyButton
var finance_panel: FinancePanel
var notice_label: NoticeLabel
var removal_mode_bar: RemovalModeBar
var inventory_panel: InventoryPanel


func _ready() -> void:
	RenderingServer.set_default_clear_color(BACKGROUND_COLOR)
	state = GameState.new(GameState.DEFAULT_MAP_SIZE, null, EconomyRules.load_default())

	level_view = LevelView.new()
	add_child(level_view)
	level_view.setup(state.grid, LEVEL)

	room_overlay = RoomOverlay.new()
	level_view.add_ground_overlay(room_overlay)
	room_overlay.setup(state.rooms, LEVEL)

	cursor = CellCursor.new()
	add_child(cursor)
	cursor.setup(state.grid, LEVEL)

	entrance_layer = EntranceLayer.new()
	add_child(entrance_layer)
	entrance_layer.setup(state.entrances, state.grid, LEVEL)

	agents_layer = AgentsLayer.new()
	add_child(agents_layer)
	agents_layer.setup(state.agents, state.guests, level_view.get_entities_root())

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
	room_info_panel.setup(state.rooms, state.guests.occupancy)

	agent_info_panel = AgentInfoPanel.new()
	hud.add_child(agent_info_panel)
	agent_info_panel.setup(state.agents, state.guests)
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

	hotel_status_label = HotelStatusLabel.new()
	hotel_status_label.anchor_left = 1.0
	hotel_status_label.anchor_right = 1.0
	hotel_status_label.offset_left = -STATUS_LABEL_WIDTH - HUD_MARGIN
	hotel_status_label.offset_right = -HUD_MARGIN
	hotel_status_label.offset_top = HUD_MARGIN + 28.0 + MONEY_ROW_HEIGHT
	hud.add_child(hotel_status_label)
	hotel_status_label.setup(state, LEVEL)

	money_button = MoneyButton.new()
	money_button.anchor_left = 1.0
	money_button.anchor_right = 1.0
	money_button.offset_left = -STATUS_LABEL_WIDTH - HUD_MARGIN
	money_button.offset_right = -HUD_MARGIN
	money_button.offset_top = HUD_MARGIN + 24.0
	hud.add_child(money_button)
	money_button.setup(state.ledger, state.clock)

	finance_panel = FinancePanel.new()
	hud.add_child(finance_panel)
	finance_panel.setup(state.ledger, state.clock)
	money_button.pressed.connect(finance_panel.toggle)

	notice_label = NoticeLabel.new()
	hud.add_child(notice_label)
	notice_label.setup()
	state.build.funds_insufficient.connect(_on_funds_insufficient)

	wall_mode_bar = WallModeBar.new()
	hud.add_child(wall_mode_bar)
	wall_mode_bar.setup(level_view.get_wall_mode())
	wall_mode_bar.mode_selected.connect(level_view.set_wall_mode)
	level_view.wall_mode_changed.connect(wall_mode_bar.set_mode)

	removal_mode_bar = RemovalModeBar.new()
	hud.add_child(removal_mode_bar)
	removal_mode_bar.setup(state.inventory.removal_mode)
	removal_mode_bar.mode_selected.connect(_on_removal_mode_selected)
	state.inventory.removal_mode_changed.connect(removal_mode_bar.set_mode)

	inventory_panel = InventoryPanel.new()
	hud.add_child(inventory_panel)
	inventory_panel.setup(state.inventory, state.economy, state.rules, state.storage)


func _process(delta: float) -> void:
	state.tick(delta)


func _on_removal_mode_selected(mode: Inventory.RemovalMode) -> void:
	state.inventory.removal_mode = mode


func _on_funds_insufficient(required_balance: int, balance: int) -> void:
	notice_label.show_notice(MoneyTexts.insufficient_text(required_balance, balance))


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


## Atajos: Espacio pausa/reanuda el reloj; 1, 2 y 3 eligen la velocidad; C cambia el modo de
## visualización de las paredes; F abre y cierra las finanzas; I el inventario; V alterna entre
## vender y guardar lo que se quita.
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_F:
			finance_panel.toggle()
		KEY_I:
			inventory_panel.toggle()
		KEY_V:
			if not key.ctrl_pressed:
				state.inventory.removal_mode = (Inventory.RemovalMode.STORE
						if state.inventory.removal_mode == Inventory.RemovalMode.SELL
						else Inventory.RemovalMode.SELL)
		KEY_C:
			if not key.ctrl_pressed:
				level_view.set_wall_mode(WallViewMode.next(level_view.get_wall_mode()))
		KEY_SPACE:
			state.clock.toggle_pause()
		KEY_1:
			state.clock.set_speed(GameClock.Speed.X1)
		KEY_2:
			state.clock.set_speed(GameClock.Speed.X2)
		KEY_3:
			state.clock.set_speed(GameClock.Speed.X3)
