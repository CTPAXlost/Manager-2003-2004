class_name TacticsPitch
extends Control

signal player_dropped_on_pitch(player_id: int, local_position: Vector2)

var drag_hover_position = Vector2.ZERO
var drag_hover_active = false

func _ready() -> void:
    custom_minimum_size = Vector2(620, 500)
    mouse_filter = Control.MOUSE_FILTER_STOP
    queue_redraw()

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        queue_redraw()
    elif what == NOTIFICATION_DRAG_END:
        drag_hover_active = false
        queue_redraw()

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
    var allowed = data is Dictionary and data.get("kind", "") == "player" and int(data.get("player_id", -1)) >= 0
    drag_hover_active = allowed
    drag_hover_position = at_position
    queue_redraw()
    return allowed

func _drop_data(at_position: Vector2, data: Variant) -> void:
    drag_hover_active = false
    queue_redraw()
    player_dropped_on_pitch.emit(int(data.get("player_id", -1)), at_position)

func _draw() -> void:
    var r = Rect2(Vector2.ZERO, size)
    draw_rect(r, Color("0d563f"), true)
    var line = Color(0.75, 1.0, 0.88, 0.75)
    draw_rect(r.grow(-8), line, false, 2.0)
    draw_line(Vector2(8, size.y / 2.0), Vector2(size.x - 8, size.y / 2.0), line, 2.0)
    draw_circle(size / 2.0, min(size.x, size.y) * 0.095, line, false, 2.0)
    draw_circle(size / 2.0, 4.0, line, true)
    var box_w = size.x * 0.42
    var box_h = size.y * 0.17
    draw_rect(Rect2((size.x - box_w) / 2.0, 8, box_w, box_h), line, false, 2.0)
    draw_rect(Rect2((size.x - box_w) / 2.0, size.y - 8 - box_h, box_w, box_h), line, false, 2.0)
    var goal_w = size.x * 0.18
    draw_rect(Rect2((size.x - goal_w) / 2.0, 1, goal_w, 12), line, false, 2.0)
    draw_rect(Rect2((size.x - goal_w) / 2.0, size.y - 13, goal_w, 12), line, false, 2.0)
    if drag_hover_active:
        draw_circle(drag_hover_position, 28.0, Color(0.25, 0.88, 1.0, 0.18), true)
        draw_circle(drag_hover_position, 28.0, Color("40e0ff"), false, 2.0)
