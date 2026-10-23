class_name GameState
extends RefCounted
## Raíz de la simulación: agrupa todo el estado del juego. No conoce ninguna vista.

const DEFAULT_MAP_SIZE: Vector2i = Vector2i(32, 32)

var grid: GridMap2D
var build: BuildCommands
var clock: GameClock


func _init(map_size: Vector2i = DEFAULT_MAP_SIZE) -> void:
	grid = GridMap2D.new(map_size)
	build = BuildCommands.new(grid)
	clock = GameClock.new()


## Avanza la simulación con el tiempo real transcurrido (en segundos).
func tick(real_delta: float) -> void:
	clock.tick(real_delta)
