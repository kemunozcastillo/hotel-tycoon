class_name WallStyle
extends RefCounted
## Alturas con las que se puede dibujar una pared o una puerta (modo corte de paredes).

enum Height {
	FULL, ## Pared completa.
	LOW, ## Pared baja: deja ver lo que hay detrás.
	FLAT, ## Solo una línea en la base, para saber dónde está.
}

## Altura en píxeles de cada nivel.
const FULL_PIXELS: int = 48
const LOW_PIXELS: int = 14
const FLAT_PIXELS: int = 3


static func pixels(height: WallStyle.Height) -> int:
	match height:
		WallStyle.Height.LOW:
			return LOW_PIXELS
		WallStyle.Height.FLAT:
			return FLAT_PIXELS
		_:
			return FULL_PIXELS
