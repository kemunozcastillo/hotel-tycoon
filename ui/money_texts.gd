class_name MoneyTexts
extends RefCounted
## Textos en español del dinero: importes, categorías, presupuestos de construcción y el informe de
## finanzas. Funciones puras, compartidas por las etiquetas y paneles.

const CURRENCY: String = "€"
## Cuántos días se muestran en el resumen del informe.
const REPORT_DAYS: int = 7
## Cuántos movimientos recientes se muestran en el informe.
const REPORT_TRANSACTIONS: int = 8

const OK_COLOR: String = "#7bd88f"
const FAIL_COLOR: String = "#ff8a6b"


## "1.234 €", "-85 €": con punto como separador de miles.
static func format(amount: int) -> String:
	var digits: String = str(absi(amount))
	var grouped: String = ""
	var count: int = 0
	for i in range(digits.length() - 1, -1, -1):
		grouped = digits[i] + grouped
		count += 1
		if count % 3 == 0 and i > 0:
			grouped = "." + grouped
	return "%s%s %s" % ["-" if amount < 0 else "", grouped, CURRENCY]


## Importe con signo explícito: "+40 €", "-20 €" y "0 €".
static func signed(amount: int) -> String:
	if amount > 0:
		return "+" + format(amount)
	return format(amount)


static func category_label(category: Ledger.Category) -> String:
	match category:
		Ledger.Category.BUILD:
			return "Construcción"
		Ledger.Category.SALE:
			return "Venta de piezas"
		Ledger.Category.STAY_DEPOSIT:
			return "Anticipos de estancias"
		Ledger.Category.STAY_FINAL:
			return "Liquidación de estancias"
		Ledger.Category.DEPOSIT_REFUND:
			return "Anticipos devueltos"
		_:
			return "Mantenimiento"


## "Día 3 14:05" a partir de los minutos totales del reloj.
static func clock_text(total_minutes: float) -> String:
	var day: int = floori(total_minutes / 1440.0) + 1
	var hour: int = floori(total_minutes / 60.0) % 24
	var minute: int = floori(total_minutes) % 60
	return "Día %d %02d:%02d" % [day, hour, minute]


## Lo que cuesta o devuelve una orden de construcción, para la vista previa. Vacío si no cambia
## nada o si todo es gratis.
static func quote_text(quote: BuildQuote) -> String:
	if quote.is_empty():
		return ""
	var parts: Array[String] = []
	if quote.cost > 0:
		parts.append("-" + format(quote.cost))
	if quote.from_stock > 0:
		parts.append("%d del inventario" % quote.from_stock)
	if quote.income > 0:
		parts.append("+" + format(quote.income))
	if quote.stored > 0:
		parts.append("%d al inventario" % quote.stored)
	if not quote.affordable:
		parts.append("¡sin fondos! hacen falta %s" % format(quote.required_balance))
	return " · ".join(parts)


## "nuevos" / "usadas"...: el estado de una pieza concordando con su género (suelo es masculino;
## pared y puerta, femenino).
static func condition_label(kind: BuildItem.Kind, condition: BuildItem.Condition) -> String:
	var feminine: bool = kind != BuildItem.Kind.FLOOR
	if condition == BuildItem.Condition.NEW:
		return "nuevas" if feminine else "nuevos"
	return "usadas" if feminine else "usados"


## Una fila del inventario: "Suelos nuevos ×12 · vale 120 €".
static func stock_row_text(kind: BuildItem.Kind, condition: BuildItem.Condition, count: int, value: int) -> String:
	return "%s %s ×%d · vale %s" % [BuildItem.label_plural(kind), condition_label(kind, condition), count, format(value)]


## Aviso cuando una orden se rechaza por falta de dinero.
static func insufficient_text(required_balance: int, balance: int) -> String:
	return "Dinero insuficiente: hacen falta %s y hay %s" % [format(required_balance), format(balance)]


## Las categorías de un día con algún movimiento, una por línea, en BBCode.
static func day_lines(ledger: Ledger, day: int) -> String:
	var lines: String = ""
	for category in range(Ledger.CATEGORY_COUNT):
		var total: int = ledger.get_day_total(day, category as Ledger.Category)
		if total != 0:
			lines += "  %s  %s\n" % [category_label(category as Ledger.Category), _colored(total)]
	if lines.is_empty():
		lines = "  Sin movimientos\n"
	return lines


## Informe de finanzas en BBCode: saldo, hoy, últimos días y movimientos recientes.
static func finance_report(ledger: Ledger, today: int, total_minutes: float) -> String:
	var text: String = "[b]Finanzas[/b]   Saldo: %s\n\n" % _colored(ledger.balance, false)
	text += "[b]Hoy[/b] (día %d)\n" % today
	text += day_lines(ledger, today)
	text += "  Entradas %s · Salidas %s · Neto %s\n\n" % [
		signed(ledger.get_day_income(today)), "-" + format(ledger.get_day_expenses(today)), _colored(ledger.get_day_net(today))]

	text += "[b]Últimos días[/b]\n"
	for day in range(maxi(today - REPORT_DAYS + 1, 1), today + 1):
		text += "  Día %d:  %s  /  %s  =  %s\n" % [
			day, signed(ledger.get_day_income(day)), "-" + format(ledger.get_day_expenses(day)), _colored(ledger.get_day_net(day))]

	text += "\n[b]Movimientos recientes[/b]\n"
	var recent: Array[Dictionary] = ledger.get_recent(REPORT_TRANSACTIONS)
	if recent.is_empty():
		text += "  Ninguno\n"
	for transaction: Dictionary in recent:
		text += "  %s  %s  %s\n" % [clock_text(transaction["minute"]), _colored(transaction["amount"]), transaction["note"]]
	return text


## Importe con signo y color (verde si entra, rojo si sale). Con `with_sign` false no pone "+".
static func _colored(amount: int, with_sign: bool = true) -> String:
	var shown: String = signed(amount) if with_sign else format(amount)
	if amount > 0:
		return "[color=%s]%s[/color]" % [OK_COLOR, shown]
	if amount < 0:
		return "[color=%s]%s[/color]" % [FAIL_COLOR, shown]
	return shown
