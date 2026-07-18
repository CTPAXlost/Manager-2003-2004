class_name PlayerPortrait
extends Control

# Небольшой процедурный портрет для тактической карточки. Это не фотография
# и не попытка воспроизвести точную внешность реального футболиста: задача —
# дать каждому игроку узнаваемую, взрослую футбольную подачу без смайликов.

var player_data: Dictionary = {}

func setup(data: Dictionary) -> void:
    player_data = data.duplicate(true)
    custom_minimum_size = Vector2(56, 74)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    queue_redraw()

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        queue_redraw()

func _seed() -> int:
    return abs(int(player_data.get("id", 0)) * 1103515245 + str(player_data.get("name", "")).hash())

func _palette_value(items: Array, index: int) -> Color:
    return items[posmod(index, items.size())]

func _draw() -> void:
    if player_data.is_empty() or int(player_data.get("id", -1)) < 0:
        return

    var seed = _seed()
    var w = size.x
    var h = size.y
    var cx = w * 0.5

    var skin_palette: Array = [
        Color("f0c7a1"), Color("d8a17a"), Color("bd805c"),
        Color("996044"), Color("74442f"), Color("d9aa86")
    ]
    var hair_palette: Array = [Color("171412"), Color("35261f"), Color("5a3d2b"), Color("b38b60"), Color("d7c4a0")]
    var kit_palette: Array = [
        Color("f4f5f4"), Color("d8303f"), Color("1d58a8"),
        Color("171c26"), Color("78338f"), Color("e2b72f"),
        Color("19845d"), Color("7d1522"), Color("7fc8ea")
    ]
    var trim_palette: Array = [Color("091823"), Color("f1f1ec"), Color("d7ab35"), Color("35d4de")]

    var skin: Color = _palette_value(skin_palette, seed)
    var hair: Color = _palette_value(hair_palette, seed / 11)
    var kit: Color = _palette_value(kit_palette, seed / 23)
    var trim: Color = _palette_value(trim_palette, seed / 43)

    # Подложка карточки с мягкой глубиной.
    var card = Rect2(2, 2, w - 4, h - 4)
    draw_style_box(_portrait_card_style(Color(0.025, 0.075, 0.10, 0.88), Color(0.16, 0.72, 0.72, 0.74)), card)
    draw_circle(Vector2(cx, h * 0.38), w * 0.35, Color(0.06, 0.22, 0.24, 0.58))

    # Плечи и футболка — крупный бюст, а не миниатюрная фигура целиком.
    var shoulder_y = h * 0.64
    var shirt = PackedVector2Array([
        Vector2(cx - w * 0.36, h * 0.92),
        Vector2(cx - w * 0.32, shoulder_y + 3),
        Vector2(cx - w * 0.16, shoulder_y - 4),
        Vector2(cx - w * 0.09, shoulder_y - 9),
        Vector2(cx + w * 0.09, shoulder_y - 9),
        Vector2(cx + w * 0.16, shoulder_y - 4),
        Vector2(cx + w * 0.32, shoulder_y + 3),
        Vector2(cx + w * 0.36, h * 0.92)
    ])
    draw_colored_polygon(shirt, kit)
    draw_polyline(PackedVector2Array([Vector2(cx - w * 0.34, h * 0.91), Vector2(cx, h * 0.78), Vector2(cx + w * 0.34, h * 0.91)]), trim, 2.0, true)
    draw_line(Vector2(cx - w * 0.23, shoulder_y + 1), Vector2(cx - w * 0.30, h * 0.84), Color(1, 1, 1, 0.22), 1.0)
    draw_line(Vector2(cx + w * 0.23, shoulder_y + 1), Vector2(cx + w * 0.30, h * 0.84), Color(0, 0, 0, 0.22), 1.0)

    # Шея.
    draw_rect(Rect2(cx - w * 0.075, h * 0.51, w * 0.15, h * 0.16), skin.darkened(0.06), true)

    # Голова с более естественным овалом и светотенью.
    var head_center = Vector2(cx, h * 0.36)
    var head_w = w * (0.25 + float(seed % 5) * 0.008)
    var head_h = h * (0.255 + float((seed / 5) % 4) * 0.008)
    draw_set_transform(head_center, 0.0, Vector2(head_w, head_h))
    draw_circle(Vector2.ZERO, 1.0, skin)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    draw_arc(head_center + Vector2(head_w * 0.20, 0), head_h * 0.82, -1.25, 1.15, 20, Color(0, 0, 0, 0.11), 2.0)

    # Уши.
    draw_circle(Vector2(cx - head_w * 0.93, head_center.y), w * 0.028, skin.darkened(0.04))
    draw_circle(Vector2(cx + head_w * 0.93, head_center.y), w * 0.028, skin.darkened(0.04))

    # Волосы: несколько взрослых силуэтов без комичных деталей.
    var hair_style = posmod(seed / 71, 5)
    if hair_style == 0:
        draw_arc(head_center - Vector2(0, head_h * 0.18), head_w * 0.95, PI, TAU, 24, hair, max(3.0, w * 0.07))
    elif hair_style == 1:
        draw_colored_polygon(PackedVector2Array([
            Vector2(cx - head_w * 0.88, head_center.y - head_h * 0.28),
            Vector2(cx - head_w * 0.55, head_center.y - head_h * 0.86),
            Vector2(cx + head_w * 0.55, head_center.y - head_h * 0.86),
            Vector2(cx + head_w * 0.90, head_center.y - head_h * 0.20),
            Vector2(cx + head_w * 0.45, head_center.y - head_h * 0.46),
            Vector2(cx - head_w * 0.50, head_center.y - head_h * 0.43)
        ]), hair)
    elif hair_style == 2:
        for i in range(7):
            var px = cx - head_w * 0.75 + i * head_w * 0.25
            draw_circle(Vector2(px, head_center.y - head_h * (0.74 + 0.06 * sin(float(i)))), w * 0.055, hair)
    elif hair_style == 3:
        draw_arc(head_center - Vector2(0, head_h * 0.22), head_w * 0.94, PI, TAU, 24, hair, max(5.0, w * 0.10))
        draw_line(Vector2(cx - head_w * 0.90, head_center.y - head_h * 0.18), Vector2(cx - head_w * 0.75, head_center.y + head_h * 0.52), hair, 3.0)
        draw_line(Vector2(cx + head_w * 0.90, head_center.y - head_h * 0.18), Vector2(cx + head_w * 0.75, head_center.y + head_h * 0.52), hair, 3.0)
    else:
        draw_arc(head_center - Vector2(0, head_h * 0.16), head_w * 0.96, PI + 0.15, TAU - 0.15, 24, hair, max(2.0, w * 0.045))

    # Сдержанные черты лица. Они дают объём, но не превращают портрет в смайлик.
    var brow_y = head_center.y - head_h * 0.10
    draw_line(Vector2(cx - head_w * 0.48, brow_y), Vector2(cx - head_w * 0.18, brow_y - 1), hair.darkened(0.12), 1.2)
    draw_line(Vector2(cx + head_w * 0.18, brow_y - 1), Vector2(cx + head_w * 0.48, brow_y), hair.darkened(0.12), 1.2)
    draw_line(Vector2(cx - head_w * 0.38, head_center.y), Vector2(cx - head_w * 0.20, head_center.y), Color("342a27"), 1.1)
    draw_line(Vector2(cx + head_w * 0.20, head_center.y), Vector2(cx + head_w * 0.38, head_center.y), Color("342a27"), 1.1)
    draw_line(Vector2(cx, head_center.y + head_h * 0.03), Vector2(cx - 1, head_center.y + head_h * 0.27), skin.darkened(0.18), 1.1)
    draw_line(Vector2(cx - head_w * 0.17, head_center.y + head_h * 0.48), Vector2(cx + head_w * 0.17, head_center.y + head_h * 0.48), Color("6a3f39"), 1.1)

    # Воротник и маленький номер создают ощущение игровой карточки.
    draw_polyline(PackedVector2Array([
        Vector2(cx - w * 0.10, shoulder_y - 8),
        Vector2(cx, shoulder_y + 1),
        Vector2(cx + w * 0.10, shoulder_y - 8)
    ]), trim, 2.0, true)
    var number = str(1 + posmod(int(player_data.get("id", 0)), 30))
    draw_string(ThemeDB.fallback_font, Vector2(cx - 4, h * 0.88), number, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1, 0.72))

func _portrait_card_style(background: Color, border: Color) -> StyleBoxFlat:
    var style = StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = border
    style.set_border_width_all(1)
    style.set_corner_radius_all(10)
    return style
