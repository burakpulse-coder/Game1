extends Node

func _ready() -> void:
	SceneRouter.pending_level_id = 26
	var battle = load("res://scenes/Oyun.tscn").instantiate()
	add_child(battle)
	await get_tree().process_frame
	await get_tree().process_frame
	var wheel: LetterWheel = battle.wheel
	var local: Vector2 = wheel._positions[0]
	var canvas: Vector2 = wheel.get_global_transform_with_canvas() * local
	print("viewport size      = ", get_viewport().get_visible_rect().size)
	print("window size        = ", DisplayServer.window_get_size())
	print("stone0 local       = ", local)
	print("stone0 canvas      = ", canvas)
	print("final_transform    = ", get_viewport().get_final_transform())
	print("screen_transform   = ", get_viewport().get_screen_transform())
	var adaylar := {
		"canvas": canvas,
		"final*canvas": get_viewport().get_final_transform() * canvas,
		"screen*canvas": get_viewport().get_screen_transform() * canvas,
		"final_inv*canvas": get_viewport().get_final_transform().affine_inverse() * canvas,
	}
	for ad in adaylar:
		wheel._selection.clear()
		var ev := InputEventScreenTouch.new()
		ev.index = 0
		ev.pressed = true
		ev.position = adaylar[ad]
		Input.parse_input_event(ev)
		await get_tree().process_frame
		# Ölçüm basma anında yapılır: bırakma olayı kelimeyi gönderip seçimi siler.
		var secildi := wheel._selection.size()
		var ev2 := InputEventScreenTouch.new()
		ev2.index = 0
		ev2.pressed = false
		ev2.position = adaylar[ad]
		Input.parse_input_event(ev2)
		await get_tree().process_frame
		print("  %-18s -> %s  secim=%d" % [ad, adaylar[ad], secildi])
	get_tree().quit()
