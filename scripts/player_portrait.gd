class_name PlayerPortrait
extends Control

var player_data: Dictionary = {}

func setup(data: Dictionary) -> void:
    player_data = data.duplicate(true)
    custom_minimum_size = Vector2(52, 66)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    queue_redraw()

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        queue_redraw()

func _seed() -> int:
    return abs(int(player_data.get("id", 0)) * 1103515245 + str(player_data.get("name", "")).hash())

func _draw() -> void:
    if player_data.is_empty() or int(player_data.get("id", -1)) < 0:
        return
    var seed = _seed()
    var center_x = size.x * 0.5
    var skin_palette = [Color("e8bd98"), Color("c98d68"), Color("9a6347"), Color("74462f"), Color("d9a17a")]
    var kit_palette = [Color("f3f5f7"), Color("d53b47"), Color("245eaa"), Color("171a20"), Color("7a2d93"), Color("e0b12f"), Color("26a06d")]
    var trim_palette = [Color("18232e"), Color("f4f4f4"), Color("d8b34c"), Color("54d6e8")]
    var skin: Color = skin_palette[seed % skin_palette.size()]
    var kit: Color = kit_palette[(seed / 7) % kit_palette.size()]
    var trim: Color = trim_palette[(seed / 17) % trim_palette.size()]

    # Нейтральная стилизованная фигура футболиста: без карикатурных глаз и
    # попытки выдать случайное лицо за реального человека.
    draw_circle(Vector2(center_x, 12), 7.0, skin, true)
    var hair = Color("1b1715")
    draw_arc(Vector2(center_x, 11), 7.0, PI, TAU, 14, hair, 3.0)

    var shirt = PackedVector2Array([
        Vector2(center_x - 8, 20), Vector2(center_x - 18, 27),
        Vector2(center_x - 13, 39), Vector2(center_x - 8, 36),
        Vector2(center_x - 7, 49), Vector2(center_x + 7, 49),
        Vector2(center_x + 8, 36), Vector2(center_x + 13, 39),
        Vector2(center_x + 18, 27), Vector2(center_x + 8, 20)
    ])
    draw_colored_polygon(shirt, kit)
    draw_line(Vector2(center_x - 8, 21), Vector2(center_x + 8, 21), trim, 2.0)
    draw_line(Vector2(center_x, 22), Vector2(center_x, 47), Color(1, 1, 1, 0.18), 1.0)

    draw_rect(Rect2(center_x - 8, 49, 16, 8), Color("18212a"), true)
    draw_line(Vector2(center_x - 4, 57), Vector2(center_x - 6, 65), skin, 4.0)
    draw_line(Vector2(center_x + 4, 57), Vector2(center_x + 6, 65), skin, 4.0)
