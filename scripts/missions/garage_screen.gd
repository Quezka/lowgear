class_name GarageScreen
extends CanvasLayer
## In-game garage: switch or buy vehicles, buy and fit upgrades. Opening it also repairs and refuels.

signal swap(id: String)

var _list: VBoxContainer
var _ups: VBoxContainer
var _head: Label
var _status: Label
var _first: Button


func _ready() -> void:
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.17, 0.16, 0.26, 0.6)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.theme = GameState.ui_theme()
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	v.add_child(top)
	top.add_child(Icons.rect("garage_home", 40, GameState.DARK))
	_head = Label.new()
	_head.label_settings = GameState.label_settings(34, true)
	_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_head)
	_first = Button.new()
	_first.text = "Drive"
	_first.icon = Icons.tex("play_arrow", 64)
	_first.theme_type_variation = "PrimaryButton"
	_first.pressed.connect(close)
	top.add_child(_first)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	v.add_child(cols)
	var h := clampf(get_viewport().get_visible_rect().size.y - 230.0, 260.0, 520.0)
	_list = _column(cols, "Vehicles", h, 520)
	_ups = _column(cols, "Upgrades", h, 420)
	_status = Label.new()
	_status.label_settings = GameState.label_settings(22, true, GameState.MUTED)
	v.add_child(_status)


func _column(parent: Control, title: String, h: float, w: float) -> VBoxContainer:
	var c := VBoxContainer.new()
	parent.add_child(c)
	var l := Label.new()
	l.text = title
	l.label_settings = GameState.label_settings(24, true, GameState.MUTED)
	c.add_child(l)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(w, h)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	c.add_child(sc)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(inner)
	return inner


func open() -> void:
	visible = true
	GameState.ui_open = true
	_status.text = "Repaired and refuelled. Pick a vehicle or buy upgrades."
	refresh()
	_first.grab_focus()


func close() -> void:
	visible = false
	GameState.ui_open = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("pause") or event.is_action_pressed("interact")):
		close()
		get_viewport().set_input_as_handled()


func refresh() -> void:
	_head.text = "Garage      $%d      Level %d" % [GameState.money(), GameState.level()]
	for c in _list.get_children():
		c.queue_free()
	for c in _ups.get_children():
		c.queue_free()
	for id in CarSpecs.ORDER:
		var spec := CarSpecs.get_spec(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_list.add_child(row)
		var l := Label.new()
		l.text = "%s  ·  %s" % [spec["name"], spec.get("class", "")]
		l.tooltip_text = "Inspired by the %s" % spec.get("inspired", "")
		l.label_settings = GameState.label_settings(22, true)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var b := Button.new()
		b.custom_minimum_size = Vector2(170, 0)
		b.add_theme_font_size_override("font_size", 22)
		if id == GameState.car_id:
			b.text = "Driving"
			b.disabled = true
		elif GameState.owns(id):
			b.text = "Take it"
			b.icon = Icons.tex("play_arrow", 48)
			b.pressed.connect(func() -> void: _take(id))
		elif GameState.level() < int(spec.get("level", 1)):
			b.text = "Level %d" % int(spec["level"])
			b.icon = Icons.tex("lock", 48)
			b.disabled = true
		else:
			b.text = "$%d" % int(spec.get("price", 0))
			b.icon = Icons.tex("shopping_cart", 48)
			b.pressed.connect(func() -> void:
				var err := GameState.buy_vehicle(id)
				_status.text = err if err != "" else "Bought the %s!" % spec["name"]
				refresh())
		row.add_child(b)
	_upgrades()


func _take(id: String) -> void:
	swap.emit(id)
	_status.text = "Now driving the %s" % CarSpecs.get_spec(id)["name"]
	refresh()


func _upgrades() -> void:
	var id := GameState.car_id
	var spec := CarSpecs.get_spec(id)
	var g := GameState.garage_for(id)
	var heavy := float(spec["mass"]) > 3000.0
	for t in CarSpecs.TYRES:
		var owned := (g["owned_tyres"] as Array).has(t)
		var price := int(GameState.TYRE_PRICE[t]) * (2 if heavy else 1)
		var label := "Fitted" if g["tyres"] == t else ("Fit" if owned else "$%d" % price)
		_up_row("tire_repair", "%s tyres" % CarSpecs.TYRE_NAMES[t], label, g["tyres"] == t, func() -> void:
			if not owned:
				if not GameState.spend(price):
					_status.text = "Not enough money"
					return
				var ot: Array = g["owned_tyres"].duplicate()
				ot.append(t)
				GameState.set_garage(id, "owned_tyres", ot)
			GameState.set_garage(id, "tyres", t)
			_take(id))
	if spec.has("snorkel_parts"):
		var label := ("Remove" if g["snorkel"] else "Fit") if g["has_snorkel"] else "$%d" % GameState.SNORKEL_PRICE
		_up_row("water_drop", "Snorkel", label, false, func() -> void:
			if not g["has_snorkel"]:
				if not GameState.spend(GameState.SNORKEL_PRICE):
					_status.text = "Not enough money"
					return
				GameState.set_garage(id, "has_snorkel", true)
			GameState.set_garage(id, "snorkel", not g["snorkel"] or not g["has_snorkel"])
			_take(id))
	for up in [["engine", "Engine tune (+18% torque)", GameState.ENGINE_PRICE, "speed"],
			["tank", "Big fuel tank (+50%)", GameState.TANK_PRICE, "local_gas_station"]]:
		var have: bool = g[up[0]]
		_up_row(up[3], up[1], "Installed" if have else "$%d" % int(up[2]), have, func() -> void:
			if GameState.spend(int(up[2])):
				GameState.set_garage(id, up[0], true)
				_take(id)
			else:
				_status.text = "Not enough money")


func _up_row(icon: String, text: String, button: String, disabled: bool, cb: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_ups.add_child(row)
	row.add_child(Icons.rect(icon, 26, GameState.DARK))
	var l := Label.new()
	l.text = text
	l.label_settings = GameState.label_settings(21, true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var b := Button.new()
	b.text = button
	b.disabled = disabled
	b.custom_minimum_size = Vector2(120, 0)
	b.add_theme_font_size_override("font_size", 21)
	b.pressed.connect(cb)
	row.add_child(b)
