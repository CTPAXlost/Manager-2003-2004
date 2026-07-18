class_name PlayerPortrait
extends Control

# Компактный мини-портрет для карточки на поле.
# Для Реала и Барселоны используются индивидуальные профили, чтобы игроки
# были узнаваемы визуально, а не выглядели как случайные аватары.

var player_data: Dictionary = {}
var portrait_texture: Texture2D


func setup(data: Dictionary) -> void:
    player_data = data.duplicate(true)
    portrait_texture = null
    var portrait_path := _custom_portrait_path()
    if not portrait_path.is_empty() and ResourceLoader.exists(portrait_path):
        portrait_texture = load(portrait_path)
        custom_minimum_size = Vector2(74, 96)
    else:
        custom_minimum_size = Vector2(50, 58)
    size = custom_minimum_size
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    queue_redraw()

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        queue_redraw()

func _seed() -> int:
    return abs(int(player_data.get("id", 0)) * 214013 + str(player_data.get("name", "")).hash())

func _parse_color(hex: String) -> Color:
    return Color(hex)

func _custom_portrait_path() -> String:
    var name := str(player_data.get("name", ""))
    if name.is_empty():
        return ""
    var map := {
        "Iker Casillas": "res://assets/portraits/real_madrid/iker_casillas.png",
        "Roberto Carlos": "res://assets/portraits/real_madrid/roberto_carlos.png",
        "Iván Helguera": "res://assets/portraits/real_madrid/ivan_helguera.png",
        "Francisco Pavón": "res://assets/portraits/real_madrid/francisco_pavon.png",
        "Míchel Salgado": "res://assets/portraits/real_madrid/michel_salgado.png",
        "David Beckham": "res://assets/portraits/real_madrid/david_beckham.png",
        "Zinedine Zidane": "res://assets/portraits/real_madrid/zinedine_zidane.png",
        "Esteban Cambiasso": "res://assets/portraits/real_madrid/esteban_cambiasso.png",
        "Luís Figo": "res://assets/portraits/real_madrid/luis_figo.png",
        "Santiago Solari": "res://assets/portraits/real_madrid/santiago_solari.png",
        "Raúl": "res://assets/portraits/real_madrid/raul.png",
        "Ronaldo": "res://assets/portraits/real_madrid/ronaldo.png",
    }
    return map.get(name, "")

func _team_palette() -> Dictionary:
    var club = str(player_data.get("club_name", ""))
    if club == "Реал Мадрид":
        return {
            "frame": _parse_color("d8b354"),
            "bg": _parse_color("0d1730"),
            "bg2": _parse_color("1b2c53"),
            "line": _parse_color("27486e"),
            "shirt": _parse_color("f5f6f8"),
            "shirt2": _parse_color("d5b15b"),
            "text": _parse_color("e9edf3"),
        }
    if club == "Барселона":
        return {
            "frame": _parse_color("d8b354"),
            "bg": _parse_color("11193a"),
            "bg2": _parse_color("213c88"),
            "line": _parse_color("5c1d41"),
            "shirt": _parse_color("8f1539"),
            "shirt2": _parse_color("214c9f"),
            "text": _parse_color("e9edf3"),
        }
    return {
        "frame": _parse_color("c79434"),
        "bg": _parse_color("0d1730"),
        "bg2": _parse_color("203958"),
        "line": _parse_color("27486e"),
        "shirt": _parse_color("eff5fa"),
        "shirt2": _parse_color("3a9ad8"),
        "text": _parse_color("e9edf3"),
    }

func _premium_profile() -> Dictionary:
    var club = str(player_data.get("club_name", ""))
    if club != "Реал Мадрид" and club != "Барселона":
        return {}

    var profiles := {
        # Реал Мадрид
        "Iker Casillas": {"skin":"e4b38d", "hair":"3a271d", "hair_style":"short", "beard":"none", "eye":"3b2a1e"},
        "César Sánchez": {"skin":"e0b08c", "hair":"2b201c", "hair_style":"short", "beard":"stubble"},
        "Roberto Carlos": {"skin":"7d5139", "hair":"1a1a1a", "hair_style":"bald", "beard":"none"},
        "Míchel Salgado": {"skin":"d7a17a", "hair":"241b18", "hair_style":"medium", "beard":"stubble"},
        "Iván Helguera": {"skin":"ddb18a", "hair":"362823", "hair_style":"short", "beard":"none"},
        "Francisco Pavón": {"skin":"d8a985", "hair":"2a2220", "hair_style":"short", "beard":"none"},
        "Raúl Bravo": {"skin":"d6a179", "hair":"2d221c", "hair_style":"short", "beard":"none"},
        "David Beckham": {"skin":"e4b793", "hair":"b8874f", "hair_style":"mohawk", "beard":"stubble"},
        "Esteban Cambiasso": {"skin":"dcb08a", "hair":"2d2524", "hair_style":"bald", "beard":"none"},
        "Guti": {"skin":"e6ba97", "hair":"cfb16f", "hair_style":"medium", "beard":"none"},
        "Albert Celades": {"skin":"ddb089", "hair":"3a2b22", "hair_style":"short", "beard":"none"},
        "Zinedine Zidane": {"skin":"dfb08a", "hair":"2b1d18", "hair_style":"bald", "beard":"stubble"},
        "Santiago Solari": {"skin":"d3a07a", "hair":"3b2b20", "hair_style":"long", "beard":"none"},
        "Luís Figo": {"skin":"dca57d", "hair":"2d1f18", "hair_style":"medium", "beard":"stubble"},
        "Raúl": {"skin":"d8aa84", "hair":"261d18", "hair_style":"short", "beard":"none"},
        "Ronaldo": {"skin":"9f694a", "hair":"1b1b1b", "hair_style":"buzz", "beard":"none"},
        "Javier Portillo": {"skin":"dfb18b", "hair":"261f19", "hair_style":"short", "beard":"none"},
        "Borja Fernández": {"skin":"e0b38e", "hair":"2e241d", "hair_style":"short", "beard":"none"},
        # Барселона
        "Víctor Valdés": {"skin":"ddb089", "hair":"271f1c", "hair_style":"short", "beard":"stubble"},
        "Rüştü Reçber": {"skin":"c79270", "hair":"111111", "hair_style":"long", "beard":"goatee", "band":"black"},
        "Carles Puyol": {"skin":"ddb089", "hair":"5e422d", "hair_style":"curly_long", "beard":"stubble"},
        "Rafael Márquez": {"skin":"c89271", "hair":"211a18", "hair_style":"short", "beard":"goatee"},
        "Oleguer": {"skin":"d7a580", "hair":"4a352a", "hair_style":"curly_long", "beard":"none"},
        "Giovanni van Bronckhorst": {"skin":"c99772", "hair":"241c18", "hair_style":"short", "beard":"stubble"},
        "Gabri": {"skin":"d8aa84", "hair":"2b201b", "hair_style":"short", "beard":"none"},
        "Phillip Cocu": {"skin":"e3b68f", "hair":"d6b277", "hair_style":"short", "beard":"none"},
        "Edgar Davids": {"skin":"7d523a", "hair":"111111", "hair_style":"braids", "beard":"goatee", "glasses":true},
        "Xavi": {"skin":"d8a985", "hair":"2d231e", "hair_style":"short", "beard":"stubble"},
        "Ronaldinho": {"skin":"7b5037", "hair":"111111", "hair_style":"ponytail", "beard":"goatee", "band":"black"},
        "Luis Enrique": {"skin":"d7a27f", "hair":"30241e", "hair_style":"short", "beard":"stubble"},
        "Andrés Iniesta": {"skin":"e6be9b", "hair":"c09d70", "hair_style":"short", "beard":"none"},
        "Patrick Kluivert": {"skin":"7c5239", "hair":"171717", "hair_style":"buzz", "beard":"goatee"},
        "Javier Saviola": {"skin":"dfb28b", "hair":"412b1e", "hair_style":"long", "beard":"none"},
        "Luis García": {"skin":"d9aa82", "hair":"2a211c", "hair_style":"short", "beard":"stubble"},
        "Ricardo Quaresma": {"skin":"d3a07a", "hair":"1b1b1b", "hair_style":"medium", "beard":"none"},
        "Lionel Messi": {"skin":"ddb08c", "hair":"2d241f", "hair_style":"shaggy", "beard":"none"},
    }
    return profiles.get(str(player_data.get("name", "")), {})

func _fallback_profile() -> Dictionary:
    var seed = _seed()
    var skins = ["e8bf9c", "ddb18d", "cc946d", "9b674b", "6f4632"]
    var hairs = ["111111", "2f241f", "5a3c29", "a27446", "d1b88b"]
    var styles = ["short", "medium", "buzz", "long", "shaggy"]
    return {
        "skin": skins[posmod(seed, skins.size())],
        "hair": hairs[posmod(int(seed / 13), hairs.size())],
        "hair_style": styles[posmod(int(seed / 17), styles.size())],
        "beard": ["none", "stubble", "none", "none", "goatee"][posmod(int(seed / 19), 5)],
        "eye": "2f241f",
    }

func _player_profile() -> Dictionary:
    var profile = _premium_profile()
    if profile.is_empty():
        profile = _fallback_profile()
    if not profile.has("eye"):
        profile["eye"] = "2f241f"
    return profile

func _draw() -> void:
    if player_data.is_empty() or int(player_data.get("id", -1)) < 0:
        return

    if portrait_texture != null:
        draw_texture_rect(portrait_texture, Rect2(Vector2.ZERO, size), false)
        return

    var pal = _team_palette()
    var profile = _player_profile()
    var card = Rect2(Vector2.ZERO, size)
    var outer = StyleBoxFlat.new()
    outer.bg_color = Color("07121d")
    outer.border_color = pal["frame"]
    outer.set_border_width_all(1)
    outer.set_corner_radius_all(7)
    draw_style_box(outer, card)

    var inner = Rect2(3, 3, size.x - 6, size.y - 6)
    var inner_style = StyleBoxFlat.new()
    inner_style.bg_color = pal["bg"]
    inner_style.border_color = Color(1, 1, 1, 0.06)
    inner_style.set_border_width_all(1)
    inner_style.set_corner_radius_all(6)
    draw_style_box(inner_style, inner)

    draw_rect(Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.36)), pal["bg2"], true)
    draw_line(inner.position + Vector2(0, inner.size.y * 0.36), inner.position + Vector2(inner.size.x, inner.size.y * 0.36), pal["line"], 1.0)

    _draw_portrait(inner, profile, pal)
    draw_rect(inner, Color(1, 1, 1, 0.04), false, 1.0)

func _draw_portrait(rect: Rect2, profile: Dictionary, pal: Dictionary) -> void:
    var skin = _parse_color(str(profile.get("skin", "ddb18d")))
    var hair = _parse_color(str(profile.get("hair", "2a211d")))
    var eye = _parse_color(str(profile.get("eye", "2f241f")))
    var hair_style = str(profile.get("hair_style", "short"))
    var beard_style = str(profile.get("beard", "none"))
    var band = str(profile.get("band", ""))
    var has_glasses = bool(profile.get("glasses", false))

    var cx = rect.get_center().x
    var top_y = rect.position.y
    var head_center = Vector2(cx, top_y + 24)
    var head_rx = 9.4
    var head_ry = 11.2

    # Плечи/майка
    var shirt_main: Color = pal["shirt"]
    var shirt_alt: Color = pal["shirt2"]
    draw_colored_polygon(PackedVector2Array([
        Vector2(cx - 18, rect.position.y + rect.size.y - 1),
        Vector2(cx - 12, head_center.y + 18),
        Vector2(cx - 4, head_center.y + 15),
        Vector2(cx + 4, head_center.y + 15),
        Vector2(cx + 12, head_center.y + 18),
        Vector2(cx + 18, rect.position.y + rect.size.y - 1),
    ]), shirt_main)
    if str(player_data.get("club_name", "")) == "Барселона":
        draw_rect(Rect2(cx - 10, head_center.y + 16, 5, 22), shirt_alt, true)
        draw_rect(Rect2(cx - 1, head_center.y + 16, 5, 22), shirt_alt, true)
        draw_rect(Rect2(cx + 8, head_center.y + 16, 5, 22), shirt_alt, true)
    else:
        draw_line(Vector2(cx - 13, head_center.y + 22), Vector2(cx, head_center.y + 16), shirt_alt, 1.6)
        draw_line(Vector2(cx + 13, head_center.y + 22), Vector2(cx, head_center.y + 16), shirt_alt, 1.6)
    draw_colored_polygon(PackedVector2Array([
        Vector2(cx - 5, head_center.y + 16), Vector2(cx, head_center.y + 22), Vector2(cx + 5, head_center.y + 16), Vector2(cx, head_center.y + 18)
    ]), Color("ffffff"))

    # Шея и голова
    draw_rect(Rect2(cx - 3.5, head_center.y + 10, 7, 5), skin.darkened(0.06), true)
    _draw_ellipse(head_center, head_rx, head_ry, skin)
    draw_circle(Vector2(cx - head_rx + 1, head_center.y), 1.5, skin.darkened(0.05))
    draw_circle(Vector2(cx + head_rx - 1, head_center.y), 1.5, skin.darkened(0.05))

    _draw_hair(head_center, head_rx, head_ry, hair, hair_style)

    if not band.is_empty():
        var band_color = _parse_color("202020") if band == "black" else _parse_color(band)
        draw_rect(Rect2(cx - head_rx - 1, head_center.y - 6, head_rx * 2 + 2, 3.2), band_color, true)

    # Лицо
    draw_line(Vector2(cx - 4, head_center.y - 1), Vector2(cx - 2, head_center.y - 1), eye, 1.0)
    draw_line(Vector2(cx + 2, head_center.y - 1), Vector2(cx + 4, head_center.y - 1), eye, 1.0)
    draw_line(Vector2(cx, head_center.y + 1), Vector2(cx, head_center.y + 5), skin.darkened(0.18), 1.0)
    draw_line(Vector2(cx - 3.5, head_center.y + 8), Vector2(cx + 3.5, head_center.y + 8), Color("7a4f45"), 1.0)

    if beard_style != "none":
        _draw_beard(head_center, skin, hair, beard_style)

    if has_glasses:
        var g = Color("101010")
        draw_rect(Rect2(cx - 7, head_center.y - 2, 5, 3), Color(0,0,0,0), false, 1.2)
        draw_rect(Rect2(cx + 2, head_center.y - 2, 5, 3), Color(0,0,0,0), false, 1.2)
        draw_line(Vector2(cx - 2, head_center.y - 0.5), Vector2(cx + 2, head_center.y - 0.5), g, 1.0)
        draw_line(Vector2(cx - 9, head_center.y - 1), Vector2(cx - 7, head_center.y - 1), g, 1.0)
        draw_line(Vector2(cx + 7, head_center.y - 1), Vector2(cx + 9, head_center.y - 1), g, 1.0)

func _draw_hair(head_center: Vector2, head_rx: float, head_ry: float, hair: Color, hair_style: String) -> void:
    var cx = head_center.x
    var cy = head_center.y
    match hair_style:
        "bald":
            return
        "buzz":
            draw_arc(head_center - Vector2(0, 2), head_rx, PI + 0.1, TAU - 0.1, 20, hair, 5.0)
        "short":
            draw_colored_polygon(PackedVector2Array([
                Vector2(cx - 10, cy - 1), Vector2(cx - 9, cy - 8), Vector2(cx - 4, cy - 12),
                Vector2(cx + 4, cy - 12), Vector2(cx + 9, cy - 8), Vector2(cx + 10, cy - 1),
                Vector2(cx + 4, cy - 5), Vector2(cx - 4, cy - 5)
            ]), hair)
        "medium":
            draw_colored_polygon(PackedVector2Array([
                Vector2(cx - 11, cy - 1), Vector2(cx - 10, cy - 10), Vector2(cx - 4, cy - 13),
                Vector2(cx + 5, cy - 12), Vector2(cx + 10, cy - 7), Vector2(cx + 10, cy + 2),
                Vector2(cx + 6, cy - 2), Vector2(cx - 6, cy - 2)
            ]), hair)
            draw_rect(Rect2(cx - 10, cy - 1, 2, 10), hair, true)
            draw_rect(Rect2(cx + 8, cy - 1, 2, 10), hair, true)
        "long":
            draw_colored_polygon(PackedVector2Array([
                Vector2(cx - 10, cy - 1), Vector2(cx - 10, cy - 11), Vector2(cx - 5, cy - 13),
                Vector2(cx + 5, cy - 13), Vector2(cx + 10, cy - 11), Vector2(cx + 10, cy - 1),
                Vector2(cx + 8, cy + 8), Vector2(cx - 8, cy + 8)
            ]), hair)
        "curly_long":
            for ix in range(-2, 3):
                draw_circle(Vector2(cx + ix * 4.0, cy - 9), 3.2, hair)
            for iy in range(0, 4):
                draw_circle(Vector2(cx - 10, cy - 2 + iy * 4.0), 2.8, hair)
                draw_circle(Vector2(cx + 10, cy - 2 + iy * 4.0), 2.8, hair)
            draw_circle(Vector2(cx - 6, cy + 10), 2.6, hair)
            draw_circle(Vector2(cx + 6, cy + 10), 2.6, hair)
        "shaggy":
            draw_colored_polygon(PackedVector2Array([
                Vector2(cx - 11, cy - 1), Vector2(cx - 9, cy - 10), Vector2(cx - 4, cy - 13),
                Vector2(cx + 1, cy - 12), Vector2(cx + 6, cy - 13), Vector2(cx + 10, cy - 8),
                Vector2(cx + 8, cy - 1), Vector2(cx + 2, cy - 3), Vector2(cx - 4, cy - 1)
            ]), hair)
        "mohawk":
            draw_colored_polygon(PackedVector2Array([
                Vector2(cx - 3, cy - 12), Vector2(cx + 3, cy - 12), Vector2(cx + 5, cy - 1), Vector2(cx - 5, cy - 1)
            ]), hair)
        "ponytail":
            draw_colored_polygon(PackedVector2Array([
                Vector2(cx - 10, cy - 1), Vector2(cx - 8, cy - 10), Vector2(cx - 3, cy - 13),
                Vector2(cx + 5, cy - 12), Vector2(cx + 10, cy - 7), Vector2(cx + 10, cy + 2),
                Vector2(cx + 7, cy + 3), Vector2(cx - 7, cy + 3)
            ]), hair)
            draw_rect(Rect2(cx + 7, cy + 3, 3, 10), hair, true)
            draw_circle(Vector2(cx + 8.5, cy + 14), 2.7, hair)
        "braids":
            draw_colored_polygon(PackedVector2Array([
                Vector2(cx - 9, cy - 1), Vector2(cx - 8, cy - 10), Vector2(cx - 3, cy - 12),
                Vector2(cx + 4, cy - 12), Vector2(cx + 9, cy - 8), Vector2(cx + 9, cy + 1),
                Vector2(cx - 8, cy + 1)
            ]), hair)
            draw_rect(Rect2(cx - 10, cy + 1, 2, 9), hair, true)
            draw_rect(Rect2(cx + 8, cy + 1, 2, 9), hair, true)
        _:
            draw_arc(head_center - Vector2(0, 2), head_rx, PI, TAU, 20, hair, 5.0)

func _draw_beard(head_center: Vector2, skin: Color, hair: Color, beard_style: String) -> void:
    var cx = head_center.x
    var cy = head_center.y
    match beard_style:
        "stubble":
            draw_arc(Vector2(cx, cy + 6), 5.0, 0.1, PI - 0.1, 12, hair.darkened(0.1), 1.3)
        "goatee":
            draw_line(Vector2(cx - 2.5, cy + 8), Vector2(cx + 2.5, cy + 8), hair, 1.3)
            draw_line(Vector2(cx, cy + 7), Vector2(cx, cy + 11), hair, 1.3)
            draw_arc(Vector2(cx, cy + 9), 2.5, 0.3, PI - 0.3, 10, hair, 1.3)
        "moustache":
            draw_line(Vector2(cx - 3.5, cy + 5.5), Vector2(cx + 3.5, cy + 5.5), hair, 1.3)
        _:
            pass

func _draw_ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
    var points := PackedVector2Array()
    for i in range(32):
        var angle = TAU * float(i) / 32.0
        points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
    draw_colored_polygon(points, color)
