class_name TestCase
extends RefCounted
## Base mínima para las pruebas: cada método `test_*` de una suite se ejecuta desde
## run_tests.gd. Las aserciones solo acumulan fallos; no abortan el test.

var checks: int = 0
var failures: int = 0
var current_test: String = ""


func assert_true(condition: bool, message: String = "") -> void:
	checks += 1
	if not condition:
		_fail("se esperaba true. %s" % message)


func assert_false(condition: bool, message: String = "") -> void:
	checks += 1
	if condition:
		_fail("se esperaba false. %s" % message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	checks += 1
	if actual != expected:
		_fail("esperado %s, obtenido %s. %s" % [str(expected), str(actual), message])


func assert_near(actual: float, expected: float, message: String = "", tolerance: float = 0.0001) -> void:
	checks += 1
	if absf(actual - expected) > tolerance:
		_fail("esperado %s, obtenido %s. %s" % [str(expected), str(actual), message])


func _fail(detail: String) -> void:
	failures += 1
	printerr("  FALLO [%s] %s" % [current_test, detail])
