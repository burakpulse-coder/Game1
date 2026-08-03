extends PanelContainer

## Altın/elmas göstergesi. EconomyManager sinyaline kendisi abone olur,
## böylece her ekranın ayrıca güncelleme kodu yazması gerekmez.

var _amount: Label


func _ready() -> void:
	_amount = find_child("Tutar", true, false) as Label
	EconomyManager.currency_changed.connect(_on_changed)
	_refresh()


func _on_changed(_gold: int, _gems: int) -> void:
	_refresh()


func _refresh() -> void:
	if _amount == null:
		return
	var kind := str(get_meta("kind", "altin"))
	_amount.text = str(EconomyManager.gems() if kind == "elmas" else EconomyManager.gold())
