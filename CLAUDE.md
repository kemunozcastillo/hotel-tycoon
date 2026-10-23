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
- **Tipos de habitación** (dormitorio, baño...): los define `data/room_types.json` (id, nombre,
  color y requisitos: `min_area`, `max_area` (0 = sin límite), `min_short_side`, `min_doors`,
  `requires_complete_floor`). `RoomTypeCatalog` lo carga y descarta las entradas mal formadas
  con un aviso en `warnings` (nunca rompe el arranque). El **jugador asigna** el tipo
  (`RoomRegistry.set_room_type`); se guarda en `Room.type_id` y sigue al id estable: se conserva
  al ampliar, la parte nueva de una división queda sin tipo y al derribar se pierde.
  `RoomValidator.evaluate(room, type)` devuelve un `RoomStatus` con un `RoomCheck` por requisito
  definido; una habitación que deja de cumplir **conserva el tipo** y se marca no operativa.
  El lado corto mínimo se mide sobre el rectángulo que contiene a la habitación (una en L
  de 3 celdas cuenta como lado 2). Para añadir un tipo basta con una entrada nueva en el JSON.
  Al exportar el juego hay que incluir `data/*.json` en el filtro de exportación del preset.
- **Caminar**: `GridMap2D.is_walkable(celda, nivel)` es la **única** función que decide si se
  puede pisar una celda (hoy: tiene suelo construido) y `get_walk_cost` su coste (hoy siempre
  1.0, debe ser >= 1.0). Pathfinder, agentes y paseo preguntan solo ahí y nunca miran el suelo.
  Cuando exista un terreno predefinido (calle, acera, pasto: catálogo `data/terrain_types.json`
  con id, caminable, coste y color, y una capa de terreno por nivel bajo el suelo construido), se
  amplía en ese único sitio. Entonces habrá que limitar por zonas o tareas adónde pasea cada
  agente. `GridMap2D.revision` sube con cada cambio del mapa (para invalidar rutas guardadas).
- **Pathfinder** (`sim/pathfinder.gd`): A* de 8 direcciones sobre `is_walkable` y paredes. Un
  paso diagonal solo es válido si los dos pasos ortogonales que lo rodean también lo son (no se
  cortan esquinas). La puerta se cruza, la pared no. `find_path` devuelve la ruta con origen y
  destino incluidos (vacía si no hay camino o se supera `DEFAULT_MAX_EXPANSIONS`). El origen
  puede no ser pisable (un agente sobre suelo recién quitado debe poder salir).
- **Agentes** (`Agent`, `AgentRegistry`): se mueven por una ruta a `Agent.DEFAULT_SPEED` = 2
  celdas por **minuto de juego** (el reloj manda: pausa = quietos, x3 = el triple). Posición
  continua en coordenadas de cuadrícula (centro de celda = x+0.5, y+0.5). Si el mapa cambia
  (`revision`) comprueban su ruta, la recalculan si hace falta y quedan `BLOCKED` (reintentando
  al cambiar el mapa) si ya no hay camino. Sin colisiones entre agentes. `WanderBehavior` es el
  comportamiento **provisional**: los agentes libres con `wanders` esperan 1-4 minutos y van a
  una celda alcanzable a <= 12 celdas; se sustituirá por necesidades y tareas. Tiene semilla
  (`state.wander.set_seed`) para pruebas reproducibles.
- **Huéspedes** (`Guest`, `GuestRegistry`, `RoomOccupancy`, `GuestSpawner`, `EntrancePoints`): un
  `Guest` es la parte "de hotel" de un `Agent` (su cuerpo; `wanders = false`). Ciclo: llega por una
  **entrada** (marcador que coloca el jugador sobre una celda con suelo; provisional hasta que haya
  exterior caminable) → camina a la **recepción** (tipo `reception`, la operativa más cercana por
  coste de ruta) → espera en un puesto propio de la recepción (el mostrador es la celda más lejana a
  la puerta) → **check-in** de uno en uno, por orden de llegada, 3 min → se le asigna el dormitorio
  (`bedroom`) **libre, operativo y alcanzable más cercano** (`Pathfinder.reachable_costs` desde donde
  está) y se **reserva** en `RoomOccupancy` en ese instante (nunca dos huéspedes en una
  habitación) → se aloja 2-6 h de juego → se va por la entrada, liberando la habitación. Sin
  dormitorio libre espera en la recepción y se reintenta cuando cambia el mapa, las habitaciones o
  la ocupación; a los 60 min de espera se marcha enfadado. Si su habitación deja de ser válida
  (derribada, sin tipo, no operativa) la pierde, recupera la paciencia y busca otra. Sin camino al
  irse (o sin entrada válida) desaparece en el sitio. Los ids `bedroom` y `reception` están en
  `GuestRegistry` y deben existir en `data/room_types.json`. `GuestSpawner` hace llegar un huésped
  cada 15-45 min de juego mientras haya entrada válida y recepción operativa y haya menos de 4
  esperando. Todos estos tiempos son constantes provisionales con comentario. Sin valoraciones
  todavía. `GameState.tick` ordena: spawner, huéspedes, paseo, agentes, habitaciones, economía.
- **Economía** (`sim/`, todo enteros en €): reglas en `data/economy.json` (`EconomyRules`: dinero
  inicial 2000, precio de construir suelo 10 / pared 8 / puerta 25, venta 100% si la pieza es
  **nueva** y 85% si es **usada**, ventana de "nueva" 60 min, anticipo 50%; `load_default` cae a
  valores por defecto con avisos en `warnings` si el JSON está mal). Los precios de estancia y el
  mantenimiento diario viven en `data/room_types.json` (`stay_price`, `stay_price_per_extra_cell`
  sobre el área mínima, `daily_upkeep`). **`GameState` usa por defecto `EconomyRules.without_costs()`**
  (construir gratis, sin cobros) para que los tests de otras fases no necesiten dinero; el juego real
  pasa `EconomyRules.load_default()` (`view/main.gd`) y los tests de economía pasan sus reglas
  (`HotelFixture.build(..., reglas)`). `Ledger` guarda el saldo y los movimientos por categoría
  (construcción, venta, anticipo, liquidación, anticipo devuelto, mantenimiento) con totales por
  día; el saldo solo baja de 0 por mantenimiento o devoluciones, nunca por construir.
- **Construir cuesta**: `BuildCommands` funciona en tres pasos, **plan → presupuesto → ejecución**:
  cada orden se convierte en una lista de `BuildOp`, `BuildQuote.evaluate` la simula en orden (coste,
  ingresos, piezas del inventario, vendidas, guardadas, saldo necesario) y `execute` aplica
  exactamente esa lista. Las formas son **atómicas**: si no hay saldo no se construye ni una celda y
  se emite `funds_insufficient`. La vista previa (`ShapePreview`) muestra el presupuesto de la misma
  lista. Se usan primero las piezas del `Inventory` (gratis, las usadas antes). Nunca se gana dinero
  construyendo y vendiendo (el valor de venta es <= el precio y la marca de "usada" persiste).
- **Piezas nuevas y usadas**: `PlacedPieces` anota cuándo se colocó cada pieza (por señales de la
  cuadrícula). Una pieza es nueva si lleva menos de `new_window_minutes` y no salió del inventario;
  si no, usada (lo desconocido también). Al quitar, `Inventory.removal_mode` decide: **SELL** (entra su
  valor) o **STORE** (va al inventario con su estado; si `capacity_provider` dice que no cabe, se
  vende). Inventario global y sin límite; el gancho `capacity_provider` es para la futura habitación
  almacén. `Economy.sell_stock(tipo, estado, cantidad)` vende existencias.
- **Pagos**: el huésped paga el 50% (`deposit_of`) al asignarle dormitorio y el resto al terminar la
  estancia; si no la completa, se devuelve el anticipo (y al reasignarle otra habitación paga uno
  nuevo). Quien se va enfadado antes de tener habitación no paga. El mantenimiento diario de cada
  habitación con tipo se cobra al cambiar de día (`Economy.update` cobra cada día pendiente).
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
         RoomType / RoomTypeCatalog / RoomValidator (RoomStatus, RoomCheck),
         MinHeap, Pathfinder, Agent / AgentRegistry / WanderBehavior,
         EntrancePoints, Guest / GuestRegistry / RoomOccupancy / GuestSpawner,
         EconomyRules / Ledger / BuildItem / PlacedPieces / Inventory / BuildOp / BuildQuote /
         Economy (dinero, costes, inventario y pagos),
         GameClock, GameState (raíz de la simulación)
view/    main.tscn/main.gd (escena principal), IsoProjection (única que conoce el rombo 64x32),
         TilesetFactory (arte provisional por código), LevelView (TileMapLayer), GridLines,
         IsoCamera, CellCursor, ShapePreview, RoomOverlay, EntranceLayer, AgentsLayer / AgentView,
         BuildController, WallStyle / WallViewMode / WallVisibility (alturas y modo corte de
         paredes)
ui/      BuildToolbar (herramientas, paleta de tipos, Entrada y Agente), WallModeBar, RoomInfoPanel,
         AgentInfoPanel, HotelStatusLabel, RoomTexts y GuestTexts (textos en español), ClockLabel
         (día, hora y velocidad), MoneyTexts (importes y textos de dinero), MoneyButton (saldo),
         FinancePanel, NoticeLabel (avisos), RemovalModeBar (Vender/Guardar), InventoryPanel
data/    room_types.json (tipos de habitación, requisitos, precios de estancia y mantenimiento),
         economy.json (reglas de economía)
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
  puertas, detección de habitaciones, asignación de tipos con clics reales sobre la barra, panel
  de información, herramienta Agente (crear, seleccionar, enviar, bloqueo, Supr), la ordenación
  de los agentes con las paredes (comprobada por el color real de los píxeles, en los dos ejes), el
  ciclo completo de un huésped (herramienta Entrada, tipos Recepción y Dormitorio, llegada,
  check-in, alojamiento, paneles, salida), el modo corte de paredes (tecla C, botones, y la
  visibilidad de un agente por píxeles en los cuatro modos), el dinero (saldo, vista previa con
  coste, fondos insuficientes, demoler), el inventario (V, I, guardar, reutilizar gratis, vender) y
  reloj. Admite hasta veintidós rutas de PNG tras `--` (en el orden en que las guarda cada
  comprobación; ver las llamadas `_save_args`). La escena real tiene economía activa, así que
  la comprobación del dinero fija un saldo de prueba y deja fondos de sobra al terminar para las
  demás.
  Las comprobaciones de ordenación con las paredes fijan el modo Arriba (con paredes bajas no
  tapan al agente).
- `tests/hotel_fixture.gd` (`HotelFixture.build(n_dormitorios, semilla, llegadas_automaticas, reglas_de_economia)`):
  hotel de prueba (vestíbulo, entrada, recepción y N dormitorios con puerta) para los tests de
  huéspedes. Las llegadas automáticas vienen desactivadas; cada test llama a `guests.arrive`.
- `tests/capture_view.gd`: captura una escena de demostración con varias habitaciones y agentes
  paseando.

```bash
"$GODOT" --path . --script res://tests/interaction_check.gd -- captura0.png captura1.png
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
  celda dibuja las aristas que posee (norte = X, oeste = Y) con un tile por combinación de estados.
  Una arista tiene 7 estados visuales (nada, o pared/puerta en cada altura de `WallStyle.Height`:
  FULL 48 px, LOW 14 px, FLAT 3 px), así que hay 7 x 7 - 1 = 48 tiles (`TilesetFactory.wall_coords`).
  Se necesita una sola capa y no una por eje porque solo así se ordena bien por Y con los agentes.
  Los tiles se dibujan por columnas con `fill_rect` (generar el TileSet tarda unos 2 ms; dibujarlos
  probando cada píxel contra un polígono sería unas cien veces más lento).
- **Modo corte de paredes** (solo vista; no está en `sim/` ni se guarda): `WallViewMode` (Arriba,
  Corte, Bajas, Ocultas; por defecto Corte), `WallVisibility.height_for` (lógica pura) y
  `LevelView.set_wall_mode`. En Corte, una pared se baja si la celda de **atrás** (norte para una
  arista X, oeste para una Y) tiene suelo, porque le tapa algo; si no, es una pared del fondo y se
  deja entera. Así, en un edificio sobre terreno sin suelo, las paredes norte y oeste quedan altas y
  las sur y este bajas; pero si hay suelo alrededor (un vestíbulo, un pasillo) todas las que dan a
  él bajan. Solo se mira la celda inmediatamente detrás. Al cambiar el suelo de una celda solo se
  redibujan las dos celdas cuyas paredes dependen de ella (`WallVisibility.dependent_wall_cells`);
  los tests comprueban que la actualización incremental coincide con un redibujado completo. Las
  vistas previas de construcción y las etiquetas usan siempre la altura completa.
- El tinte de habitaciones (`RoomOverlay`) se inserta entre el suelo y las paredes
  (`LevelView.add_ground_overlay`) para no teñir las paredes; su etiqueta flota por encima.
- Los comandos de forma (`fill_rect_floor`, `outline_rect_walls`, `build_room`, ...) solo añaden
  lo que falta, respetan las puertas existentes y devuelven cuántas celdas o aristas cambiaron.
  `demolish_room` sí quita puertas.
- Los botones de la barra comparten un `ButtonGroup` con `allow_unpress`. Al pasar de un botón a
  otro, Godot avisa primero de que el anterior se soltó cuando el nuevo ya está pulsado:
  `BuildToolbar` no deselecciona la herramienta en ese caso (`_another_button_is_pressed`), o la
  sincronización de botones desmarcaría el recién pulsado.
- **Agentes y paredes**: los `AgentView` cuelgan de `LevelView.get_entities_root()`, un nodo con
  `y_sort_enabled` que también contiene la capa de paredes. La posición del nodo es el punto de
  los pies. Los tiles de pared llevan `y_sort_origin = -8` (el punto medio de sus aristas está 8 px
  sobre el centro de la celda), que ordena bien al agente dentro de la celda y al otro lado de la
  pared. Con las paredes completas (modo Arriba) los agentes dentro de una habitación quedan
  tapados por sus paredes frontales; el modo Corte lo resuelve.
- Los paneles de información (`RoomInfoPanel`, `AgentInfoPanel`) ignoran el ratón para no tapar la
  construcción.
- En los tests, una función conectada a una señal de `GameState` no debe capturar el propio
  `state` (crea un ciclo de referencias y Godot avisa de fugas al cerrar): capturar solo lo
  necesario (por ejemplo `state.clock`).
- Un huésped alojado queda dentro de su dormitorio; en el modo Corte (por defecto) se ve, y en
  Arriba lo tapan las paredes frontales.
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
- Tipos de habitación: los botones Dormitorio / Baño de la barra (generados desde
  `data/room_types.json`) activan la herramienta Tipo; clic izquierdo dentro de una habitación le
  asigna el tipo, clic derecho se lo quita. Al pasar el cursor sobre una habitación se resalta y
  el panel (abajo a la izquierda) muestra sus requisitos con OK / NO.
- Agentes (herramienta de desarrollo, botón Agente): clic izquierdo sobre suelo libre crea un
  agente y lo selecciona; sobre un agente, lo selecciona. Clic derecho envía al seleccionado a esa
  celda (se dibuja su ruta), `Supr` lo elimina. Los agentes libres pasean solos.
- Hotel: para que lleguen huéspedes hacen falta una **entrada** (botón Entrada: clic izquierdo
  marca una celda con suelo, derecho la quita), una habitación de tipo **Recepción** operativa y
  dormitorios (tipo **Dormitorio**). Arriba a la derecha, debajo del reloj, un resumen indica qué
  falta o cuántos huéspedes, cuántos esperan y cuántos dormitorios hay libres. Con la herramienta
  Agente se puede seleccionar a un huésped y ver su estado; el panel de un dormitorio indica quién
  lo ocupa. Los huéspedes llevan sombrero (y maleta al llegar o irse).
- Paredes: el selector de abajo en el centro (Arriba / Corte / Bajas / Ocultas) o la tecla `C`, que
  rota entre los cuatro modos. Corte es el modo por defecto.
- Dinero: el saldo (arriba a la derecha, bajo el reloj; rojo en negativo) abre las finanzas, igual
  que `F`. Al arrastrar una forma, la vista previa muestra su coste o lo que devuelve (en rojo si no
  hay fondos, y entonces no se construye nada y sale un aviso). Abajo, sobre el selector de paredes,
  "Al quitar": **Vender** (entra el dinero) o **Guardar** (la pieza va al inventario); tecla `V` los
  alterna. `I` abre el inventario: piezas nuevas y usadas con su valor y un botón para venderlas.
  La habitación almacén (capacidad del inventario) está pendiente.
- Reloj: `Espacio` pausa, `1` / `2` / `3` velocidades.
