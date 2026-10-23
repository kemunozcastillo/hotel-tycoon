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
- **Suelo** por celda. **Paredes y puertas por arista** (no por celda), para que una habitación
  de 2x2 ocupe 2x2. Cada celda "posee" su arista norte (eje X) y su arista oeste (eje Y); las
  aristas sur y este son las de la celda vecina. Ver `sim/edge.gd`. Una arista es
  `CellTypes.EdgeType` `NONE`, `WALL` o `DOOR`.
- **Dos nociones de bloqueo** en `GridMap2D`: `is_blocked_between` (movimiento: solo lo bloquea
  una pared, la puerta se cruza) e `is_room_boundary` (separa habitaciones: pared o puerta).
- **Habitaciones**: derivadas del mapa, nunca se editan a mano. `RoomDetector` (función pura)
  encuentra las regiones cerradas; `RoomRegistry` las guarda con **ids estables** (una habitación
  que se amplía o se divide conserva el id en la parte con más celdas en común), recalcula
  de forma perezosa (el mapa solo marca "sucio"; `GameState.tick` llama a `refresh()`) y emite
  `room_created/changed/removed`. Una región cerrada sin suelo completo también es habitación
  (`has_complete_floor = false`).
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
sim/     lógica pura: GridMap2D (niveles, suelo, paredes y puertas por arista), Edge, LevelLayer,
         GridShapes (rectángulos), BuildCommands, Room / RoomDetector / RoomRegistry,
         GameClock, GameState (raíz de la simulación)
view/    main.tscn/main.gd (escena principal), IsoProjection (única que conoce el rombo 64x32),
         TilesetFactory (arte provisional por código), LevelView (TileMapLayer), GridLines,
         IsoCamera, CellCursor, ShapePreview, RoomOverlay, BuildController
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
  cámara, construcción (un baño de 2x2 con 8 clics), formas con Mayús, herramienta Habitación,
  puertas, detección de habitaciones y reloj. Admite hasta cinco rutas de PNG tras `--`:
  construcción, resaltado de celda, resaltado de arista, vista previa de forma y puerta.
- `tests/capture_view.gd`: captura una escena de demostración con varias habitaciones.

```bash
"$GODOT" --path . --script res://tests/interaction_check.gd -- build.png cell.png edge.png preview.png door.png
"$GODOT" --path . --script res://tests/capture_view.gd -- demo.png
```

Mientras corre `interaction_check.gd` conviene no mover el ratón sobre su ventana: los eventos
reales se mezclan con los inyectados y pueden dar fallos falsos (si pasa, repetir).

Nota: el ratón inyectado no mueve el cursor real del sistema, por eso `CellCursor` guarda la
última posición recibida por `_input` en vez de consultar el ratón del viewport.

## Detalles a tener en cuenta

- `IsoProjection` coincide con `TileMapLayer.map_to_local()` (la caja de la celda (0,0) empieza en
  el origen); `tests/test_iso_projection.gd` lo comprueba contra un `TileMapLayer` real.
- Las paredes y puertas de la vista viven en una sola `TileMapLayer` con `y_sort_enabled`; cada
  celda dibuja las aristas que posee (norte = X, oeste = Y) con un tile por combinación de tipos
  (`TilesetFactory.wall_coords`: 3 x 3 menos "nada y nada" = 8 tiles).
- El tinte de habitaciones (`RoomOverlay`) se inserta entre el suelo y las paredes
  (`LevelView.add_ground_overlay`) para no teñir las paredes; su etiqueta flota por encima.
- Los comandos de forma (`fill_rect_floor`, `outline_rect_walls`, `build_room`, ...) solo añaden
  lo que falta, respetan las puertas existentes y devuelven cuántas celdas o aristas cambiaron.
  `demolish_room` sí quita puertas.
- En el modo arista, el punto del ratón se interpreta sobre el plano del suelo, no sobre la
  altura de la pared.
- Hay un solo nivel visible (0). `GridMap2D` y `LevelView` ya reciben el nivel como parámetro.
- Con `class_name` no se pueden calificar los enums con el nombre corto dentro de la propia clase
  en firmas de funciones (`Edge.Side`, no `Side`).

## Controles

- Cámara: `WASD` / flechas, botón central + arrastrar, rueda para zoom.
- Construcción: elegir herramienta en la barra (Suelo / Pared / Puerta / Habitación); clic
  izquierdo coloca, clic derecho quita. Suelo y Pared pintan arrastrando; con `Mayús` pulsado al
  empezar, el arrastre define un rectángulo (suelo relleno o perímetro de paredes). Habitación
  siempre usa rectángulo y crea suelo y paredes (clic derecho la derriba). `Esc` cancela el
  arrastre en curso y, si no hay, deselecciona la herramienta.
- Reloj: `Espacio` pausa, `1` / `2` / `3` velocidades.
