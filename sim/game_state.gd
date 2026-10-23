class_name GameState
extends RefCounted
## Raíz de la simulación: agrupa todo el estado del juego. No conoce ninguna vista.

const DEFAULT_MAP_SIZE: Vector2i = Vector2i(32, 32)

var grid: GridMap2D
var build: BuildCommands
var clock: GameClock
var room_types: RoomTypeCatalog
var rooms: RoomRegistry
var agents: AgentRegistry
var wander: WanderBehavior
var entrances: EntrancePoints
var guests: GuestRegistry


## `catalog` permite probar con otros tipos; por defecto se carga data/room_types.json.
func _init(map_size: Vector2i = DEFAULT_MAP_SIZE, catalog: RoomTypeCatalog = null) -> void:
	grid = GridMap2D.new(map_size)
	build = BuildCommands.new(grid)
	clock = GameClock.new()
	room_types = catalog if catalog != null else RoomTypeCatalog.load_default()
	rooms = RoomRegistry.new(grid, room_types)
	agents = AgentRegistry.new(grid)
	wander = WanderBehavior.new(grid, agents)
	entrances = EntrancePoints.new(grid)
	guests = GuestRegistry.new(grid, agents, rooms, entrances)


## Avanza la simulación con el tiempo real transcurrido (en segundos).
func tick(real_delta: float) -> void:
	var game_minutes: float = clock.tick(real_delta)
	guests.tick(game_minutes)
	wander.tick(game_minutes)
	agents.tick(game_minutes)
	rooms.refresh()
