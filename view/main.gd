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
## Dónde se guardan las partidas (las pruebas lo cambian para no tocar las del jugador).
var save_directory: String = SaveGame.SAVE_DIR
## Si se guarda sola, en la ranura de autoguardado, al empezar cada día de juego.
var autosave_enabled: bool = true
var _autosave_day: int = 0


func _ready() -> void:
	RenderingServer.set_default_clear_color(BACKGROUND_COLOR)
	state = GameState.new_hotel_game()
	_build()


## Crea todo lo visual (y sus conexiones) a partir de `state`. Se llama al empezar y al cargar una
## partida, que sustituye a `state` y lo reconstruye todo (la vista no guarda estado de juego).
func _build() -> void:
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
	_autosave_day = state.clock.get_day()

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
	var day: int = state.clock.get_day()
	if day != _autosave_day:
		_autosave_day = day
		if autosave_enabled:
			var error: String = SaveGame.save_slot(state, SaveGame.AUTO_SLOT, save_directory)
			if not error.is_empty():
				notice_label.show_notice("No se pudo autoguardar: %s" % error)


## Guarda la partida en una ranura. Devuelve true si fue bien.
func save_game(slot: StringName = SaveGame.MANUAL_SLOT) -> bool:
	var error: String = SaveGame.save_slot(state, slot, save_directory)
	if error.is_empty():
		notice_label.show_notice("Partida guardada")
		return true
	notice_label.show_notice("No se pudo guardar: %s" % error)
	return false


## Carga una ranura: construye el estado aparte y, solo si es válido, sustituye al actual y rehace
## la vista. Se conservan la cámara y el modo de paredes. Devuelve true si cargó.
func load_game(slot: StringName = SaveGame.MANUAL_SLOT) -> bool:
	var result: SaveGame.LoadResult = SaveGame.load_slot(slot, state.rules, state.room_types, save_directory)
	if not result.is_ok():
		notice_label.show_notice("No se pudo cargar: %s" % result.errors[0], 5.0)
		return false
	var camera_position: Vector2 = camera.position
	var camera_zoom: Vector2 = camera.zoom
	var wall_mode: WallViewMode.Mode = level_view.get_wall_mode()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	state = result.state
	_build()
	camera.position = camera_position
	camera.zoom = camera_zoom
	level_view.set_wall_mode(wall_mode)
	var message: String = "Partida cargada" if slot == SaveGame.MANUAL_SLOT else "Autoguardado cargado"
	if not result.warnings.is_empty():
		message += " (%s)" % result.warnings[0]
	notice_label.show_notice(message)
	return true


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
## vender y guardar lo que se quita; F5 guarda la partida, F9 la carga y Mayús+F9 carga el
## autoguardado.
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_F:
			finance_panel.toggle()
		KEY_F5:
			save_game()
		KEY_F9:
			load_game(SaveGame.AUTO_SLOT if key.shift_pressed else SaveGame.MANUAL_SLOT)
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
