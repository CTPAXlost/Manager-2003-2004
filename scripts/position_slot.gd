class_name PositionSlot
extends PanelContainer

signal player_dropped(player_id: int, slot_id: String)
signal slot_pressed(slot_id: String)
signal slot_moved(slot_id: String, normalized_position: Vector2)
signal player_context_requested(player_id: int, slot_id: String, screen_position: Vector2)

var slot_id = ""
var role_name = ""
var accepted: Array = []
var player_id = -1
var player_data: Dictionary = {}
var effective_rating = 0
var fit_text = ""
var title_label: Label
var name_label: Label
var info_label: Label
var fit_label: Label
var body: HBoxContainer
var portrait: PlayerPortrait
var text_box: VBoxContainer
var normal_style: StyleBoxFlat
var hover_style: StyleBoxFlat
var warning_style: StyleBoxFlat
var edit_style: StyleBoxFlat
var click_armed = false
var drag_started = false
var press_position = Vector2.ZERO
var editor_mode = false
var moving_slot = false
var is_selected = false
var action_button: Button

func setup(data: Dictionary) -> void:
    slot_id = str(data.get("id", "slot"))
    role_name = str(data.get("label", slot_id))
    accepted = data.get("accepted", [])
    custom_minimum_size = Vector2(168, 124)
    mouse_filter = Control.MOUSE_FILTER_STOP
    mouse_force_pass_scroll_events = false
    mouse_default_cursor_shape = Control.CURSOR_DRAG
    focus_mode = Control.FOCUS_NONE

    normal_style = _make_style(Color(0.025, 0.065, 0.09, 0.97), Color("b98a35"), 1)
    hover_style = _make_style(Color(0.055, 0.19, 0.20, 0.98), Color("40e0ff"), 2)
    warning_style = _make_style(Color(0.19, 0.105, 0.08, 0.98), Color("ffc857"), 2)
    edit_style = _make_style(Color(0.16, 0.12, 0.035, 0.98), Color("ffc857"), 2)
    add_theme_stylebox_override("panel", normal_style)

    body = HBoxContainer.new()
    body.add_theme_constant_override("separation", 5)
    body.alignment = BoxContainer.ALIGNMENT_CENTER
    body.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(body)

    portrait = PlayerPortrait.new()
    portrait.setup({})
    body.add_child(portrait)

    text_box = VBoxContainer.new()
    text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    text_box.add_theme_constant_override("separation", 0)
    text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    body.add_child(text_box)

    title_label = Label.new()
    title_label.text = role_name
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_label.add_theme_font_size_override("font_size", 11)
    title_label.add_theme_color_override("font_color", Color("e2bd61"))
    title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    text_box.add_child(title_label)

    name_label = Label.new()
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    name_label.add_theme_font_size_override("font_size", 12)
    name_label.add_theme_color_override("font_color", Color("e8f3f8"))
    name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    text_box.add_child(name_label)

    info_label = Label.new()
    info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    info_label.add_theme_font_size_override("font_size", 11)
    info_label.add_theme_color_override("font_color", Color("c5d5dc"))
    info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    text_box.add_child(info_label)

    fit_label = Label.new()
    fit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    fit_label.add_theme_font_size_override("font_size", 9)
    fit_label.add_theme_color_override("font_color", Color("d7aa48"))
    fit_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    text_box.add_child(fit_label)

    action_button = Button.new()
    action_button.text = "↔"
    action_button.tooltip_text = "Выбрать этого игрока или эту позицию для замены"
    action_button.custom_minimum_size = Vector2(26, 28)
    action_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    action_button.focus_mode = Control.FOCUS_NONE
    action_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    action_button.add_theme_font_size_override("font_size", 14)
    action_button.pressed.connect(func(): slot_pressed.emit(slot_id))
    body.add_child(action_button)

    set_player({})



func set_empty_message(name_text: String, info_text: String, status_text = "") -> void:
    player_data = {}
    player_id = -1
    effective_rating = -1
    if portrait != null:
        portrait.setup({})
    fit_text = str(status_text)
    name_label.text = name_text
    info_label.text = info_text
    fit_label.text = str(status_text)
    mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    tooltip_text = "%s\n%s" % [info_text, status_text]
    _restore_style()

func set_selected(value: bool) -> void:
    is_selected = value
    _restore_style()

func set_role(new_role: String) -> void:
    role_name = new_role
    accepted = [new_role]
    if title_label != null:
        title_label.text = new_role

func set_editor_mode(value: bool) -> void:
    editor_mode = value
    moving_slot = false
    click_armed = false
    drag_started = false
    mouse_default_cursor_shape = Control.CURSOR_MOVE if editor_mode else (Control.CURSOR_DRAG if player_id >= 0 else Control.CURSOR_POINTING_HAND)
    if action_button != null:
        action_button.visible = not editor_mode
    _restore_style()
    if editor_mode:
        tooltip_text = "Режим свободной схемы: зажмите карточку и переместите её в любую точку поля"

func _make_style(background: Color, border: Color, width: int) -> StyleBoxFlat:
    var style = StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = border
    style.set_border_width_all(width)
    style.set_corner_radius_all(9)
    style.content_margin_left = 7
    style.content_margin_right = 7
    style.content_margin_top = 5
    style.content_margin_bottom = 5
    return style

func set_player(player: Dictionary, calculated_rating = -1, calculated_fit_text = "") -> void:
    player_data = player.duplicate(true)
    player_id = int(player_data.get("id", -1))
    if portrait != null:
        portrait.setup(player_data)
    effective_rating = int(calculated_rating)
    fit_text = str(calculated_fit_text)
    if player_id < 0:
        name_label.text = "ПУСТО"
        info_label.text = "бросьте игрока сюда"
        fit_label.text = ""
        mouse_default_cursor_shape = Control.CURSOR_MOVE if editor_mode else Control.CURSOR_POINTING_HAND
        tooltip_text = "Перетащите сюда футболиста"
        _restore_style()
        return

    var parts = str(player_data.get("name", "Игрок")).split(" ")
    var surname = parts[parts.size() - 1] if parts.size() > 0 else "Игрок"
    var base_rating = int(player_data.get("rating", 0))
    name_label.text = surname
    if effective_rating >= 0 and effective_rating != base_rating:
        info_label.text = "%s  %d → %d · %d%%" % [player_data.get("position", "?"), base_rating, effective_rating, int(player_data.get("condition", 100))]
    else:
        info_label.text = "%s  %d · %d%%" % [player_data.get("position", "?"), base_rating, int(player_data.get("condition", 100))]
    fit_label.text = fit_text
    mouse_default_cursor_shape = Control.CURSOR_MOVE if editor_mode else Control.CURSOR_DRAG
    var secondaries: Array = player_data.get("secondary", [])
    tooltip_text = "%s\nОсновная: %s\nДополнительные: %s\nЭффективный рейтинг здесь: %d\n%s" % [
        player_data.get("name", "Игрок"),
        player_data.get("position", "?"),
        ", ".join(secondaries) if not secondaries.is_empty() else "нет",
        effective_rating if effective_rating >= 0 else base_rating,
        "Перемещайте всю позицию по полю" if editor_mode else "Перетащите игрока на другую позицию",
    ]
    _restore_style()

func _gui_input(event: InputEvent) -> void:
    if editor_mode:
        _editor_gui_input(event)
        return
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
        if event.pressed and player_id >= 0:
            player_context_requested.emit(player_id, slot_id, get_global_mouse_position())
            accept_event()
        return
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            click_armed = true
            drag_started = false
            press_position = event.position
            add_theme_stylebox_override("panel", hover_style)
            accept_event()
        else:
            var should_click = click_armed and not drag_started
            click_armed = false
            if should_click:
                slot_pressed.emit(slot_id)
            _restore_style()
            accept_event()
    elif event is InputEventMouseMotion and click_armed and not drag_started:
        if event.position.distance_to(press_position) > 4.0 and player_id >= 0:
            drag_started = true
            click_armed = false
            force_drag(_drag_payload(), _make_drag_preview())
            accept_event()

func _editor_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            moving_slot = true
            add_theme_stylebox_override("panel", hover_style)
            accept_event()
        else:
            if moving_slot:
                moving_slot = false
                _emit_normalized_position()
                _restore_style()
                accept_event()
    elif event is InputEventMouseMotion and moving_slot:
        var parent_control = get_parent() as Control
        if parent_control == null:
            return
        position += event.relative
        position.x = clamp(position.x, 4.0, max(4.0, parent_control.size.x - size.x - 4.0))
        position.y = clamp(position.y, 4.0, max(4.0, parent_control.size.y - size.y - 4.0))
        accept_event()

func _emit_normalized_position() -> void:
    var parent_control = get_parent() as Control
    if parent_control == null or parent_control.size.x <= 0.0 or parent_control.size.y <= 0.0:
        return
    var center = position + size / 2.0
    slot_moved.emit(slot_id, Vector2(clamp(center.x / parent_control.size.x, 0.04, 0.96), clamp(center.y / parent_control.size.y, 0.04, 0.96)))

func _get_drag_data(_at_position: Vector2) -> Variant:
    if editor_mode or player_id < 0:
        return null
    drag_started = true
    click_armed = false
    set_drag_preview(_make_drag_preview())
    return _drag_payload()

func _drag_payload() -> Dictionary:
    return {
        "kind": "player",
        "player_id": player_id,
        "source": "pitch",
        "source_slot": slot_id,
    }

func _make_drag_preview() -> Control:
    var preview = Label.new()
    preview.text = "%s  [%s · %d]" % [
        player_data.get("name", "Игрок"),
        player_data.get("position", "?"),
        int(player_data.get("rating", 0)),
    ]
    preview.add_theme_font_size_override("font_size", 14)
    preview.add_theme_color_override("font_color", Color("d9fbff"))
    var box = StyleBoxFlat.new()
    box.bg_color = Color("183347")
    box.border_color = Color("40e0ff")
    box.set_border_width_all(1)
    box.set_corner_radius_all(8)
    box.content_margin_left = 12
    box.content_margin_right = 12
    box.content_margin_top = 8
    box.content_margin_bottom = 8
    preview.add_theme_stylebox_override("normal", box)
    return preview

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
    if editor_mode:
        return false
    var allowed = data is Dictionary and data.get("kind", "") == "player" and int(data.get("player_id", -1)) >= 0
    if allowed:
        add_theme_stylebox_override("panel", hover_style)
    return allowed

func _drop_data(_at_position: Vector2, data: Variant) -> void:
    if editor_mode:
        return
    _restore_style()
    player_dropped.emit(int(data.get("player_id", -1)), slot_id)

func _restore_style() -> void:
    if editor_mode:
        add_theme_stylebox_override("panel", edit_style)
    elif is_selected:
        add_theme_stylebox_override("panel", hover_style)
    elif player_id < 0 or (effective_rating >= 0 and effective_rating < int(player_data.get("rating", 0)) - 5):
        add_theme_stylebox_override("panel", warning_style)
    else:
        add_theme_stylebox_override("panel", normal_style)

func _notification(what: int) -> void:
    if what == NOTIFICATION_DRAG_END and normal_style != null:
        drag_started = false
        click_armed = false
        _restore_style()
