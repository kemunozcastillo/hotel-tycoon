class_name GuestTexts
extends RefCounted
## Textos en español de los huéspedes y del estado del hotel. Funciones puras, para el panel del
## agente y la etiqueta de estado.


## Qué está haciendo el huésped, con los tiempos que importan al jugador.
static func state_text(guest: Guest) -> String:
	match guest.state:
		Guest.State.ARRIVING:
			return "Llega a la recepción"
		Guest.State.QUEUED:
			return "Espera su turno de check-in (lleva %d min)" % roundi(guest.waited_minutes)
		Guest.State.CHECKING_IN:
			return "Hace el check-in (quedan %d min)" % ceili(maxf(guest.timer_minutes, 0.0))
		Guest.State.WAITING_ROOM:
			return "Sin dormitorio libre: espera (paciencia %d de %d min)" % [
				roundi(guest.waited_minutes), roundi(GuestRegistry.PATIENCE_MINUTES)]
		Guest.State.GOING_TO_ROOM:
			return "Va a su dormitorio (habitación %d)" % guest.room_id
		Guest.State.STAYING:
			return "Alojado en la habitación %d (quedan %s)" % [guest.room_id, _duration_text(guest.timer_minutes)]
		Guest.State.LEAVING:
			return "Se marcha enfadado" if guest.left_unhappy else "Se marcha"
	return ""


## Texto del panel de un agente que es un huésped.
static func describe(guest: Guest) -> String:
	return "Huésped %d\n%s" % [guest.id, state_text(guest)]


## "2 h 30 min" / "45 min".
static func _duration_text(minutes: float) -> String:
	var total: int = ceili(maxf(minutes, 0.0))
	if total >= 60:
		return "%d h %02d min" % [floori(total / 60.0), total % 60]
	return "%d min" % total


## Resumen del hotel para la etiqueta de estado. Si falta algo imprescindible para que lleguen
## huéspedes, lo avisa en lugar de mostrar contadores.
static func hotel_summary(guest_count: int, waiting: int, free_bedrooms: int, total_bedrooms: int,
		has_entrance: bool, has_reception: bool) -> String:
	if not has_entrance:
		return "Falta una entrada: marca una celda con la herramienta Entrada"
	if not has_reception:
		return "Falta una recepción operativa (tipo Recepción, con puerta)"
	return "Huéspedes %d  ·  En espera %d  ·  Dormitorios libres %d/%d" % [
		guest_count, waiting, free_bedrooms, total_bedrooms]
