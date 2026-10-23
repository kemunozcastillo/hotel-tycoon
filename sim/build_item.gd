class_name BuildItem
extends RefCounted
## Las piezas que se construyen y que tienen precio, se pueden guardar en el inventario y se
## pueden vender. Solo datos, sin lógica de economía.

## Tipo de pieza: un suelo (por celda), una pared o una puerta (por arista).
enum Kind { FLOOR, WALL, DOOR }
## Estado de una pieza. NUEVA: recién colocada (dentro del margen para deshacer un error) y sin
## uso anterior. USADA: lleva colocada más tiempo, o ya pasó por el inventario como usada. Al
## venderla vale menos (EconomyRules.sale_value).
enum Condition { NEW, USED }

const KIND_COUNT: int = 3
const CONDITION_COUNT: int = 2


## El tipo de pieza que corresponde a lo que hay sobre una arista (-1 si no hay nada).
static func kind_of_edge(type: CellTypes.EdgeType) -> int:
	match type:
		CellTypes.EdgeType.WALL:
			return Kind.WALL
		CellTypes.EdgeType.DOOR:
			return Kind.DOOR
		_:
			return -1


static func label(kind: BuildItem.Kind) -> String:
	match kind:
		BuildItem.Kind.WALL:
			return "Pared"
		BuildItem.Kind.DOOR:
			return "Puerta"
		_:
			return "Suelo"


static func label_plural(kind: BuildItem.Kind) -> String:
	match kind:
		BuildItem.Kind.WALL:
			return "Paredes"
		BuildItem.Kind.DOOR:
			return "Puertas"
		_:
			return "Suelos"
