class_name PlayerToken
extends PanelContainer

signal player_selected(player_id: int)

var player_data: Dictionary = {}
var compact = false
var click_armed = false
var drag_started = false
var press_position = Vector2.ZERO
var is_selected = false
var normal_style: StyleBoxFlat
var hover_style: StyleBoxFlat
var selected_style: StyleBoxFlat
var main_label: Label
var details_label: Label

func setup(data: Dictionary, is_compact = false) -> void:
    player_data = data.duplicate(true)
    compact = is_compact
    custom_minimum_size = Vector2(170 if compact else 270, 60 if compact else 58)
    mouse_default_cursor_shape = Control.CURSOR_DRAG
    mouse_filter = Control.MOUSE_FILTER_STOP
    mouse_force_pass_scroll_events = false
    focus_mode = Control.FOCUS_NONE

    normal_style = _make_style(Color("101a23"), Color("1d3342"), 1)
    hover_style = _make_style(Color("183243"), Color("40e0ff"), 2)
    selected_style = _make_style(Color("164459"), Color("74f3c0"), 2)
    add_theme_stylebox_override("panel", normal_style)

    var box = VBoxContainer.new()
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    box.add_theme_constant_override("separation", 1)
    add_child(box)

    main_label = Label.new()
    main_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    main_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    main_label.add_theme_font_size_override("font_size", 12 if compact else 13)
    main_label.add_theme_color_override("font_color", Color("e8f3f8"))
    box.add_child(main_label)

    details_label = Label.new()
    details_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    details_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    details_label.add_theme_font_size_override("font_size", 10 if compact else 11)
    details_label.add_theme_color_override("font_color", Color("8ba2b0"))
    box.add_child(details_label)
    refresh()

func _make_style(background: Color, border: Color, width: int) -> StyleBoxFlat:
    var style = StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = border
    style.set_border_width_all(width)
    style.set_corner_radius_all(8)
    style.content_margin_left = 12
    style.content_margin_right = 12
    style.content_margin_top = 7
    style.content_margin_bottom = 7
    return style

func refresh() -> void:
    if main_label == null or details_label == null:
        return
    var name = str(player_data.get("name", "Игрок"))
    var primary = str(player_data.get("position", "?"))
    var secondaries: Array = player_data.get("secondary", [])
    var positions = primary
    if not secondaries.is_empty():
        positions += " / " + ", ".join(secondaries)
    main_label.text = ("▦  " + name) if not compact else _surname(name)
    details_label.text = "%s · рейтинг %d · форма %d%%" % [positions, int(player_data.get("rating", 0)), int(player_data.get("condition", 100))]
    tooltip_text = "%s\nОсновная: %s\nДополнительные: %s\nПеретащите на поле либо нажмите и затем выберите позицию" % [name, primary, ", ".join(secondaries) if not secondaries.is_empty() else "нет"]

func _surname(full_name: String) -> String:
    var parts = full_name.split(" ")
    return parts[parts.size() - 1] if parts.size() > 0 else full_name

func set_selected(value: bool) -> void:
    is_selected = value
    _restore_style()

func _gui_input(event: InputEvent) -> void:
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
                player_selected.emit(int(player_data.get("id", -1)))
            _restore_style()
            accept_event()
    elif event is InputEventMouseMotion and click_armed and not drag_started:
        if event.position.distance_to(press_position) > 4.0:
            drag_started = true
            click_armed = false
            force_drag(_drag_payload(), _make_drag_preview())
            accept_event()

func _get_drag_data(_at_position: Vector2) -> Variant:
    if player_data.is_empty():
        return null
    drag_started = true
    click_armed = false
    set_drag_preview(_make_drag_preview())
    return _drag_payload()

func _drag_payload() -> Dictionary:
    return {"kind": "player", "player_id": int(player_data.get("id", -1)), "source": "bench"}

func _make_drag_preview() -> Control:
    var preview = Label.new()
    preview.text = "%s  [%s · %d]" % [player_data.get("name", "Игрок"), player_data.get("position", "?"), int(player_data.get("rating", 0))]
    preview.add_theme_font_size_override("font_size", 14)
    preview.add_theme_color_override("font_color", Color("d9fbff"))
    var box = StyleBoxFlat.new()
    box.bg_color = Color("183347")
    box.border_color = Color("40e0ff")
    box.set_border_width_all(2)
    box.set_corner_radius_all(8)
    box.content_margin_left = 12
    box.content_margin_right = 12
    box.content_margin_top = 8
    box.content_margin_bottom = 8
    preview.add_theme_stylebox_override("normal", box)
    return preview

func _restore_style() -> void:
    if selected_style == null:
        return
    add_theme_stylebox_override("panel", selected_style if is_selected else normal_style)

func _notification(what: int) -> void:
    if what == NOTIFICATION_MOUSE_ENTER and not drag_started:
        add_theme_stylebox_override("panel", hover_style)
    elif what == NOTIFICATION_MOUSE_EXIT and not drag_started:
        _restore_style()
    elif what == NOTIFICATION_DRAG_END:
        drag_started = false
        click_armed = false
        _restore_style()
