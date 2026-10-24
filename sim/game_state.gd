class_name GameState
extends RefCounted
## Raíz de la simulación: agrupa todo el estado del juego. No conoce ninguna vista.

const DEFAULT_MAP_SIZE: Vector2i = Vector2i(32, 32)

var grid: GridMap2D
var build: BuildCommands
var clock: GameClock
var rules: EconomyRules
var ledger: Ledger
var inventory: Inventory
var pieces: PlacedPieces
var room_types: RoomTypeCatalog
var rooms: RoomRegistry
var agents: AgentRegistry
var wander: WanderBehavior
var entrances: EntrancePoints
var guests: GuestRegistry
var spawner: GuestSpawner
var economy: Economy
var storage: StorageCapacity


## `catalog` permite probar con otros tipos; por defecto se carga data/room_types.json.
## `economy_rules` son las reglas de dinero; por defecto no cuesta nada (así los tests pueden
## construir sin límite) y el juego pasa EconomyRules.load_default().
## El mapa empieza sin terreno (solo se pisa lo construido); el trazado del exterior lo pone
## `new_hotel_game` o la partida cargada.
func _init(map_size: Vector2i = DEFAULT_MAP_SIZE, catalog: RoomTypeCatalog = null,
		economy_rules: EconomyRules = null, terrain_catalog: TerrainCatalog = null) -> void:
	grid = GridMap2D.new(map_size, terrain_catalog if terrain_catalog != null else TerrainCatalog.load_default())
	clock = GameClock.new()
	rules = economy_rules if economy_rules != null else EconomyRules.without_costs()
	ledger = Ledger.new(rules.start_money, clock)
	inventory = Inventory.new()
	pieces = PlacedPieces.new(grid, clock, rules)
	build = BuildCommands.new(grid, rules, ledger, inventory, pieces)
	room_types = catalog if catalog != null else RoomTypeCatalog.load_default()
	rooms = RoomRegistry.new(grid, room_types)
	agents = AgentRegistry.new(grid)
	wander = WanderBehavior.new(grid, agents)
	entrances = EntrancePoints.new(grid)
	guests = GuestRegistry.new(grid, agents, rooms, entrances)
	spawner = GuestSpawner.new(guests)
	economy = Economy.new(rules, ledger, inventory, rooms, room_types, grid, guests, clock)
	storage = StorageCapacity.new(rooms, room_types, grid)
	if rules.limited_storage:
		inventory.capacity_provider = storage.get_capacity


## Una partida nueva del juego real: mapa de tamaño normal con el exterior trazado (calle, acera y
## césped) y los puntos de llegada de los huéspedes en los extremos de la acera.
static func new_hotel_game(economy_rules: EconomyRules = null) -> GameState:
	var state := GameState.new(DEFAULT_MAP_SIZE, null, economy_rules if economy_rules != null else EconomyRules.load_default())
	TerrainGenerator.apply_default_layout(state.grid, 0)
	for cell: Vector2i in TerrainGenerator.arrival_cells(state.grid.size):
		state.entrances.add(cell, 0)
	return state


## Avanza la simulación con el tiempo real transcurrido (en segundos).
func tick(real_delta: float) -> void:
	var game_minutes: float = clock.tick(real_delta)
	spawner.tick(game_minutes)
	guests.tick(game_minutes)
	wander.tick(game_minutes)
	agents.tick(game_minutes)
	rooms.refresh()
	economy.update()
