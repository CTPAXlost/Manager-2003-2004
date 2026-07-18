class_name PlayerPortrait
extends Control

var player_data: Dictionary = {}

func setup(data: Dictionary) -> void:
    player_data = data.duplicate(true)
    custom_minimum_size = Vector2(46, 46)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    queue_redraw()

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        queue_redraw()

func _seed() -> int:
    var value = int(player_data.get("id", 0)) * 1103515245 + str(player_data.get("name", "")).hash()
    return abs(value)

func _draw() -> void:
    var center = size * 0.5
    var radius = min(size.x, size.y) * 0.46
    draw_circle(center, radius, Color("0b2530"), true)
    draw_circle(center, radius, Color("3bd5d5"), false, 1.5)
    if player_data.is_empty() or int(player_data.get("id", -1)) < 0:
        draw_circle(center, radius * 0.38, Color("29424b"), true)
        return

    var seed = _seed()
    var skin_palette = [Color("f1c7a5"), Color("d99b72"), Color("b97852"), Color("8c573d"), Color("f0b98e")]
    var hair_palette = [Color("201713"), Color("5b3924"), Color("d3b069"), Color("16181b"), Color("7c4d32")]
    var jersey_palette = [Color("c83e4d"), Color("e6e8e6"), Color("246a9c"), Color("151515"), Color("7d2e8e"), Color("e0b12f")]
    var skin: Color = skin_palette[seed % skin_palette.size()]
    var hair: Color = hair_palette[(seed / 7) % hair_palette.size()]
    var jersey: Color = jersey_palette[(seed / 17) % jersey_palette.size()]

    var torso = PackedVector2Array([
        Vector2(center.x - radius * 0.60, center.y + radius * 0.78),
        Vector2(center.x - radius * 0.42, center.y + radius * 0.22),
        Vector2(center.x + radius * 0.42, center.y + radius * 0.22),
        Vector2(center.x + radius * 0.60, center.y + radius * 0.78),
    ])
    draw_colored_polygon(torso, jersey)
    draw_line(Vector2(center.x, center.y + radius * 0.25), Vector2(center.x, center.y + radius * 0.78), Color(1,1,1,0.22), 1.0)

    var head_center = Vector2(center.x, center.y - radius * 0.08)
    draw_circle(head_center, radius * 0.42, skin, true)

    var hair_style = seed % 4
    if hair_style == 0:
        draw_arc(head_center, radius * 0.40, PI, TAU, 20, hair, radius * 0.18)
    elif hair_style == 1:
        draw_circle(Vector2(head_center.x, head_center.y - radius * 0.22), radius * 0.30, hair, true)
    elif hair_style == 2:
        var hair_poly = PackedVector2Array([
            Vector2(head_center.x - radius * 0.40, head_center.y - radius * 0.03),
            Vector2(head_center.x - radius * 0.25, head_center.y - radius * 0.42),
            Vector2(head_center.x + radius * 0.15, head_center.y - radius * 0.48),
            Vector2(head_center.x + radius * 0.40, head_center.y - radius * 0.05),
        ])
        draw_colored_polygon(hair_poly, hair)
    else:
        draw_arc(head_center, radius * 0.39, PI * 1.05, PI * 1.95, 16, hair, radius * 0.13)

    var eye_y = head_center.y - radius * 0.02
    draw_circle(Vector2(head_center.x - radius * 0.14, eye_y), radius * 0.028, Color("1a1d20"), true)
    draw_circle(Vector2(head_center.x + radius * 0.14, eye_y), radius * 0.028, Color("1a1d20"), true)
    draw_line(Vector2(head_center.x - radius * 0.11, head_center.y + radius * 0.17), Vector2(head_center.x + radius * 0.11, head_center.y + radius * 0.17), Color("713f37"), 1.0)
