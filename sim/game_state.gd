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


## `catalog` permite probar con otros tipos; por defecto se carga data/room_types.json.
## `economy_rules` son las reglas de dinero; por defecto no cuesta nada (así los tests pueden
## construir sin límite) y el juego pasa EconomyRules.load_default().
func _init(map_size: Vector2i = DEFAULT_MAP_SIZE, catalog: RoomTypeCatalog = null,
		economy_rules: EconomyRules = null) -> void:
	grid = GridMap2D.new(map_size)
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


## Avanza la simulación con el tiempo real transcurrido (en segundos).
func tick(real_delta: float) -> void:
	var game_minutes: float = clock.tick(real_delta)
	spawner.tick(game_minutes)
	guests.tick(game_minutes)
	wander.tick(game_minutes)
	agents.tick(game_minutes)
	rooms.refresh()
	economy.update()
