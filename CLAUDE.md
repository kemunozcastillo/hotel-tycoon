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
sim/     lógica pura: GridMap2D (niveles, suelo, paredes por arista), Edge, LevelLayer,
         BuildCommands, GameClock, GameState (raíz de la simulación)
view/    main.tscn/main.gd (escena principal), IsoProjection (única que conoce el rombo 64x32),
         TilesetFactory (arte provisional por código), LevelView (TileMapLayer), GridLines,
         IsoCamera, CellCursor, BuildController
ui/      BuildToolbar (herramientas), ClockLabel (día, hora y velocidad)
data/    datos del juego (vacío por ahora)
assets/  arte y audio (vacío; el arte provisional se genera por código)
tests/   suites headless de sim/ y view/ más herramientas de verificación con ventana
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

# Pruebas headless (sin ventana). Si se añaden clases con class_name, primero
# hay que regenerar la caché de clases globales:
"$GODOT" --headless --path . --import
timeout 60 "$GODOT" --headless --path . --script res://tests/run_tests.gd
```

Usar siempre `timeout`: si un script tiene un error de parseo, Godot no termina solo.
Código de salida 1 si algún test falla. Para añadir una suite: crear `tests/test_xxx.gd`
(`extends TestCase`, métodos `test_*`) y registrarla en `SUITES` de `tests/run_tests.gd`.

### Verificación con ventana (necesita GPU, no es headless)

- `tests/interaction_check.gd`: inyecta ratón y teclado en la escena real y comprueba hover,
  cámara, construcción (incluido un baño de 2x2 con 8 clics) y reloj. Admite hasta tres rutas
  de PNG tras `--`: resultado de construir, resaltado de celda y resaltado de arista.
- `tests/capture_view.gd`: captura una escena de demostración con habitaciones.

```bash
"$GODOT" --path . --script res://tests/interaction_check.gd -- build.png cell.png edge.png
"$GODOT" --path . --script res://tests/capture_view.gd -- demo.png
```

Nota: el ratón inyectado no mueve el cursor real del sistema, por eso `CellCursor` guarda la
última posición recibida por `_input` en vez de consultar el ratón del viewport.

## Detalles a tener en cuenta

- `IsoProjection` coincide con `TileMapLayer.map_to_local()` (la caja de la celda (0,0) empieza en
  el origen); `tests/test_iso_projection.gd` lo comprueba contra un `TileMapLayer` real.
- Las paredes de la vista viven en una sola `TileMapLayer` con `y_sort_enabled`; cada celda dibuja
  las aristas que posee (norte = X, oeste = Y) con un tile de tres variantes: X, Y o ambas.
- En el modo arista, el punto del ratón se interpreta sobre el plano del suelo, no sobre la
  altura de la pared.
- Hay un solo nivel visible (0). `GridMap2D` y `LevelView` ya reciben el nivel como parámetro.
- Con `class_name` no se pueden calificar los enums con el nombre corto dentro de la propia clase
  en firmas de funciones (`Edge.Side`, no `Side`).

## Controles

- Cámara: `WASD` / flechas, botón central + arrastrar, rueda para zoom.
- Construcción: elegir herramienta en la barra (Suelo / Pared); clic izquierdo coloca,
  clic derecho quita, se puede arrastrar. `Esc` deselecciona la herramienta.
- Reloj: `Espacio` pausa, `1` / `2` / `3` velocidades.
