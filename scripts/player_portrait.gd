class_name PlayerPortrait
extends Control

# Процедурный полу-реалистичный портрет для тактических карточек.
# Это всё ещё процедурный портрет, просто более детализированный визуально.
# Для Реала и Барселоны применяются клубные цвета, чтобы визуально тестировать
# премиальный стиль именно у этих команд.

var player_data: Dictionary = {}

func setup(data: Dictionary) -> void:
    player_data = data.duplicate(true)
    custom_minimum_size = Vector2(78, 86)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    queue_redraw()

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        queue_redraw()

func _seed() -> int:
    return abs(int(player_data.get("id", 0)) * 214013 + str(player_data.get("name", "")).hash())

func _team_colors() -> Dictionary:
    var club = str(player_data.get("club_name", ""))
    if club == "Реал Мадрид":
        return {"shirt": Color("edf1f4"), "shirt_2": Color("d9b44f"), "trim": Color("19314f"), "bg": Color("0d2842")}
    if club == "Барселона":
        return {"shirt": Color("173f95"), "shirt_2": Color("8e163a"), "trim": Color("ebd08f"), "bg": Color("1a1f52")}
    return {"shirt": Color("e4e7ea"), "shirt_2": Color("3294d4"), "trim": Color("d9b35f"), "bg": Color("0e2534")}

func _draw() -> void:
    if player_data.is_empty() or int(player_data.get("id", -1)) < 0:
        return

    var seed = _seed()
    var w = size.x
    var h = size.y
    var cx = w * 0.5
    var colors = _team_colors()
    var club_bg: Color = colors["bg"]

    var skin_palette = [
        Color("f0c6a4"), Color("dfa786"), Color("c78b67"),
        Color("a46849"), Color("7a4a33"), Color("e6bb94")
    ]
    var hair_palette = [Color("111111"), Color("36261e"), Color("5b3d2d"), Color("a57949"), Color("d7c49f")]
    var skin: Color = skin_palette[posmod(seed, skin_palette.size())]
    var hair: Color = hair_palette[posmod(seed / 17, hair_palette.size())]

    # Мягкий фон карточки.
    draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0), true)
    draw_circle(Vector2(cx, h * 0.44), w * 0.44, club_bg.lightened(0.16))
    draw_circle(Vector2(cx, h * 0.44), w * 0.37, club_bg.lightened(0.05))
    draw_circle(Vector2(cx, h * 0.44), w * 0.44, Color(1, 1, 1, 0.14), false, 1.5)

    # Плечи/майка.
    var shirt_main: Color = colors["shirt"]
    var shirt_alt: Color = colors["shirt_2"]
    var trim: Color = colors["trim"]
    var shoulder_y = h * 0.65
    var body_poly = PackedVector2Array([
        Vector2(cx - w * 0.36, h * 0.97),
        Vector2(cx - w * 0.28, shoulder_y + 6),
        Vector2(cx - w * 0.13, shoulder_y - 2),
        Vector2(cx - w * 0.08, shoulder_y - 7),
        Vector2(cx + w * 0.08, shoulder_y - 7),
        Vector2(cx + w * 0.13, shoulder_y - 2),
        Vector2(cx + w * 0.28, shoulder_y + 6),
        Vector2(cx + w * 0.36, h * 0.97),
    ])
    draw_colored_polygon(body_poly, shirt_main)
    if str(player_data.get("club_name", "")) == "Барселона":
        draw_rect(Rect2(cx - w * 0.18, shoulder_y - 4, w * 0.07, h * 0.28), shirt_alt, true)
        draw_rect(Rect2(cx - w * 0.05, shoulder_y - 7, w * 0.07, h * 0.32), shirt_alt, true)
        draw_rect(Rect2(cx + w * 0.08, shoulder_y - 4, w * 0.07, h * 0.28), shirt_alt, true)
    else:
        draw_polyline(PackedVector2Array([
            Vector2(cx - w * 0.30, h * 0.95), Vector2(cx, h * 0.80), Vector2(cx + w * 0.30, h * 0.95)
        ]), trim, 2.0, true)
    draw_polyline(PackedVector2Array([
        Vector2(cx - w * 0.08, shoulder_y - 6), Vector2(cx, shoulder_y + 4), Vector2(cx + w * 0.08, shoulder_y - 6)
    ]), trim, 2.0, true)

    # Шея.
    draw_rect(Rect2(cx - w * 0.07, h * 0.47, w * 0.14, h * 0.14), skin.darkened(0.04), true)

    # Голова.
    var head_center = Vector2(cx, h * 0.33)
    var head_rx = w * (0.18 + float(seed % 4) * 0.01)
    var head_ry = h * (0.16 + float((seed / 9) % 4) * 0.008)
    _draw_ellipse(head_center, head_rx, head_ry, skin)
    _draw_ellipse(head_center + Vector2(head_rx * 0.12, head_ry * 0.04), head_rx * 0.96, head_ry * 0.95, Color(1, 1, 1, 0.05))

    # Уши.
    draw_circle(Vector2(cx - head_rx * 0.94, head_center.y), w * 0.018, skin.darkened(0.03))
    draw_circle(Vector2(cx + head_rx * 0.94, head_center.y), w * 0.018, skin.darkened(0.03))

    # Волосы.
    var hair_style = posmod(seed / 41, 6)
    if hair_style == 0:
        draw_arc(head_center - Vector2(0, head_ry * 0.15), head_rx * 0.98, PI, TAU, 24, hair, max(4.0, w * 0.08))
    elif hair_style == 1:
        draw_colored_polygon(PackedVector2Array([
            Vector2(cx - head_rx * 0.92, head_center.y - head_ry * 0.22),
            Vector2(cx - head_rx * 0.58, head_center.y - head_ry * 0.95),
            Vector2(cx + head_rx * 0.15, head_center.y - head_ry * 0.98),
            Vector2(cx + head_rx * 0.88, head_center.y - head_ry * 0.18),
            Vector2(cx + head_rx * 0.30, head_center.y - head_ry * 0.42),
            Vector2(cx - head_rx * 0.55, head_center.y - head_ry * 0.40)
        ]), hair)
    elif hair_style == 2:
        for i in range(6):
            var px = cx - head_rx * 0.72 + i * head_rx * 0.28
            draw_circle(Vector2(px, head_center.y - head_ry * (0.80 + 0.05 * sin(float(i)))), w * 0.040, hair)
    elif hair_style == 3:
        draw_arc(head_center - Vector2(0, head_ry * 0.12), head_rx * 1.00, PI, TAU, 24, hair, max(2.0, w * 0.05))
        draw_line(Vector2(cx - head_rx * 0.88, head_center.y - head_ry * 0.16), Vector2(cx - head_rx * 0.72, head_center.y + head_ry * 0.55), hair, 2.0)
        draw_line(Vector2(cx + head_rx * 0.88, head_center.y - head_ry * 0.16), Vector2(cx + head_rx * 0.72, head_center.y + head_ry * 0.55), hair, 2.0)
    elif hair_style == 4:
        draw_arc(head_center - Vector2(0, head_ry * 0.05), head_rx * 1.02, PI + 0.18, TAU - 0.18, 24, hair, max(6.0, w * 0.11))
    else:
        draw_arc(head_center - Vector2(0, head_ry * 0.30), head_rx * 0.55, PI, TAU, 24, hair, max(5.0, w * 0.08))

    # Лицо.
    var eye_y = head_center.y - head_ry * 0.02
    draw_line(Vector2(cx - head_rx * 0.42, eye_y), Vector2(cx - head_rx * 0.20, eye_y), Color("2a221f"), 1.2)
    draw_line(Vector2(cx + head_rx * 0.20, eye_y), Vector2(cx + head_rx * 0.42, eye_y), Color("2a221f"), 1.2)
    draw_line(Vector2(cx - head_rx * 0.46, eye_y - 4), Vector2(cx - head_rx * 0.20, eye_y - 5), hair.darkened(0.08), 1.1)
    draw_line(Vector2(cx + head_rx * 0.20, eye_y - 5), Vector2(cx + head_rx * 0.46, eye_y - 4), hair.darkened(0.08), 1.1)
    draw_line(Vector2(cx, head_center.y + head_ry * 0.01), Vector2(cx - 1, head_center.y + head_ry * 0.26), skin.darkened(0.16), 1.0)
    draw_line(Vector2(cx - head_rx * 0.16, head_center.y + head_ry * 0.44), Vector2(cx + head_rx * 0.16, head_center.y + head_ry * 0.44), Color("6e433a"), 1.2)

    if posmod(seed / 7, 5) == 0:
        draw_arc(Vector2(cx, head_center.y + head_ry * 0.16), head_rx * 0.26, 0.2, PI - 0.2, 14, hair.darkened(0.1), 2.0)
        draw_arc(Vector2(cx, head_center.y + head_ry * 0.32), head_rx * 0.20, 0.15, PI - 0.15, 14, hair.darkened(0.1), 1.8)

    # Небольшая окантовка портрета.
    draw_circle(Vector2(cx, h * 0.44), w * 0.44, Color(1, 1, 1, 0.08), false, 1.0)

    var shirt_no = str(1 + posmod(int(player_data.get("id", 0)), 30))
    draw_string(ThemeDB.fallback_font, Vector2(cx - 5, h * 0.95), shirt_no, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1, 0.65))

func _draw_ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
    var points := PackedVector2Array()
    for i in range(32):
        var angle = TAU * float(i) / 32.0
        points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
    draw_colored_polygon(points, color)
