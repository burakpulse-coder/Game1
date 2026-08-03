extends Node

## Google Play Billing sarmalayıcısı.
##
## Eklenti yoksa mağaza ekranı ürünleri listeler ama satın alma "kullanılamıyor"
## döner — oyun ilerlemesi hiçbir satın almaya bağlı değildir (pay-to-win yok).

signal purchase_completed(product_id: String)
signal purchase_failed(product_id: String, reason: String)
signal products_updated

const SINGLETON_NAME := "GodotGooglePlayBilling"

var _plugin: Object = null
var _connected := false
var _prices := {}   ## ürün kimliği -> mağazadan gelen yerelleştirilmiş fiyat


func _ready() -> void:
	if Engine.has_singleton(SINGLETON_NAME):
		_plugin = Engine.get_singleton(SINGLETON_NAME)
		_connect_plugin_signals()
		_plugin.startConnection()
	else:
		print("[IapManager] Billing eklentisi yok — satın almalar devre dışı.")


func _connect_plugin_signals() -> void:
	for pair in [
		["connected", _on_connected],
		["disconnected", _on_disconnected],
		["sku_details_query_completed", _on_sku_details],
		["purchases_updated", _on_purchases_updated],
		["purchase_error", _on_purchase_error],
	]:
		if _plugin.has_signal(pair[0]):
			_plugin.connect(pair[0], pair[1])


func is_available() -> bool:
	return _plugin != null and _connected


func price_of(product_id: String) -> String:
	if _prices.has(product_id):
		return _prices[product_id]
	return str(GameConfig.IAP_PRODUCTS.get(product_id, {}).get("fiyat", "—"))


## Başlangıç paketi yalnızca bir kez satın alınabilir.
func is_purchasable(product_id: String) -> bool:
	var data: Dictionary = GameConfig.IAP_PRODUCTS.get(product_id, {})
	if data.is_empty():
		return false
	if data.get("tur", "") == "kalici" and SaveManager.has_purchase(product_id):
		return false
	return true


func purchase(product_id: String) -> void:
	if not is_purchasable(product_id):
		purchase_failed.emit(product_id, "Bu ürün zaten sahiplenilmiş")
		return
	if not is_available():
		purchase_failed.emit(product_id, "Mağazaya bağlanılamadı")
		return
	_plugin.purchase(product_id)


func restore_purchases() -> void:
	if not is_available():
		return
	_plugin.queryPurchases("inapp")


func _on_connected() -> void:
	_connected = true
	var ids := PackedStringArray(GameConfig.IAP_PRODUCTS.keys())
	if _plugin.has_method("querySkuDetails"):
		_plugin.querySkuDetails(ids, "inapp")
	restore_purchases()


func _on_disconnected() -> void:
	_connected = false


func _on_sku_details(details) -> void:
	for entry in details:
		if typeof(entry) == TYPE_DICTIONARY and entry.has("sku"):
			_prices[entry["sku"]] = str(entry.get("price", ""))
	products_updated.emit()


func _on_purchases_updated(purchases) -> void:
	for purchase_data in purchases:
		if typeof(purchase_data) != TYPE_DICTIONARY:
			continue
		var sku := str(purchase_data.get("sku", ""))
		if sku == "":
			continue
		_grant(sku)
		# Tüketilebilir ürünler tekrar satın alınabilsin diye tüketilir.
		var product: Dictionary = GameConfig.IAP_PRODUCTS.get(sku, {})
		if product.get("tur", "") == "tuketilir" and _plugin.has_method("consumePurchase"):
			_plugin.consumePurchase(purchase_data.get("purchase_token", ""))
		elif _plugin.has_method("acknowledgePurchase"):
			_plugin.acknowledgePurchase(purchase_data.get("purchase_token", ""))


func _on_purchase_error(code, message) -> void:
	purchase_failed.emit("", "Satın alma hatası (%s): %s" % [code, message])


## Ürünün oyun içi karşılığını verir.
func _grant(product_id: String) -> void:
	var product: Dictionary = GameConfig.IAP_PRODUCTS.get(product_id, {})
	if product.is_empty():
		return
	if product.has("elmas") and int(product["elmas"]) > 0:
		EconomyManager.add_gems(int(product["elmas"]))
	if product.has("altin"):
		EconomyManager.add_gold(int(product["altin"]))
	if product.get("tur", "") == "kalici":
		SaveManager.add_purchase(product_id)
	purchase_completed.emit(product_id)
