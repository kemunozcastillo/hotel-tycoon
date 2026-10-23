# Hotel Tycoon

Juego de gestión de hotel con vista isométrica, hecho en **Godot 4.7** con **GDScript** (sin C#).
Referencias de género: Project Hospital y Prison Architect.

## Regla de oro: simulación separada de la vista

- `sim/` contiene la **lógica pura**: cuadrícula, habitaciones, agentes, economía, tiempo.
  Solo clases `RefCounted` / `Resource`. **Prohibido** usar nodos visuales, la cámara o la
  proyección isométrica. Debe poder ejecutarse sin ventana (headless).
- `view/` contiene todo lo **visual**: `TileMapLayer`, sprites, cámara, cursor.
  Solo **lee** el estado de `sim/` y reacciona a sus **señales**. Nunca guarda estado de juego.
- `ui/` contiene los controles de interfaz (botones, etiquetas). Habla con `sim/` solo a
  través de los comandos (`BuildCommands`) y reacciona a señales.
- Todo cambio del mundo pasa primero por `sim/` (comandos) y la vista lo refleja por señal.
  La vista nunca modifica sus tiles "por su cuenta".

## Modelo de la cuadrícula

- Una celda es un `Vector2i`; el piso (nivel) es un `int` aparte. Hoy solo existe el nivel 0,
  pero la API (`GridMap2D`) ya admite varios niveles.
- **Suelo** por celda. **Paredes por arista** (no por celda), para que una habitación de 2x2
  ocupe 2x2. Cada celda "posee" su arista norte (eje X) y su arista oeste (eje Y); las aristas
  sur y este son las de la celda vecina. Ver `sim/edge.gd`.
- Convención de ejes de la cuadrícula: X crece hacia abajo-derecha en pantalla, Y hacia
  abajo-izquierda (rombo 2:1 de 64x32, `TileSet.TILE_LAYOUT_DIAMOND_DOWN`).

## Convenciones de GDScript

- **Tipado estático en todo**: variables, parámetros, retornos y arrays (`Array[Vector2i]`).
- Nombres (clases, funciones, variables, señales, archivos) **en inglés**; `snake_case` para
  funciones/variables/archivos, `PascalCase` para `class_name`, `UPPER_CASE` para constantes.
- **Comentarios en español.**
- Variables privadas con prefijo `_`. Señales en pasado (`cell_changed`).
- Escenas (`.tscn`) y `project.godot`: tocarlos a mano solo cuando sea imprescindible; las
  escenas se construyen por código siempre que sea simple.
- Cada pieza de `sim/` tiene su test en `tests/`.

## Estructura de carpetas

```
sim/     lógica pura (cuadrícula, aristas, comandos de construcción, reloj, estado)
view/    TileMapLayer, cámara, cursor, controlador de construcción, escena principal
ui/      barra de construcción, etiqueta del reloj
data/    datos del juego (vacío por ahora)
assets/  arte y audio (vacío; el arte provisional se genera por código)
tests/   pruebas headless de sim/ y herramientas de verificación
```

## Cómo ejecutar

El ejecutable de Godot está en una carpeta llamada `Godot_v4.7.2-stable_win64.exe`; para la
terminal se usa el `_console.exe` que contiene:

```bash
GODOT="C:/Proyectos/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"

# Jugar (abre ventana)
"$GODOT" --path .

# Comprobar errores de parseo
"$GODOT" --headless --path . --quit

# Pruebas de sim/ (sin ventana). Si se añaden clases con class_name, primero
# hay que regenerar la caché de clases globales:
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . --script res://tests/run_tests.gd
```

## Controles

- Cámara: `WASD` / flechas, botón central + arrastrar, rueda para zoom.
- Construcción: elegir herramienta en la barra (Suelo / Pared); clic izquierdo coloca,
  clic derecho quita, se puede arrastrar. `Esc` deselecciona la herramienta.
- Reloj: `Espacio` pausa, `1` / `2` / `3` velocidades.
