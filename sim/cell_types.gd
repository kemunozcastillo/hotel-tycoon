class_name CellTypes
extends RefCounted
## Enumeraciones de los tipos de contenido de una celda. Solo datos, sin lógica.

## Tipo de suelo de una celda. NONE significa "sin construir".
enum FloorType { NONE, BASIC }

## Tipo de lo que hay sobre una arista. WALL bloquea el paso; DOOR deja pasar pero separa
## habitaciones.
enum EdgeType { NONE, WALL, DOOR }
