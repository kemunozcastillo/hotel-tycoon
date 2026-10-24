class_name Economy
extends RefCounted
## El dinero que mueve el hotel mientras funciona: lo que pagan los huéspedes, el mantenimiento
## diario de las habitaciones y la venta de piezas del inventario. (Lo que cuesta construir lo
## gestiona BuildCommands.)
##
## Pago de una estancia:
##   - Al hacer el check-in (cuando se le asigna dormitorio) se cobra el anticipo: la mitad del
##     precio, redondeada hacia abajo. El precio queda fijado en ese momento.
##   - Al terminar la estancia contento se cobra el resto.
##   - Si no la completa (pierde su habitación, no puede llegar a ella, o desaparece su agente) se
##     le devuelve el anticipo. Si luego recibe otro dormitorio, paga un anticipo nuevo.
##   - Un huésped que se marcha enfadado antes de tener habitación no ha pagado nada.
##
## Mantenimiento: al empezar cada día de juego se cobra la suma de `daily_upkeep` de cada habitación
## con tipo (también las no operativas, que no dejan de costar). Si el reloj salta varios días, se
## cobra cada uno y se archiva en su día.
##
## Con `EconomyRules.charges_enabled = false` nada de esto mueve dinero.

var _rules: EconomyRules
var _ledger: Ledger
var _inventory: Inventory
var _rooms: RoomRegistry
var _catalog: RoomTypeCatalog
var _grid: GridMap2D
var _clock: GameClock
var _last_day: int = 1


func _init(rules: EconomyRules, ledger: Ledger, inventory: Inventory, rooms: RoomRegistry,
		catalog: RoomTypeCatalog, grid: GridMap2D, guests: GuestRegistry, clock: GameClock) -> void:
	_rules = rules
	_ledger = ledger
	_inventory = inventory
	_rooms = rooms
	_catalog = catalog
	_grid = grid
	_clock = clock
	_last_day = clock.get_day()
	guests.guest_checked_in.connect(_on_guest_checked_in)
	guests.guest_stay_completed.connect(_on_stay_completed)
	guests.guest_room_lost.connect(_on_room_lost)
	guests.guest_left.connect(_on_guest_left)


## Precio de una estancia en esa habitación: el del tipo más un extra por cada celda por encima del
## mínimo. 0 si la habitación no tiene tipo o no se alquila.
func stay_price_of(room: Room) -> int:
	var type: RoomType = _catalog.get_type(room.type_id)
	if type == null:
		return 0
	var extra_cells: int = maxi(room.get_area() - type.min_area, 0)
	return type.stay_price + extra_cells * type.stay_price_per_extra_cell


## Lo que cuesta ahora mismo un día de mantenimiento de todas las habitaciones.
func daily_upkeep() -> int:
	var total: int = 0
	for level: int in _grid.get_levels():
		for room: Room in _rooms.get_rooms(level):
			var type: RoomType = _catalog.get_type(room.type_id)
			if type != null:
				total += type.daily_upkeep
	return total


## Cobra el mantenimiento de los días que hayan empezado desde la última vez.
func update() -> void:
	var day: int = _clock.get_day()
	while _last_day < day:
		_last_day += 1
		if _rules.charges_enabled:
			var upkeep: int = daily_upkeep()
			_ledger.record(Ledger.Category.UPKEEP, -upkeep, "Mantenimiento diario", _last_day)


## Vende piezas del inventario al valor de su estado. Devuelve el dinero recibido (0 y sin cambios
## si no hay tantas piezas).
func sell_stock(kind: BuildItem.Kind, condition: BuildItem.Condition, amount: int) -> int:
	if not _inventory.remove_stock(kind, condition, amount):
		return 0
	var income: int = _rules.sale_value(kind, condition) * amount
	_ledger.record(Ledger.Category.SALE, income, "Venta del inventario: %s" % BuildItem.describe_count(kind, amount))
	return income


# --- Pagos de las estancias -----------------------------------------------------------------

func _on_guest_checked_in(guest: Guest) -> void:
	if not _rules.charges_enabled:
		return
	var room: Room = _rooms.get_room(guest.room_id)
	if room == null:
		return
	guest.stay_price = stay_price_of(room)
	guest.deposit_paid = _rules.deposit_of(guest.stay_price)
	_ledger.record(Ledger.Category.STAY_DEPOSIT, guest.deposit_paid, "Anticipo del huésped %d" % guest.id)


func _on_stay_completed(guest: Guest) -> void:
	if not _rules.charges_enabled or (guest.deposit_paid <= 0 and guest.stay_price <= 0):
		return
	_ledger.record(Ledger.Category.STAY_FINAL, guest.stay_price - guest.deposit_paid, "Liquidación del huésped %d" % guest.id)


func _on_room_lost(guest: Guest) -> void:
	_refund_deposit(guest)


func _on_guest_left(guest: Guest) -> void:
	_refund_deposit(guest)


## Devuelve el anticipo si la estancia no llegó a completarse. No hace nada si ya se devolvió.
func _refund_deposit(guest: Guest) -> void:
	if guest.deposit_paid <= 0 or guest.stay_completed:
		return
	_ledger.record(Ledger.Category.DEPOSIT_REFUND, -guest.deposit_paid, "Devolución del anticipo del huésped %d" % guest.id)
	guest.deposit_paid = 0
	guest.stay_price = 0


# --- Guardado -----------------------------------------------------------------------------------

func serialize() -> Dictionary:
	return {"last_day": _last_day}


func restore(data: Dictionary, reader: SaveReader) -> void:
	_last_day = reader.read_int(data, "last_day", "economía", 1)
