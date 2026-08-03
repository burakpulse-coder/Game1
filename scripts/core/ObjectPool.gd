class_name ObjectPool
extends RefCounted

## Genel amaçlı nesne havuzu.
##
## Düşman ve mermi gibi sık doğup ölen düğümler her seferinde yaratılmaz;
## havuzdan alınıp geri bırakılır. Düşük donanımlı Android cihazlarda çöp
## toplayıcı duraklamalarını ve kare düşmelerini engeller.
##
## Havuzdaki düğümlerin `pool_reset()` metodu varsa geri bırakılırken çağrılır.

var _factory: Callable
var _parent: Node
var _free: Array[Node] = []
var _active: Array[Node] = []
var _max_size: int


func _init(parent: Node, factory: Callable, prewarm: int = 0, max_size: int = 256) -> void:
	_parent = parent
	_factory = factory
	_max_size = max_size
	for i in prewarm:
		var node: Node = _factory.call()
		_deactivate(node)
		_parent.add_child(node)
		_free.append(node)


func acquire() -> Node:
	var node: Node
	if _free.is_empty():
		node = _factory.call()
		_parent.add_child(node)
	else:
		node = _free.pop_back()
	_activate(node)
	_active.append(node)
	return node


func release(node: Node) -> void:
	var index := _active.find(node)
	if index < 0:
		return  # zaten geri bırakılmış
	_active.remove_at(index)
	if node.has_method("pool_reset"):
		node.call("pool_reset")
	_deactivate(node)
	if _free.size() < _max_size:
		_free.append(node)
	else:
		node.queue_free()


func release_all() -> void:
	for node in _active.duplicate():
		release(node)


## Etkin nesneler üzerinde güvenli gezinme için kopya döndürür.
func active() -> Array[Node]:
	return _active


func active_count() -> int:
	return _active.size()


func _activate(node: Node) -> void:
	node.set_process(true)
	node.set_physics_process(true)
	if node is CanvasItem:
		(node as CanvasItem).visible = true


func _deactivate(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	if node is CanvasItem:
		(node as CanvasItem).visible = false
