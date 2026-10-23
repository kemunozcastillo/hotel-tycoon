class_name WallViewMode
extends RefCounted
## Modos de visualización de las paredes (corte de paredes). Es una preferencia de la vista:
## no existe en `sim/` ni se guarda entre sesiones.

enum Mode {
	UP, ## Todas las paredes completas.
	CUTAWAY, ## Las que tapan algo, bajas; las del fondo, completas.
	LOW, ## Todas bajas.
	DOWN, ## Solo una línea en la base de cada pared y puerta.
}

const MODE_COUNT: int = 4


## Modo con el que arranca el juego.
static func default_mode() -> WallViewMode.Mode:
	return WallViewMode.Mode.CUTAWAY


## El modo siguiente al indicado (después del último vuelve al primero).
static func next(mode: WallViewMode.Mode) -> WallViewMode.Mode:
	return ((mode + 1) % MODE_COUNT) as WallViewMode.Mode


static func label(mode: WallViewMode.Mode) -> String:
	match mode:
		WallViewMode.Mode.UP:
			return "Arriba"
		WallViewMode.Mode.CUTAWAY:
			return "Corte"
		WallViewMode.Mode.LOW:
			return "Bajas"
		_:
			return "Ocultas"
