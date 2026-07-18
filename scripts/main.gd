extends Control

const SAVE_PATH = "user://manager_2003_save.json"
const SEGMENTS = [15, 25, 35, 45, 55, 65, 75, 85, 90]
const MAX_SUBSTITUTIONS = 5
const MAX_POSITION_TRAININGS = 3
const SPECIALIST_POSITION_COST = 5000000
const MAX_CONTRACT_YEARS = 6
const MAX_CONTRACT_EXTENSION_YEARS = 6
const MAX_TOTAL_CONTRACT_YEARS = 12
const DEVELOPMENT_CHECK_ROUNDS = 3
const MAX_IMPORTANT_PLAYERS = 3
const MATCH_DAYS_STEP = 7
const MAX_INCOMING_OFFERS = 3
const TRANSFER_OFFER_COOLDOWN_ROUNDS = 2
const MAX_AI_SUBSTITUTIONS = 5
const CONDITION_MINIMUM = 35
const PROMOTION_RELEGATION_PLACES = 3
const POSITION_CODES = ["GK", "RB", "RWB", "LB", "LWB", "CB", "DM", "CM", "AM", "RM", "LM", "RW", "LW", "CF", "ST"]
const SPONSORS = {
    "stable": {"name": "North Star", "description": "Крупный аванс и спокойные бонусы", "upfront": 8000000, "win": 180000, "draw": 80000, "match": 60000, "champion": 2500000, "top3": 1000000},
    "results": {"name": "Victory Line", "description": "Меньше денег сразу, но высокие премии за победы", "upfront": 3000000, "win": 500000, "draw": 120000, "match": 0, "champion": 7000000, "top3": 3000000},
    "balanced": {"name": "Heritage Sport", "description": "Сбалансированный контракт на весь сезон", "upfront": 5000000, "win": 300000, "draw": 100000, "match": 40000, "champion": 4500000, "top3": 2000000}
}
const LEAGUE_PRIZES = [30000000, 20000000, 10000000, 7000000, 5000000, 3500000, 2500000, 1500000]

var database: Dictionary = {}
var teams_by_id: Dictionary = {}
var players_by_id: Dictionary = {}
var club_squads: Dictionary = {}
var player_club_index: Dictionary = {}
var statistics_cache: Dictionary = {}
var statistics_cache_revision = 0
var game_state: Dictionary = {}
var lineup: Dictionary = {}
var fixtures: Array = []
var league_table: Dictionary = {}
var current_match: Dictionary = {}
var player_stats: Dictionary = {}
var selected_team_id = -1
var selected_club_for_new_game = -1
var pitch_slots: Dictionary = {}
var screen_root: Control
var content_area: VBoxContainer
var rng = RandomNumberGenerator.new()
var notice_text = ""
var _cached_new_game_group: ButtonGroup
var selected_tactics_player_id = -1
var selected_substitution_player_id = -1
var formation_edit_mode = false
var selected_training_player_id = -1

var colors = {
    "bg": Color("07111c"),
    "panel": Color("0d1b29"),
    "panel_2": Color("12283a"),
    "cyan": Color("40e0ff"),
    "mint": Color("74f3c0"),
    "text": Color("e8f3f8"),
    "muted": Color("8ba2b0"),
    "danger": Color("ff7685"),
    "warning": Color("ffc857"),
    "pitch": Color("0d563f")
}

func _ready() -> void:
    rng.randomize()
    _load_database()
    _build_base()
    _show_main_menu()

func _load_database() -> void:
    var file = FileAccess.open("res://data/database.json", FileAccess.READ)
    if file == null:
        push_error("Не удалось открыть базу данных")
        return
    var parsed = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary:
        push_error("База данных повреждена")
        return
    database = parsed
    player_club_index.clear()
    statistics_cache.clear()
    for team in database.get("teams", []):
        var team_id = int(team.get("id", -1))
        teams_by_id[str(team_id)] = team
        club_squads[str(team_id)] = team.get("players", []).duplicate(true)
        for raw_player_id in team.get("players", []):
            player_club_index[str(int(raw_player_id))] = team_id
    for player in database.get("players", []):
        var prepared: Dictionary = player.duplicate(true)
        prepared["condition"] = int(prepared.get("condition", 100))
        prepared["morale"] = int(prepared.get("morale", 75))
        prepared["position"] = str(prepared.get("position", "")).strip_edges().to_upper()
        var normalized_secondary: Array = []
        for raw_position in prepared.get("secondary", []):
            var position = str(raw_position).strip_edges().to_upper()
            if not position.is_empty() and position != prepared["position"] and position not in normalized_secondary:
                normalized_secondary.append(position)
        prepared["secondary"] = normalized_secondary
        prepared["contract_years"] = int(prepared.get("contract_years", 2))
        prepared["wage_weekly"] = int(prepared.get("wage_weekly", max(1000, int(prepared.get("rating", 60)) * 250)))
        var legacy_injury_matches = int(prepared.get("injured_matches", 0))
        prepared["injury_days"] = int(prepared.get("injury_days", legacy_injury_matches * MATCH_DAYS_STEP))
        prepared["injured_matches"] = int(ceil(float(prepared["injury_days"]) / float(MATCH_DAYS_STEP)))
        prepared["injury_name"] = str(prepared.get("injury_name", ""))
        prepared["injury_details"] = str(prepared.get("injury_details", prepared.get("injury_name", "")))
        prepared["injury_severity"] = str(prepared.get("injury_severity", ""))
        prepared["injury_history"] = int(prepared.get("injury_history", 0))
        prepared["severe_injuries"] = int(prepared.get("severe_injuries", 0))
        prepared["suspended_matches"] = int(prepared.get("suspended_matches", 0))
        prepared["suspension_reason"] = str(prepared.get("suspension_reason", ""))
        prepared["development_points"] = float(prepared.get("development_points", 0.0))
        prepared["rating_changes_season"] = int(prepared.get("rating_changes_season", 0))
        prepared["last_rating_change_round"] = int(prepared.get("last_rating_change_round", -99))
        prepared["retired"] = bool(prepared.get("retired", false))
        prepared["career_avg_rating"] = float(prepared.get("career_avg_rating", 6.5))
        prepared["career_rating_apps"] = int(prepared.get("career_rating_apps", 0))
        prepared["career_club_stats"] = prepared.get("career_club_stats", {}) if prepared.get("career_club_stats", {}) is Dictionary else {}
        prepared["career_total_apps"] = int(prepared.get("career_total_apps", 0))
        prepared["career_total_goals"] = int(prepared.get("career_total_goals", 0))
        prepared["career_total_assists"] = int(prepared.get("career_total_assists", 0))
        prepared["career_total_clean_sheets"] = int(prepared.get("career_total_clean_sheets", 0))
        prepared["career_total_conceded"] = int(prepared.get("career_total_conceded", 0))
        players_by_id[str(int(prepared.get("id", -1)))] = prepared

func _build_base() -> void:
    var bg = ColorRect.new()
    bg.color = colors.bg
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(bg)

    screen_root = Control.new()
    screen_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(screen_root)

func _clear_screen() -> void:
    pitch_slots.clear()
    for child in screen_root.get_children():
        screen_root.remove_child(child)
        child.queue_free()

func _panel_style(bg_color: Color, border_color = Color.TRANSPARENT, radius = 10, border = 0) -> StyleBoxFlat:
    var box = StyleBoxFlat.new()
    box.bg_color = bg_color
    box.border_color = border_color
    box.set_corner_radius_all(radius)
    box.set_border_width_all(border)
    box.content_margin_left = 14
    box.content_margin_right = 14
    box.content_margin_top = 12
    box.content_margin_bottom = 12
    return box

func _button(text_value: String, primary = false) -> Button:
    var button = Button.new()
    button.text = text_value
    button.custom_minimum_size = Vector2(0, 42)
    button.add_theme_font_size_override("font_size", 14)
    var normal = _panel_style(colors.panel_2 if not primary else Color("11647a"), colors.cyan if primary else Color("26465b"), 8, 1)
    var hover = _panel_style(Color("17415a") if not primary else Color("16839a"), colors.cyan, 8, 1)
    var pressed = _panel_style(Color("0d3044"), colors.mint, 8, 1)
    var disabled = _panel_style(Color("14202a"), Color("22313b"), 8, 1)
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_stylebox_override("disabled", disabled)
    button.add_theme_color_override("font_color", colors.text)
    button.add_theme_color_override("font_disabled_color", Color("60717c"))
    return button

func _style_option_button(option: OptionButton, min_width = 160.0) -> void:
    option.custom_minimum_size = Vector2(min_width, 42)
    option.add_theme_font_size_override("font_size", 13)
    option.add_theme_color_override("font_color", colors.text)
    option.add_theme_color_override("font_hover_color", colors.text)
    option.add_theme_color_override("font_pressed_color", colors.text)
    option.add_theme_stylebox_override("normal", _panel_style(Color("102434"), Color("31566b"), 8, 1))
    option.add_theme_stylebox_override("hover", _panel_style(Color("16364a"), colors.cyan, 8, 1))
    option.add_theme_stylebox_override("pressed", _panel_style(Color("0e2d40"), colors.mint, 8, 1))
    var popup = option.get_popup()
    popup.add_theme_font_size_override("font_size", 13)
    popup.add_theme_color_override("font_color", colors.text)
    popup.add_theme_color_override("font_hover_color", Color("07111c"))
    popup.add_theme_stylebox_override("panel", _panel_style(Color("102434"), Color("31566b"), 6, 1))
    popup.add_theme_stylebox_override("hover", _panel_style(colors.mint, colors.mint, 4, 0))

func _label(text_value: String, size = 14, color: Color = Color.WHITE) -> Label:
    var label = Label.new()
    label.text = text_value
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    return label

func _title(text_value: String) -> Label:
    var label = _label(text_value, 28, colors.text)
    label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
    label.add_theme_constant_override("shadow_offset_x", 2)
    label.add_theme_constant_override("shadow_offset_y", 2)
    return label

func _show_main_menu() -> void:
    _clear_screen()
    var center = CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    screen_root.add_child(center)

    var card = PanelContainer.new()
    card.custom_minimum_size = Vector2(520, 500)
    card.add_theme_stylebox_override("panel", _panel_style(Color("0c1b2a"), Color("1d6075"), 16, 1))
    center.add_child(card)

    var box = VBoxContainer.new()
    box.add_theme_constant_override("separation", 14)
    card.add_child(box)

    var era = _label("СЕЗОН 2003 / 2004", 15, colors.mint)
    era.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(era)

    var heading = _title("ФУТБОЛЬНЫЙ МЕНЕДЖЕР 2003")
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(heading)

    var subtitle = _label("Текстовая карьера · тактика · трансферы · пошаговый матч", 14, colors.muted)
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(subtitle)

    var spacer = Control.new()
    spacer.custom_minimum_size = Vector2(0, 20)
    box.add_child(spacer)

    var new_game = _button("НОВАЯ КАРЬЕРА", true)
    new_game.pressed.connect(_show_new_game)
    box.add_child(new_game)

    var continue_game = _button("ПРОДОЛЖИТЬ")
    continue_game.disabled = not FileAccess.file_exists(SAVE_PATH)
    continue_game.pressed.connect(_load_game)
    box.add_child(continue_game)

    var about = _button("О ПРОТОТИПЕ")
    about.pressed.connect(_show_about)
    box.add_child(about)

    var exit = _button("ВЫХОД")
    exit.pressed.connect(get_tree().quit)
    box.add_child(exit)

    var version = _label("Версия v1.1.0 · Godot 4", 12, colors.muted)
    version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(version)

func _show_about() -> void:
    var dialog = AcceptDialog.new()
    dialog.title = "О прототипе"
    dialog.dialog_text = "Версия с дисквалификациями, травмами в днях, трансферными предложениями, исполнителями стандартов, динамическими ролями свободной схемы и расширенной статистикой матчей.\n\nУже реализованы: выбор клуба, состав, ручная расстановка с перетаскиванием, четыре схемы, текстовый матч по отрезкам, замены, таблица, календарь, простые трансферы и сохранение.\n\nВ демонстрационной базе четыре английских клуба и расширенные составы сезона 2003/04. Полная база 12 дивизионов будет подключаться после проверки механики."
    dialog.min_size = Vector2i(600, 320)
    add_child(dialog)
    dialog.popup_centered()

func _show_new_game() -> void:
    _clear_screen()
    selected_club_for_new_game = -1

    var margin = MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 70)
    margin.add_theme_constant_override("margin_right", 70)
    margin.add_theme_constant_override("margin_top", 35)
    margin.add_theme_constant_override("margin_bottom", 35)
    screen_root.add_child(margin)

    var scroll = ScrollContainer.new()
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    margin.add_child(scroll)
    var root = VBoxContainer.new()
    root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    root.add_theme_constant_override("separation", 14)
    scroll.add_child(root)

    root.add_child(_title("Новая карьера"))
    root.add_child(_label("Выберите страну, дивизион и клуб сезона 2003/04.", 14, colors.muted))

    var select_panel = PanelContainer.new()
    select_panel.add_theme_stylebox_override("panel", _panel_style(colors.panel, Color("19384b"), 12, 1))
    root.add_child(select_panel)
    var select_box = VBoxContainer.new()
    select_box.add_theme_constant_override("separation", 10)
    select_panel.add_child(select_box)

    var country_option = OptionButton.new()
    var countries: Array = []
    for league in database.get("leagues", []):
        var country = str(league.get("country", ""))
        if not country.is_empty() and country not in countries:
            countries.append(country)
    countries.sort()
    for country in countries:
        country_option.add_item(country)
        country_option.set_item_metadata(country_option.item_count - 1, country)
    _style_option_button(country_option, 520)
    select_box.add_child(_label("Страна", 14, colors.mint))
    select_box.add_child(country_option)

    var league_option = OptionButton.new()
    _style_option_button(league_option, 520)
    select_box.add_child(_label("Лига", 14, colors.mint))
    select_box.add_child(league_option)

    var club_option = OptionButton.new()
    _style_option_button(club_option, 520)
    select_box.add_child(_label("Клуб", 14, colors.mint))
    select_box.add_child(club_option)

    var selected_info = _label("", 14, colors.warning)
    selected_info.name = "SelectedClubInfo"
    select_box.add_child(selected_info)

    var sponsor_panel = PanelContainer.new()
    sponsor_panel.add_theme_stylebox_override("panel", _panel_style(Color("0d1f2d"), Color("24485c"), 10, 1))
    root.add_child(sponsor_panel)
    var sponsor_box = VBoxContainer.new()
    sponsor_box.add_theme_constant_override("separation", 8)
    sponsor_panel.add_child(sponsor_box)
    sponsor_box.add_child(_label("Спонсорский контракт", 18, colors.text))
    var sponsor_option = OptionButton.new()
    for sponsor_id in SPONSORS.keys():
        var sponsor: Dictionary = SPONSORS[sponsor_id]
        sponsor_option.add_item("%s — %s · аванс %s" % [sponsor.get("name", "Спонсор"), sponsor.get("description", ""), _money(int(sponsor.get("upfront", 0)))])
        sponsor_option.set_item_metadata(sponsor_option.item_count - 1, sponsor_id)
    sponsor_option.select(2 if sponsor_option.item_count > 2 else 0)
    _style_option_button(sponsor_option, 620)
    sponsor_box.add_child(sponsor_option)

    var options = HBoxContainer.new()
    options.add_theme_constant_override("separation", 14)
    root.add_child(options)
    options.add_child(_label("Продолжительность карьеры:", 15, colors.text))
    var season_option = OptionButton.new()
    season_option.add_item("2 сезона", 2)
    season_option.add_item("3 сезона", 3)
    season_option.select(1)
    _style_option_button(season_option, 180)
    options.add_child(season_option)

    var buttons = HBoxContainer.new()
    buttons.add_theme_constant_override("separation", 12)
    root.add_child(buttons)
    var back = _button("НАЗАД")
    back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    back.pressed.connect(_show_main_menu)
    buttons.add_child(back)
    var start = _button("НАЧАТЬ КАРЬЕРУ", true)
    start.name = "StartCareerButton"
    start.disabled = true
    start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    start.pressed.connect(_start_new_game.bind(season_option, sponsor_option))
    buttons.add_child(start)

    country_option.item_selected.connect(_new_game_country_changed.bind(country_option, league_option, club_option, start, selected_info))
    league_option.item_selected.connect(_new_game_league_changed.bind(league_option, club_option, start, selected_info))
    club_option.item_selected.connect(_new_game_club_changed.bind(club_option, start, selected_info))
    if country_option.item_count > 0:
        country_option.select(0)
        _populate_new_game_leagues(str(country_option.get_item_metadata(0)), league_option, club_option, start, selected_info)

func _populate_new_game_leagues(country: String, league_option: OptionButton, club_option: OptionButton, start: Button, info: Label) -> void:
    league_option.clear()
    for league in database.get("leagues", []):
        if str(league.get("country", "")) != country:
            continue
        league_option.add_item(str(league.get("name", "Лига")))
        league_option.set_item_metadata(league_option.item_count - 1, str(league.get("id", "")))
    if league_option.item_count > 0:
        league_option.select(0)
        _populate_new_game_clubs(str(league_option.get_item_metadata(0)), club_option, start, info)

func _populate_new_game_clubs(competition_id: String, club_option: OptionButton, start: Button, info: Label) -> void:
    club_option.clear()
    var clubs: Array = []
    for team in database.get("teams", []):
        if str(team.get("competition", "")) == competition_id and bool(team.get("playable", false)):
            clubs.append(team)
    clubs.sort_custom(func(a, b): return int(a.get("rank_seed", 999)) < int(b.get("rank_seed", 999)))
    for team in clubs:
        club_option.add_item("%s · бюджет %s · сила %d" % [team.get("name", "Клуб"), _money(int(team.get("budget", 0))), _team_base_rating(int(team.get("id", -1)))])
        club_option.set_item_metadata(club_option.item_count - 1, int(team.get("id", -1)))
    selected_club_for_new_game = -1
    start.disabled = true
    info.text = ""
    if club_option.item_count > 0:
        club_option.select(0)
        _new_game_club_changed(0, club_option, start, info)

func _new_game_country_changed(index: int, country_option: OptionButton, league_option: OptionButton, club_option: OptionButton, start: Button, info: Label) -> void:
    _populate_new_game_leagues(str(country_option.get_item_metadata(index)), league_option, club_option, start, info)

func _new_game_league_changed(index: int, league_option: OptionButton, club_option: OptionButton, start: Button, info: Label) -> void:
    _populate_new_game_clubs(str(league_option.get_item_metadata(index)), club_option, start, info)

func _new_game_club_changed(index: int, club_option: OptionButton, start: Button, info: Label) -> void:
    if index < 0 or index >= club_option.item_count:
        selected_club_for_new_game = -1
        start.disabled = true
        return
    selected_club_for_new_game = int(club_option.get_item_metadata(index))
    start.disabled = selected_club_for_new_game < 0
    var team = _team(selected_club_for_new_game)
    info.text = "Выбран: %s · %s · тренер: %s" % [team.get("name", "Клуб"), team.get("league_name", "Лига"), team.get("coach_name", "штаб 2003/04")]

func _new_game_button_group() -> ButtonGroup:
    if _cached_new_game_group == null:
        _cached_new_game_group = ButtonGroup.new()
    return _cached_new_game_group

func _select_new_club(team_id: int, _button_ref: Button) -> void:
    selected_club_for_new_game = team_id
    var start = screen_root.find_child("StartCareerButton", true, false) as Button
    if start:
        start.disabled = false

func _start_new_game(season_option: OptionButton, sponsor_option: OptionButton) -> void:
    if selected_club_for_new_game < 0:
        return
    var chosen_team_id = selected_club_for_new_game
    teams_by_id.clear()
    players_by_id.clear()
    club_squads.clear()
    _load_database()
    selected_team_id = chosen_team_id
    var team = _team(selected_team_id)
    var sponsor_id = str(sponsor_option.get_item_metadata(sponsor_option.selected))
    if not SPONSORS.has(sponsor_id):
        sponsor_id = "balanced"
    var sponsor: Dictionary = SPONSORS[sponsor_id]
    game_state = {
        "team_id": selected_team_id,
        "season": 1,
        "seasons_total": season_option.get_selected_id(),
        "budget": int(team.get("budget", 0)) + int(sponsor.get("upfront", 0)),
        "formation": str(team.get("coach_formation", "4-4-2")),
        "tactical_style": str(team.get("coach_style", "Сбалансированно")),
        "fullback_duty": "Поддержка",
        "lineup_confirmed": true,
        "market_ids": database.get("market_players", []).duplicate(true),
        "transfer_search": "",
        "academy_promotions": [],
        "career_wins": 0,
        "career_draws": 0,
        "career_losses": 0,
        "career_gf": 0,
        "career_ga": 0,
        "position_training": {},
        "custom_positions": {},
        "custom_roles": {},
        "sponsor_id": sponsor_id,
        "sponsor_income": int(sponsor.get("upfront", 0)),
        "season_sponsor_income": int(sponsor.get("upfront", 0)),
        "prize_income": 0,
        "season_awards_paid": [],
        "season_award_amounts": {},
        "loans_out": {},
        "ai_loans": {},
        "ai_budgets": _initial_ai_budgets(),
        "ai_window_actions": {},
        "retired_players": [],
        "development_round": 0,
        "winter_window_processed": false,
        "world_leagues": {},
        "selected_world_competition": "eng1_demo",
        "important_players": [],
        "set_piece_takers": {},
        "transfer_listed": [],
        "incoming_offers": [],
        "transfer_offer_history": [],
        "last_transfer_offer_round": -99,
        "cups": {},
        "trophies": [],
        "promotion_history": [],
        "last_season_place": 0,
        "data_revision": 0
    }
    current_match = {}
    lineup = _auto_pick_lineup(str(team.get("coach_formation", "4-4-2")))
    _ensure_set_piece_assignments()
    _reset_player_stats()
    _start_season()
    notice_text = "Контракт с %s подписан. Аванс %s уже поступил в бюджет." % [sponsor.get("name", "спонсором"), _money(int(sponsor.get("upfront", 0)))]
    _show_dashboard("club")

func _start_season() -> void:
    var user_team = _team(selected_team_id)
    var user_competition = str(user_team.get("competition", "eng1_demo"))
    var world: Dictionary = {}
    var competition_ids: Array = []
    for team in database.get("teams", []):
        var comp = str(team.get("competition", ""))
        if not comp.is_empty() and comp not in competition_ids:
            competition_ids.append(comp)
    for competition_id in competition_ids:
        var ids = _competition_team_ids(str(competition_id))
        var comp_fixtures = _generate_fixtures(ids)
        var comp_table: Dictionary = {}
        for id in ids:
            comp_table[str(id)] = {"p": 0, "w": 0, "d": 0, "l": 0, "gf": 0, "ga": 0, "pts": 0}
        world[str(competition_id)] = {"fixtures": comp_fixtures, "table": comp_table, "round_simulated": 0}
    game_state["world_leagues"] = world
    game_state["selected_world_competition"] = user_competition
    var user_state: Dictionary = world.get(user_competition, {})
    fixtures = user_state.get("fixtures", []).duplicate(true)
    league_table = user_state.get("table", {}).duplicate(true)
    game_state["winter_window_processed"] = false
    _clean_important_players()
    _clean_transfer_list()
    _ensure_set_piece_assignments()
    _ensure_player_stats()
    _initialize_cup_competitions()
    _process_ai_transfer_window("summer")

func _show_dashboard(tab: String) -> void:
    if tab != "tactics":
        selected_tactics_player_id = -1
        formation_edit_mode = false
    _clear_screen()
    var root = VBoxContainer.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_theme_constant_override("separation", 0)
    screen_root.add_child(root)

    var header = PanelContainer.new()
    header.custom_minimum_size = Vector2(0, 78)
    header.add_theme_stylebox_override("panel", _panel_style(Color("0b1a28"), Color("1c5065"), 0, 0))
    root.add_child(header)
    var head_box = HBoxContainer.new()
    head_box.add_theme_constant_override("separation", 18)
    header.add_child(head_box)

    var team = _team(selected_team_id)
    var head_title = _label(str(team.get("name", "Клуб")), 24, colors.text)
    head_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    head_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    head_box.add_child(head_title)
    head_box.add_child(_label("Сезон %d/%d" % [int(game_state.get("season", 1)), int(game_state.get("seasons_total", 3))], 14, colors.mint))
    head_box.add_child(_label("Бюджет: %s" % _money(int(game_state.get("budget", 0))), 14, colors.cyan))
    var menu = _button("ГЛАВНОЕ МЕНЮ")
    menu.custom_minimum_size.x = 160
    menu.pressed.connect(_show_main_menu)
    head_box.add_child(menu)

    var body = HBoxContainer.new()
    body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(body)

    var nav_panel = PanelContainer.new()
    nav_panel.custom_minimum_size = Vector2(215, 0)
    nav_panel.add_theme_stylebox_override("panel", _panel_style(Color("091621"), Color("18354a"), 0, 0))
    body.add_child(nav_panel)
    var nav = VBoxContainer.new()
    nav.add_theme_constant_override("separation", 9)
    nav_panel.add_child(nav)

    var nav_items = [
        ["club", "СОСТАВ"], ["reserve", "РЕЗЕРВ"], ["academy", "АКАДЕМИЯ"], ["tactics", "ТАКТИКА"], ["match", "МАТЧ"],
        ["calendar", "КАЛЕНДАРЬ"], ["table", "ТАБЛИЦА"], ["statistics", "СТАТИСТИКА"],
        ["training", "ТРЕНИРОВКИ"], ["finances", "ФИНАНСЫ"], ["transfers", "ТРАНСФЕРЫ"],
        ["tournaments", "ТУРНИРЫ"], ["other_leagues", "ДРУГИЕ ЛИГИ"]
    ]
    for item in nav_items:
        var nav_button = _button(item[1], item[0] == tab)
        nav_button.pressed.connect(_show_dashboard.bind(item[0]))
        nav.add_child(nav_button)
    var stretch = Control.new()
    stretch.size_flags_vertical = Control.SIZE_EXPAND_FILL
    nav.add_child(stretch)
    var save = _button("СОХРАНИТЬ")
    save.pressed.connect(_save_game)
    nav.add_child(save)

    # Вся рабочая область находится в ScrollContainer. При небольшом окне
    # элементы больше не вылезают за правый и нижний край.
    var main_scroll = ScrollContainer.new()
    main_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    main_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body.add_child(main_scroll)

    var main_margin = MarginContainer.new()
    main_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    main_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
    main_margin.add_theme_constant_override("margin_left", 22)
    main_margin.add_theme_constant_override("margin_right", 22)
    main_margin.add_theme_constant_override("margin_top", 18)
    main_margin.add_theme_constant_override("margin_bottom", 18)
    main_scroll.add_child(main_margin)

    content_area = VBoxContainer.new()
    content_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content_area.add_theme_constant_override("separation", 12)
    main_margin.add_child(content_area)

    if not notice_text.is_empty():
        var notice = PanelContainer.new()
        notice.add_theme_stylebox_override("panel", _panel_style(Color("173549"), colors.cyan, 8, 1))
        var notice_label = _label(notice_text, 13, colors.text)
        notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        notice.add_child(notice_label)
        content_area.add_child(notice)
        notice_text = ""

    match tab:
        "club": _render_club()
        "reserve": _render_reserve()
        "academy": _render_academy()
        "tactics": _render_tactics()
        "match": _render_match()
        "calendar": _render_calendar()
        "table": _render_table()
        "statistics": _render_statistics()
        "training": _render_training()
        "finances": _render_finances()
        "transfers": _render_transfers()
        "tournaments": _render_tournaments()
        "other_leagues": _render_other_leagues()

func _render_club() -> void:
    content_area.add_child(_title("Состав команды"))
    var team = _team(selected_team_id)
    var coach_panel = PanelContainer.new()
    coach_panel.add_theme_stylebox_override("panel", _panel_style(Color("10283a"), Color("245269"), 8, 1))
    var coach_box = HFlowContainer.new()
    coach_box.add_theme_constant_override("h_separation", 18)
    coach_box.add_theme_constant_override("v_separation", 6)
    coach_panel.add_child(coach_box)
    coach_box.add_child(_label("Тренер сезона 2003/04: %s" % team.get("coach_name", "не указан"), 14, colors.mint))
    coach_box.add_child(_label("Базовая схема: %s" % team.get("coach_formation", "4-4-2"), 14, colors.cyan))
    coach_box.add_child(_label("Почерк: %s" % team.get("coach_style", "Сбалансированно"), 14, colors.warning))
    content_area.add_child(coach_panel)
    var info = _label("Нажмите имя футболиста, чтобы открыть карточку: позиции, форма, травмы, развитие, продажа, аренда и контракт.", 13, colors.muted)
    info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content_area.add_child(info)

    var header = HBoxContainer.new()
    header.add_theme_constant_override("separation", 8)
    for item in [["Игрок", 250], ["Осн.", 55], ["Дополнительные", 150], ["Возраст", 62], ["Рейт.", 62], ["Состояние", 150], ["Контракт", 85], ["Цена", 100]]:
        var l = _label(item[0], 12, colors.mint)
        l.custom_minimum_size.x = item[1]
        header.add_child(l)
    content_area.add_child(header)

    var scroll = ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content_area.add_child(scroll)
    var list = VBoxContainer.new()
    list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    list.add_theme_constant_override("separation", 5)
    scroll.add_child(list)

    var squad = _squad_level_ids(selected_team_id, "first")
    squad.sort_custom(func(a, b): return int(_player(a).get("rating", 0)) > int(_player(b).get("rating", 0)))
    for player_id in squad:
        var player = _player(int(player_id))
        var secondary: Array = player.get("secondary", [])
        var injured = _is_player_injured(player)
        var suspended = _is_player_suspended(player)
        var state_text = _player_availability_text(player)
        var state_color = colors.danger if injured else (colors.warning if suspended else colors.mint)
        var row = PanelContainer.new()
        row.add_theme_stylebox_override("panel", _panel_style(Color("26161b") if injured else (Color("2a2412") if suspended else Color("0d1f2d")), state_color if injured or suspended else Color("193447"), 6, 1))
        var h = HBoxContainer.new()
        h.add_theme_constant_override("separation", 8)
        row.add_child(h)
        var star = "★ " if _is_important_player(int(player_id)) else ""
        h.add_child(_player_link_button(int(player_id), star + str(player.get("name", "Игрок")), 250))
        var values = [
            [player.get("position", "?"), 55, colors.cyan],
            [", ".join(secondary) if not secondary.is_empty() else "—", 150, colors.muted],
            [str(player.get("age", "?")), 62, colors.text],
            [str(player.get("rating", 0)), 62, colors.warning if int(player.get("rating", 0)) >= 85 else colors.text],
            [state_text, 190, state_color],
            ["%d г." % int(player.get("contract_years", 1)), 85, colors.warning if int(player.get("contract_years", 1)) <= 1 else colors.text],
            [_money(int(player.get("value", 0))), 100, colors.muted]
        ]
        for value in values:
            var l = _label(str(value[0]), 13, value[2])
            l.custom_minimum_size.x = value[1]
            l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
            h.add_child(l)
        list.add_child(row)

    var loans: Dictionary = game_state.get("loans_out", {})
    if not loans.is_empty():
        content_area.add_child(_label("В аренде", 18, colors.mint))
        for key in loans.keys():
            var loan: Dictionary = loans[key]
            content_area.add_child(_label("%s — вернётся к сезону %d" % [_player(int(key)).get("name", "Игрок"), int(loan.get("return_season", 2))], 13, colors.muted))

func _render_tactics() -> void:
    _sanitize_lineup()
    game_state["lineup_confirmed"] = _lineup_is_valid()

    var top = HFlowContainer.new()
    top.add_theme_constant_override("h_separation", 10)
    top.add_theme_constant_override("v_separation", 8)
    var title = _title("Тактика и стартовый состав")
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top.add_child(title)
    var auto = _button("АВТОСОСТАВ")
    auto.pressed.connect(_auto_lineup_pressed)
    top.add_child(auto)
    var edit_positions = _button("ЗАВЕРШИТЬ РЕДАКТОР" if formation_edit_mode else "СВОБОДНАЯ СХЕМА", formation_edit_mode)
    edit_positions.pressed.connect(_toggle_formation_editor)
    top.add_child(edit_positions)
    var reset_positions = _button("СБРОСИТЬ ПОЗИЦИИ")
    reset_positions.pressed.connect(_reset_custom_positions)
    top.add_child(reset_positions)
    var confirm_text = "ПРИМЕНИТЬ ТАКТИКУ И ВЕРНУТЬСЯ" if not current_match.is_empty() else "ПОДТВЕРДИТЬ И К МАТЧУ"
    var confirm = _button(confirm_text, true)
    confirm.pressed.connect(_confirm_starting_lineup)
    top.add_child(confirm)
    content_area.add_child(top)

    var controls = HFlowContainer.new()
    controls.add_theme_constant_override("h_separation", 12)
    controls.add_theme_constant_override("v_separation", 8)
    content_area.add_child(controls)
    controls.add_child(_label("Схема:", 14, colors.text))
    var formation_option = OptionButton.new()
    for name in _formations().keys():
        formation_option.add_item(name)
    var current_formation = str(game_state.get("formation", "4-4-2"))
    formation_option.select(max(0, Array(_formations().keys()).find(current_formation)))
    formation_option.item_selected.connect(_formation_selected.bind(formation_option))
    _style_option_button(formation_option, 175)
    controls.add_child(formation_option)

    controls.add_child(_label("Крайние защитники:", 14, colors.text))
    var fullback_option = OptionButton.new()
    var fullback_roles = ["Оборона", "Поддержка", "Атака"]
    for role in fullback_roles:
        fullback_option.add_item(role)
    fullback_option.select(max(0, fullback_roles.find(str(game_state.get("fullback_duty", "Поддержка")))))
    fullback_option.item_selected.connect(_fullback_duty_selected.bind(fullback_option))
    _style_option_button(fullback_option, 155)
    controls.add_child(fullback_option)

    controls.add_child(_label("Стиль:", 14, colors.text))
    var style_option = OptionButton.new()
    var styles = ["Сбалансированно", "Атака", "Оборона", "Прессинг", "Контратака", "Глубокая оборона + контратака"]
    for style in styles:
        style_option.add_item(style)
    style_option.select(max(0, styles.find(str(game_state.get("tactical_style", "Сбалансированно")))))
    style_option.item_selected.connect(_style_selected.bind(style_option))
    _style_option_button(style_option, 190)
    controls.add_child(style_option)

    var power = _label("Сила состава: %d" % int(_user_team_power()), 14, colors.mint)
    power.name = "PowerLabel"
    controls.add_child(power)
    var validation = _lineup_validation()
    var ready = bool(validation.get("valid", false))
    var ready_text = "Тактическая перестройка готова — можно продолжать матч" if not current_match.is_empty() else "Состав готов — можно начинать матч"
    controls.add_child(_label(ready_text if ready else str(validation.get("reason", "Состав неполный")), 13, colors.mint if ready else colors.warning))

    var help_panel = PanelContainer.new()
    help_panel.add_theme_stylebox_override("panel", _panel_style(Color("10283a"), Color("245269"), 8, 1))
    var help_text = "РЕДАКТОР СХЕМЫ ВКЛЮЧЁН: двигайте позиции по полю. Роль меняется автоматически по зоне: например, справа высоко будет RW, а в центре глубоко — DM." if formation_edit_mode else "Зажмите карточку запасного и бросьте на поле. Код сверху карточки показывает именно роль в схеме, а не родную позицию игрока."
    if not current_match.is_empty() and _sent_off_count(selected_team_id) > 0:
        help_text += " После удаления пустая позиция допустима: переставьте оставшихся игроков, примените тактику и продолжайте матч в меньшинстве."
    var help = _label(help_text, 13, colors.text)
    help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    help_panel.add_child(help)
    content_area.add_child(help_panel)
    _render_set_piece_assignments()

    var split: BoxContainer
    var compact_layout = get_viewport_rect().size.x < 1320.0
    if compact_layout:
        split = VBoxContainer.new()
    else:
        split = HBoxContainer.new()
    split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    split.size_flags_vertical = Control.SIZE_EXPAND_FILL
    split.add_theme_constant_override("separation", 14)
    content_area.add_child(split)

    var bench_panel = PanelContainer.new()
    bench_panel.custom_minimum_size = Vector2(0, 330) if compact_layout else Vector2(335, 520)
    bench_panel.add_theme_stylebox_override("panel", _panel_style(colors.panel, Color("1a3e52"), 10, 1))
    split.add_child(bench_panel)
    var bench_box = VBoxContainer.new()
    bench_box.add_theme_constant_override("separation", 8)
    bench_panel.add_child(bench_box)
    bench_box.add_child(_label("Скамейка основной команды", 18, colors.text))
    bench_box.add_child(_label("Тяните карточку на поле — необязательно попадать точно в маленькую ячейку.", 12, colors.muted))

    var bench_scroll = ScrollContainer.new()
    bench_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    bench_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    bench_box.add_child(bench_scroll)
    var bench_list = VBoxContainer.new()
    bench_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    bench_list.add_theme_constant_override("separation", 6)
    bench_scroll.add_child(bench_list)

    var sorted_squad = _match_squad(selected_team_id)
    sorted_squad.sort_custom(func(a, b): return int(_player(a).get("rating", 0)) > int(_player(b).get("rating", 0)))
    var bench_count = 0
    for player_id in sorted_squad:
        if int(player_id) in lineup.values():
            continue
        bench_count += 1
        var token = PlayerToken.new()
        token.setup(_player(int(player_id)))
        token.player_selected.connect(_select_tactics_player)
        bench_list.add_child(token)
    if bench_count == 0:
        bench_list.add_child(_label("Все футболисты находятся на поле.", 13, colors.muted))

    var pitch_panel = PanelContainer.new()
    pitch_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    pitch_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    pitch_panel.custom_minimum_size = Vector2(650, 520)
    pitch_panel.add_theme_stylebox_override("panel", _panel_style(Color("081a22"), Color("1b4c58"), 10, 1))
    split.add_child(pitch_panel)
    var pitch = TacticsPitch.new()
    pitch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    pitch.size_flags_vertical = Control.SIZE_EXPAND_FILL
    pitch_panel.add_child(pitch)
    pitch.resized.connect(_layout_pitch_slots.bind(pitch))
    pitch.player_dropped_on_pitch.connect(_player_dropped_on_pitch)
    _create_pitch_slots(pitch)
    _layout_pitch_slots.call_deferred(pitch)

func _create_pitch_slots(pitch: TacticsPitch) -> void:
    pitch_slots.clear()
    var formation_name = str(game_state.get("formation", "4-4-2"))
    for raw_slot_data in _formations().get(formation_name, []):
        var slot_data = _dynamic_slot_data(raw_slot_data)
        var slot = PositionSlot.new()
        slot.setup(slot_data)
        slot.set_editor_mode(formation_edit_mode)
        slot.player_dropped.connect(_player_dropped)
        slot.slot_pressed.connect(_tactics_slot_clicked)
        slot.slot_moved.connect(_formation_slot_moved)
        pitch.add_child(slot)
        pitch_slots[str(slot_data.get("id", ""))] = slot
        var player_id = int(lineup.get(str(slot_data.get("id", "")), -1))
        if player_id >= 0:
            var player = _player(player_id)
            slot.set_player(player, _effective_rating_for_slot(player, slot_data.get("accepted", [])), _fit_description(player, slot_data.get("accepted", [])))
        else:
            slot.set_player({})

func _layout_pitch_slots(pitch: TacticsPitch) -> void:
    if not is_instance_valid(pitch) or not pitch.is_inside_tree():
        return
    var formation_name = str(game_state.get("formation", "4-4-2"))
    for slot_data in _formations().get(formation_name, []):
        var slot_id = str(slot_data.get("id", ""))
        var slot = pitch_slots.get(slot_id) as PositionSlot
        if slot == null:
            continue
        var coords = _slot_coordinates(slot_data)
        var card_size = slot.custom_minimum_size
        var x = coords.x * pitch.size.x - card_size.x / 2.0
        var y = coords.y * pitch.size.y - card_size.y / 2.0
        slot.position = Vector2(
            clamp(x, 5.0, max(5.0, pitch.size.x - card_size.x - 5.0)),
            clamp(y, 5.0, max(5.0, pitch.size.y - card_size.y - 5.0))
        )

func _player_dropped_on_pitch(player_id: int, local_position: Vector2) -> void:
    if formation_edit_mode:
        return
    if pitch_slots.is_empty():
        return
    var nearest_slot_id = ""
    var nearest_distance = INF
    for slot_id in pitch_slots.keys():
        var slot = pitch_slots[slot_id] as PositionSlot
        if slot == null:
            continue
        var center = slot.position + slot.size / 2.0
        var distance = center.distance_squared_to(local_position)
        if distance < nearest_distance:
            nearest_distance = distance
            nearest_slot_id = str(slot_id)
    if not nearest_slot_id.is_empty():
        _player_dropped(player_id, nearest_slot_id)

func _player_dropped(player_id: int, target_slot_id: String) -> void:
    if player_id < 0 or not _squad_has_player(selected_team_id, player_id):
        return
    var target_slot = _formation_slot(target_slot_id)
    var target_is_goalkeeper = "GK" in target_slot.get("accepted", [])
    if target_is_goalkeeper and not _is_goalkeeper(_player(player_id)):
        selected_tactics_player_id = -1
        notice_text = "На позицию ВР можно поставить только вратаря."
        _show_dashboard("tactics")
        return
    if not target_is_goalkeeper and _is_goalkeeper(_player(player_id)):
        selected_tactics_player_id = -1
        notice_text = "Вратаря нельзя перетащить на полевую позицию."
        _show_dashboard("tactics")
        return
    if not current_match.is_empty() and player_id not in lineup.values():
        selected_tactics_player_id = -1
        notice_text = "Во время матча запасной выходит только через кнопку «Замена»."
        _show_dashboard("tactics")
        return

    var source_slot = ""
    for key in lineup.keys():
        if int(lineup.get(key, -1)) == player_id:
            source_slot = str(key)
            break
    var target_player = int(lineup.get(target_slot_id, -1))

    if source_slot == target_slot_id:
        selected_tactics_player_id = -1
        return

    lineup[target_slot_id] = player_id
    if not source_slot.is_empty():
        if target_player >= 0 and target_player != player_id:
            lineup[source_slot] = target_player
        else:
            lineup.erase(source_slot)

    _sanitize_lineup()
    game_state["lineup_confirmed"] = _lineup_is_valid()
    selected_tactics_player_id = -1
    notice_text = "%s перемещён. Состав сохранён автоматически." % _player(player_id).get("name", "Игрок")
    call_deferred("_show_dashboard", "tactics")

func _lineup_validation() -> Dictionary:
    if not current_match.is_empty():
        return _live_lineup_validation()
    var slots: Array = _formations().get(str(game_state.get("formation", "4-4-2")), [])
    if slots.size() != 11:
        return {"valid": false, "reason": "В выбранной схеме должно быть ровно 11 позиций."}
    var used: Dictionary = {}
    for raw_slot in slots:
        var slot = _dynamic_slot_data(raw_slot)
        var slot_id = str(slot.get("id", ""))
        var player_id = int(lineup.get(slot_id, -1))
        if player_id < 0:
            return {"valid": false, "reason": "Позиция %s пока пустая." % str(slot.get("label", slot_id))}
        if not _squad_has_player(selected_team_id, player_id) or _player(player_id).is_empty():
            return {"valid": false, "reason": "В составе найден футболист, которого уже нет в клубе."}
        var availability_player = _player(player_id)
        if _is_player_injured(availability_player):
            return {"valid": false, "reason": "%s травмирован: %s." % [availability_player.get("name", "Игрок"), _injury_recovery_text(availability_player)]}
        if _is_player_suspended(availability_player):
            return {"valid": false, "reason": "%s дисквалифицирован ещё на %d матч(а)." % [availability_player.get("name", "Игрок"), int(availability_player.get("suspended_matches", 0))]}
        var key = str(player_id)
        if used.has(key):
            return {"valid": false, "reason": "%s выбран в стартовом составе дважды." % _player(player_id).get("name", "Игрок")}
        used[key] = true
        if "GK" in slot.get("accepted", []) and not _is_goalkeeper(_player(player_id)):
            return {"valid": false, "reason": "В ячейке GK должен стоять вратарь."}
        if "GK" not in slot.get("accepted", []) and _is_goalkeeper(_player(player_id)):
            return {"valid": false, "reason": "Вратарь не может играть в поле."}
    if used.size() != 11:
        return {"valid": false, "reason": "Нужны 11 разных футболистов."}
    return {"valid": true, "reason": "Состав готов."}

func _live_lineup_validation() -> Dictionary:
    var slots: Array = _formations().get(str(game_state.get("formation", "4-4-2")), [])
    if slots.size() != 11:
        return {"valid": false, "reason": "В выбранной схеме должно быть ровно 11 позиционных ячеек."}
    # Для проверки схемы считаем всех футболистов, которые формально ещё на поле.
    # Травмированный остаётся в своей ячейке до официальной замены, а удалённый
    # полностью исключается из состава. Поэтому пустых мест должно быть ровно
    # столько, сколько удалений, независимо от того, куда пользователь передвинул
    # оставшихся игроков.
    var active_ids: Array = _team_on_pitch_player_ids(selected_team_id)
    var active_lookup: Dictionary = {}
    for raw_id in active_ids:
        active_lookup[str(int(raw_id))] = true
    var expected_empty = max(0, 11 - active_ids.size())
    var empty_slots = 0
    var used: Dictionary = {}
    var goalkeeper_present = false
    for raw_slot in slots:
        var slot = _dynamic_slot_data(raw_slot)
        var slot_id = str(slot.get("id", ""))
        var player_id = int(lineup.get(slot_id, -1))
        if player_id < 0:
            empty_slots += 1
            continue
        if not active_lookup.has(str(player_id)):
            var absent_name = str(_player(player_id).get("name", "Игрок"))
            return {"valid": false, "reason": "%s уже не находится на поле. Удалённого или травмированного игрока нужно убрать из схемы." % absent_name}
        if used.has(str(player_id)):
            return {"valid": false, "reason": "%s указан в схеме дважды." % _player(player_id).get("name", "Игрок")}
        used[str(player_id)] = true
        var is_gk_slot = "GK" in slot.get("accepted", [])
        if is_gk_slot and not _is_goalkeeper(_player(player_id)):
            return {"valid": false, "reason": "В ячейке GK должен находиться вратарь."}
        if not is_gk_slot and _is_goalkeeper(_player(player_id)):
            return {"valid": false, "reason": "Вратарь не может играть в поле."}
        if is_gk_slot and _is_goalkeeper(_player(player_id)):
            goalkeeper_present = true
    if used.size() != active_ids.size():
        return {"valid": false, "reason": "Не все оставшиеся на поле футболисты размещены в схеме."}
    if empty_slots != expected_empty:
        return {"valid": false, "reason": "После удаления или незаменённой травмы должно быть пустых позиций: %d. Сейчас: %d." % [expected_empty, empty_slots]}
    var active_has_goalkeeper = false
    for raw_id in active_ids:
        if _is_goalkeeper(_player(int(raw_id))):
            active_has_goalkeeper = true
            break
    if active_has_goalkeeper and not goalkeeper_present:
        return {"valid": false, "reason": "Оставшийся вратарь должен находиться в ячейке GK."}
    var status_parts: Array = []
    var red_count = _sent_off_count(selected_team_id)
    var injured_count = _injured_on_pitch_count(selected_team_id)
    if red_count > 0:
        status_parts.append("удалений: %d" % red_count)
    if injured_count > 0:
        status_parts.append("незаменённых травм: %d" % injured_count)
    return {"valid": true, "reason": "Тактика готова%s." % (" · " + ", ".join(status_parts) if not status_parts.is_empty() else "")}

func _lineup_is_valid() -> bool:
    return bool(_lineup_validation().get("valid", false))

func _confirm_starting_lineup() -> void:
    formation_edit_mode = false
    _sanitize_lineup()
    var validation = _lineup_validation()

    if not current_match.is_empty():
        game_state["lineup_confirmed"] = bool(validation.get("valid", false))
        if bool(validation.get("valid", false)):
            _sync_user_match_lineup_from_tactics()
            _ensure_set_piece_assignments()
            notice_text = "Тактика применена. Пустое место после удаления может перемещаться вместе с перестройкой, но заполнить его заменой нельзя."
            _show_dashboard("match")
        else:
            notice_text = "Не удалось применить тактику: %s" % str(validation.get("reason", "неизвестная ошибка"))
            _show_dashboard("tactics")
        return

    # Перед новым матчем мягко восстанавливаем пустые/дублирующиеся ячейки старых сохранений.
    # Расставленные пользователем корректные футболисты остаются на своих местах.
    if not bool(validation.get("valid", false)):
        lineup = _auto_pick_lineup(str(game_state.get("formation", "4-4-2")))
        _sanitize_lineup()
        validation = _lineup_validation()

    game_state["lineup_confirmed"] = bool(validation.get("valid", false))
    if bool(validation.get("valid", false)):
        notice_text = "Состав подтверждён: 11 разных игроков, вратарь находится в воротах."
        _show_dashboard("match")
    else:
        notice_text = "Не удалось подготовить состав: %s" % str(validation.get("reason", "неизвестная ошибка"))
        _show_dashboard("tactics")

func _refresh_pitch_slots() -> void:
    for slot_id in pitch_slots.keys():
        var slot = pitch_slots[slot_id] as PositionSlot
        var player_id = int(lineup.get(slot_id, -1))
        if player_id >= 0:
            var slot_data = _formation_slot(slot_id)
            var player = _player(player_id)
            slot.set_player(player, _effective_rating_for_slot(player, slot_data.get("accepted", [])), _fit_description(player, slot_data.get("accepted", [])))
        else:
            slot.set_player({})
    var power = screen_root.find_child("PowerLabel", true, false) as Label
    if power:
        power.text = "Сила выбранного состава: %d" % int(_user_team_power())

func _formation_selected(index: int, option: OptionButton) -> void:
    formation_edit_mode = false
    var formation_name = option.get_item_text(index)
    var old_players = _unique_player_ids(lineup.values())
    game_state["formation"] = formation_name
    lineup = _lineup_from_player_pool(formation_name, old_players, current_match.is_empty())
    _sanitize_lineup()
    game_state["lineup_confirmed"] = _lineup_is_valid()
    selected_tactics_player_id = -1
    if current_match.is_empty():
        notice_text = "Схема изменена на %s. Игроки автоматически распределены; теперь их можно свободно менять местами перетаскиванием." % formation_name
    else:
        notice_text = "Схема изменена на %s. Оставшиеся на поле игроки сразу перераспределены; пустая позиция после удаления допустима." % formation_name
    _show_dashboard("tactics")

func _style_selected(index: int, option: OptionButton) -> void:
    game_state["tactical_style"] = option.get_item_text(index)
    var power = screen_root.find_child("PowerLabel", true, false) as Label
    if power:
        power.text = "Сила выбранного состава: %d" % int(_user_team_power())

func _auto_lineup_pressed() -> void:
    if not current_match.is_empty():
        notice_text = "Автосостав недоступен во время матча: используйте разрешённые замены."
    else:
        lineup = _auto_pick_lineup(str(game_state.get("formation", "4-4-2")))
        game_state["lineup_confirmed"] = true
        notice_text = "Выбран оптимальный состав с учётом позиций и рейтинга. Он уже готов к матчу."
    _show_dashboard("tactics")

func _render_match() -> void:
    _sanitize_lineup()
    content_area.add_child(_title("Матч"))
    if not current_match.is_empty():
        var absences: Array = []
        var injury_key = "home_injured" if selected_team_id == int(current_match.get("home", -1)) else "away_injured"
        var red_key = "home_sent_off" if selected_team_id == int(current_match.get("home", -1)) else "away_sent_off"
        for raw_id in current_match.get(injury_key, []): absences.append("ТРАВМА: %s — можно заменить" % _player(int(raw_id)).get("name", "Игрок"))
        for raw_id in current_match.get(red_key, []): absences.append("УДАЛЁН: %s — заменить нельзя" % _player(int(raw_id)).get("name", "Игрок"))
        if not absences.is_empty():
            var warning = _label(" | ".join(absences), 13, colors.danger)
            warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
            content_area.add_child(warning)
    if current_match.is_empty():
        var next = _next_user_fixture()
        if next.is_empty():
            _render_season_finished()
            return
        var panel = PanelContainer.new()
        panel.add_theme_stylebox_override("panel", _panel_style(colors.panel, Color("245269"), 12, 1))
        content_area.add_child(panel)
        var box = VBoxContainer.new()
        box.add_theme_constant_override("separation", 14)
        panel.add_child(box)
        var next_label = "Тур %d" % int(next.get("round", 1)) if str(next.get("competition_type", "league")) == "league" else "%s · %s" % [next.get("competition_name", "Кубок"), next.get("round_name", "Раунд")]
        box.add_child(_label("Следующий матч · %s" % next_label, 14, colors.mint))
        var matchup = _label("%s   —   %s" % [_team_name(int(next.get("home", -1))), _team_name(int(next.get("away", -1)))], 30, colors.text)
        matchup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        matchup.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        box.add_child(matchup)
        box.add_child(_label("Матч рассчитывается по отрезкам. Между ними можно менять стиль, схему и делать до пяти замен.", 14, colors.muted))
        var home_team = _team(int(next.get("home", -1)))
        var away_team = _team(int(next.get("away", -1)))
        var coaches = _label("%s: %s · %s   |   %s: %s · %s" % [home_team.get("name", "Клуб"), home_team.get("coach_name", "Тренер"), home_team.get("coach_formation", "4-4-2"), away_team.get("name", "Клуб"), away_team.get("coach_name", "Тренер"), away_team.get("coach_formation", "4-4-2")], 13, colors.warning)
        coaches.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        coaches.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        box.add_child(coaches)
        var powers = _label("Ориентировочная сила: %s %d  ·  %s %d" % [_team_name(int(next.get("home", -1))), int(_team_match_power(int(next.get("home", -1)))), _team_name(int(next.get("away", -1))), int(_team_match_power(int(next.get("away", -1))))], 14, colors.cyan)
        powers.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        box.add_child(powers)
        var validation = _lineup_validation()
        var lineup_ready = bool(validation.get("valid", false))
        game_state["lineup_confirmed"] = lineup_ready
        var status_text = "Стартовые 11 готовы" if lineup_ready else str(validation.get("reason", "Перед матчем расставьте 11 игроков."))
        var status_label = _label(status_text, 14, colors.mint if lineup_ready else colors.warning)
        status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        box.add_child(status_label)
        var match_buttons = HBoxContainer.new()
        match_buttons.add_theme_constant_override("separation", 10)
        box.add_child(match_buttons)
        var tactics_button = _button("ПРОВЕРИТЬ СОСТАВ")
        tactics_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        tactics_button.pressed.connect(_show_dashboard.bind("tactics"))
        match_buttons.add_child(tactics_button)
        var start = _button("НАЧАТЬ МАТЧ", true)
        start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        start.disabled = not lineup_ready
        start.pressed.connect(_begin_match.bind(int(next.get("index", -1))))
        match_buttons.add_child(start)
        return

    var score_panel = PanelContainer.new()
    score_panel.add_theme_stylebox_override("panel", _panel_style(Color("0e2231"), colors.cyan, 12, 1))
    content_area.add_child(score_panel)
    var score_box = VBoxContainer.new()
    score_box.add_theme_constant_override("separation", 8)
    score_panel.add_child(score_box)
    var minute = _current_match_minute()
    var status = "ЗАВЕРШЁН" if bool(current_match.get("finished", false)) else "%d-я минута" % minute
    var status_label = _label(status, 14, colors.mint)
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    score_box.add_child(status_label)
    var score = _label("%s   %d : %d   %s" % [_team_name(int(current_match.get("home", -1))), int(current_match.get("home_score", 0)), int(current_match.get("away_score", 0)), _team_name(int(current_match.get("away", -1)))], 32, colors.text)
    score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    score.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    score_box.add_child(score)

    var action_bar = HFlowContainer.new()
    action_bar.add_theme_constant_override("h_separation", 10)
    action_bar.add_theme_constant_override("v_separation", 8)
    content_area.add_child(action_bar)
    if not bool(current_match.get("finished", false)):
        var next_segment = _button("СИМУЛИРОВАТЬ СЛЕДУЮЩИЙ ОТРЕЗОК", true)
        next_segment.custom_minimum_size.x = 330
        next_segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        next_segment.pressed.connect(_simulate_next_segment)
        action_bar.add_child(next_segment)
        var substitution = _button("ЗАМЕНА (%d/%d)" % [int(current_match.get("substitutions", 0)), MAX_SUBSTITUTIONS])
        substitution.custom_minimum_size.x = 170
        substitution.disabled = int(current_match.get("substitutions", 0)) >= MAX_SUBSTITUTIONS
        substitution.pressed.connect(_open_substitution_dialog)
        action_bar.add_child(substitution)
        var tactics = _button("ИЗМЕНИТЬ ТАКТИКУ")
        tactics.custom_minimum_size.x = 190
        tactics.pressed.connect(_show_dashboard.bind("tactics"))
        action_bar.add_child(tactics)
    else:
        var continue_button = _button("ПРОДОЛЖИТЬ", true)
        continue_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        continue_button.pressed.connect(_close_finished_match)
        action_bar.add_child(continue_button)
        _render_post_match_report()

    var lower: BoxContainer
    if get_viewport_rect().size.x < 1250.0:
        lower = VBoxContainer.new()
    else:
        lower = HBoxContainer.new()
    lower.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    lower.size_flags_vertical = Control.SIZE_EXPAND_FILL
    lower.add_theme_constant_override("separation", 14)
    content_area.add_child(lower)

    var log_panel = PanelContainer.new()
    log_panel.custom_minimum_size.y = 360
    log_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    log_panel.add_theme_stylebox_override("panel", _panel_style(colors.panel, Color("1b3e52"), 10, 1))
    lower.add_child(log_panel)
    var log_box = VBoxContainer.new()
    log_box.add_theme_constant_override("separation", 8)
    log_panel.add_child(log_box)
    log_box.add_child(_label("Ход матча", 18, colors.text))
    var log_scroll = ScrollContainer.new()
    log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    log_box.add_child(log_scroll)
    var events = VBoxContainer.new()
    events.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    events.add_theme_constant_override("separation", 5)
    log_scroll.add_child(events)
    var match_events: Array = current_match.get("events", [])
    for i in range(match_events.size() - 1, -1, -1):
        var event_label = _label(str(match_events[i]), 13, colors.text)
        event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        events.add_child(event_label)

    var match_info = PanelContainer.new()
    match_info.custom_minimum_size = Vector2(310, 0)
    match_info.add_theme_stylebox_override("panel", _panel_style(colors.panel, Color("1b3e52"), 10, 1))
    lower.add_child(match_info)
    var info_box = VBoxContainer.new()
    info_box.add_theme_constant_override("separation", 10)
    match_info.add_child(info_box)
    info_box.add_child(_label("Голы", 18, colors.text))
    var goal_events: Array = current_match.get("goals", [])
    if goal_events.is_empty():
        info_box.add_child(_label("Голов пока нет.", 13, colors.muted))
    else:
        for goal in goal_events:
            var scorer_name = str(_player(int(goal.get("scorer_id", -1))).get("name", "Игрок"))
            var assist_id = int(goal.get("assister_id", -1))
            var assist_text = "" if assist_id < 0 else "\nассист: %s" % _player(assist_id).get("name", "Игрок")
            var line = _label("%d'  %s\n%s%s" % [int(goal.get("minute", 0)), _team_name(int(goal.get("team_id", -1))), scorer_name, assist_text], 13, colors.mint if int(goal.get("team_id", -1)) == selected_team_id else colors.text)
            line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
            info_box.add_child(line)

func _begin_match(fixture_index: int) -> void:
    if fixture_index < 0 or fixture_index >= fixtures.size():
        return
    _sanitize_lineup()
    var validation = _lineup_validation()
    if not bool(validation.get("valid", false)):
        notice_text = str(validation.get("reason", "Сначала расставьте 11 игроков."))
        _show_dashboard("tactics")
        return
    _ensure_set_piece_assignments()
    var fixture: Dictionary = fixtures[fixture_index]
    var home_id = int(fixture.get("home", -1))
    var away_id = int(fixture.get("away", -1))
    var home_lineup = _team_starting_ids(home_id)
    var away_lineup = _team_starting_ids(away_id)
    var home_bench = _team_bench_ids(home_id, home_lineup)
    var away_bench = _team_bench_ids(away_id, away_lineup)
    current_match = {
        "fixture_index": fixture_index,
        "home": home_id, "away": away_id,
        "home_score": 0, "away_score": 0,
        "segment_index": 0,
        "events": ["0' Судья дал стартовый свисток."],
        "substitutions": 0, "subbed_out": [], "subbed_in": [],
        "home_substitutions": 0, "away_substitutions": 0,
        "home_subbed_out": [], "away_subbed_out": [], "home_subbed_in": [], "away_subbed_in": [],
        "home_lineup": home_lineup, "away_lineup": away_lineup,
        "home_bench": home_bench, "away_bench": away_bench,
        "appeared": [], "home_sent_off": [], "away_sent_off": [],
        "home_injured": [], "away_injured": [],
        "home_injury_events": [], "away_injury_events": [],
        "yellow_counts": {}, "new_suspensions": [],
        "home_stats": _empty_team_match_stats(), "away_stats": _empty_team_match_stats(),
        "match_ratings": {},
        "goals": [], "player_match_goals": {}, "player_match_assists": {},
        "minutes_played": {},
        "pre_match_lineup": lineup.duplicate(true),
        "pre_match_formation": str(game_state.get("formation", "4-4-2")),
        "finished": false
    }
    for player_id in home_lineup:
        _register_match_appearance(int(player_id))
        _set_match_rating(int(player_id), 6.5)
    for player_id in away_lineup:
        _register_match_appearance(int(player_id))
        _set_match_rating(int(player_id), 6.5)
    _show_dashboard("match")

func _team_bench_ids(team_id: int, starting_ids: Array) -> Array:
    var result: Array = []
    for raw_id in _match_squad(team_id):
        var player_id = int(raw_id)
        var player = _player(player_id)
        if player_id in starting_ids or _is_player_unavailable(player) or bool(player.get("retired", false)):
            continue
        result.append(player_id)
    result.sort_custom(func(a, b):
        var pa = _player(int(a))
        var pb = _player(int(b))
        var score_a = int(pa.get("rating", 0)) + int(pa.get("condition", 100)) * 0.08
        var score_b = int(pb.get("rating", 0)) + int(pb.get("condition", 100)) * 0.08
        return score_a > score_b)
    return result.slice(0, min(12, result.size()))

func _record_goal_event(team_id: int, scorer_id: int, assister_id: int, minute: int, goal_type: String) -> void:
    var goals: Array = current_match.get("goals", [])
    goals.append({"team_id": team_id, "scorer_id": scorer_id, "assister_id": assister_id, "minute": minute, "type": goal_type})
    current_match["goals"] = goals
    var scorer_map: Dictionary = current_match.get("player_match_goals", {})
    scorer_map[str(scorer_id)] = int(scorer_map.get(str(scorer_id), 0)) + 1
    current_match["player_match_goals"] = scorer_map
    if assister_id >= 0:
        var assist_map: Dictionary = current_match.get("player_match_assists", {})
        assist_map[str(assister_id)] = int(assist_map.get(str(assister_id), 0)) + 1
        current_match["player_match_assists"] = assist_map

func _apply_segment_fatigue(start_minute: int, end_minute: int) -> void:
    var duration = max(1, end_minute - start_minute)
    var minutes: Dictionary = current_match.get("minutes_played", {})
    for side in ["home", "away"]:
        var team_id = int(current_match.get(side, -1))
        var style = _team_tactical_style(team_id)
        var style_drain = 0.0
        if style == "Прессинг": style_drain = 1.15
        elif style == "Атака": style_drain = 0.55
        elif style == "Глубокая оборона + контратака": style_drain = -0.20
        for raw_id in _team_on_pitch_player_ids(team_id):
            var player_id = int(raw_id)
            var player = _player(player_id)
            var role = _player_match_role(team_id, player_id)
            var role_drain = 0.45 if role in ["RW", "LW", "RM", "LM", "RWB", "LWB"] else 0.0
            var drain = float(duration) * 0.145 + style_drain + role_drain + rng.randf_range(0.0, 0.65)
            player["condition"] = max(CONDITION_MINIMUM, int(round(float(player.get("condition", 100)) - drain)))
            minutes[str(player_id)] = int(minutes.get(str(player_id), 0)) + duration
    current_match["minutes_played"] = minutes

func _side_key_for_team(team_id: int) -> String:
    return "home" if team_id == int(current_match.get("home", -1)) else "away"

func _maybe_ai_substitutions(end_minute: int) -> void:
    if current_match.is_empty():
        return
    var ai_team_id = int(current_match.get("away", -1)) if selected_team_id == int(current_match.get("home", -1)) else int(current_match.get("home", -1))
    if ai_team_id < 0:
        return
    var side = _side_key_for_team(ai_team_id)
    var used = int(current_match.get("%s_substitutions" % side, 0))
    if used >= MAX_AI_SUBSTITUTIONS:
        return
    var injury_key = "%s_injured" % side
    var injured: Array = current_match.get(injury_key, [])
    var active: Array = _team_on_pitch_player_ids(ai_team_id)
    var bench_key = "%s_bench" % side
    var bench: Array = current_match.get(bench_key, []).duplicate()
    var planned = 0
    while used + planned < MAX_AI_SUBSTITUTIONS:
        var out_id = -1
        for raw_id in active:
            if int(raw_id) in injured:
                out_id = int(raw_id)
                break
        if out_id < 0 and end_minute >= 45:
            var tired: Array = active.duplicate()
            tired.sort_custom(func(a, b): return int(_player(int(a)).get("condition", 100)) < int(_player(int(b)).get("condition", 100)))
            if not tired.is_empty():
                var candidate_id = int(tired[0])
                var threshold = 73 if end_minute >= 75 else (66 if end_minute >= 60 else 58)
                if int(_player(candidate_id).get("condition", 100)) <= threshold and rng.randf() < (0.78 if end_minute >= 65 else 0.52):
                    out_id = candidate_id
        if out_id < 0:
            break
        var out_player = _player(out_id)
        var out_role = _player_match_role(ai_team_id, out_id)
        if out_role.is_empty():
            out_role = str(out_player.get("position", "CM"))
        var best_in = -1
        var best_score = -9999.0
        for raw_in in bench:
            var in_id = int(raw_in)
            var incoming = _player(in_id)
            if _is_player_unavailable(incoming):
                continue
            if _is_goalkeeper(out_player) != _is_goalkeeper(incoming):
                continue
            var score = float(incoming.get("rating", 0)) * _role_fit(incoming, [out_role]) + float(incoming.get("condition", 100)) * 0.12
            if score > best_score:
                best_score = score
                best_in = in_id
        if best_in < 0:
            break
        _replace_current_match_player(ai_team_id, out_id, best_in)
        _clear_injured_on_pitch_after_substitution(ai_team_id, out_id)
        active.erase(out_id)
        active.append(best_in)
        bench.erase(best_in)
        bench.append(out_id)
        planned += 1
        _register_match_appearance(best_in)
        _set_match_rating(best_in, 6.3)
        _add_match_event("%d' Автоматическая замена у %s: %s уходит, %s выходит." % [end_minute, _team_name(ai_team_id), out_player.get("name", "Игрок"), _player(best_in).get("name", "Игрок")])
    if planned > 0:
        current_match["%s_substitutions" % side] = used + planned
        current_match[bench_key] = bench

func _post_match_condition_recovery() -> void:
    var appeared: Array = current_match.get("appeared", [])
    for team_id in [int(current_match.get("home", -1)), int(current_match.get("away", -1))]:
        for raw_id in _match_squad(team_id):
            var player_id = int(raw_id)
            var player = _player(player_id)
            if _is_player_injured(player):
                player["condition"] = min(int(player.get("condition", 100)), 72)
                continue
            var recovery = 5 if player_id in appeared else 13
            player["condition"] = min(100, int(player.get("condition", 100)) + recovery)

func _simulate_next_segment() -> void:
    if current_match.is_empty() or bool(current_match.get("finished", false)):
        return
    _sanitize_lineup()
    var live_validation = _live_lineup_validation()
    if not bool(live_validation.get("valid", false)):
        notice_text = "Перед продолжением матча поправьте схему: %s" % str(live_validation.get("reason", "тактика заполнена неверно"))
        _show_dashboard("tactics")
        return
    var segment_index = int(current_match.get("segment_index", 0))
    if segment_index >= SEGMENTS.size():
        return
    var start_minute = 0 if segment_index == 0 else int(SEGMENTS[segment_index - 1])
    var end_minute = int(SEGMENTS[segment_index])
    var home_id = int(current_match.get("home", -1))
    var away_id = int(current_match.get("away", -1))

    _simulate_team_segment(home_id, away_id, start_minute, end_minute, true)
    _simulate_team_segment(away_id, home_id, start_minute, end_minute, false)
    _apply_segment_fatigue(start_minute, end_minute)
    _maybe_ai_substitutions(end_minute)

    if end_minute == 45:
        _add_match_event("45' Перерыв. Тренеры могут изменить тактику.")
    elif end_minute == 90:
        _add_match_event("90' Финальный свисток.")

    current_match["segment_index"] = segment_index + 1
    if end_minute >= 90:
        _finish_match()
    _show_dashboard("match")

func _simulate_team_segment(attacker_id: int, defender_id: int, start_minute: int, end_minute: int, is_home: bool) -> void:
    var attack_power = _team_match_power(attacker_id)
    var defense_power = _team_match_power(defender_id)
    if is_home:
        attack_power += 2.0
    var style = _team_tactical_style(attacker_id)
    var sent_off_count = _sent_off_count(attacker_id)
    var strength_probability = clamp(0.5 + (attack_power - defense_power) / 76.0, 0.10, 0.90)
    var random_component = 0.22 + rng.randf() * 0.56
    var luck_component = rng.randf()
    var attack_quality = 0.60 * strength_probability + 0.30 * random_component + 0.10 * luck_component
    if style == "Атака": attack_quality += 0.035
    elif style == "Контратака": attack_quality += 0.018
    elif style == "Глубокая оборона + контратака": attack_quality += 0.008 if sent_off_count > 0 else -0.020
    attack_quality = clamp(attack_quality, 0.10, 0.93)

    var possession_share = clamp(50.0 + (attack_power - defense_power) * 1.15, 27.0, 73.0)
    if style == "Оборона" or style == "Глубокая оборона + контратака": possession_share -= 8.0
    _add_team_match_stat(attacker_id, "possession_points", int(round(possession_share)))
    _add_team_match_stat(attacker_id, "possession_segments", 1)

    var attempts = 1
    var duration = end_minute - start_minute
    var extra_attempt_chance = 0.10 + float(duration) * 0.009 + attack_quality * 0.14
    if sent_off_count > 0:
        extra_attempt_chance -= 0.11 * sent_off_count
    if start_minute >= 65 and int(current_match.get("home_score", 0)) + int(current_match.get("away_score", 0)) <= 1:
        extra_attempt_chance += 0.10
    if rng.randf() < clamp(extra_attempt_chance, 0.02, 0.52):
        attempts += 1
    if rng.randf() < 0.04 + attack_quality * 0.025:
        attempts += 1
    for _attempt in range(attempts):
        _simulate_attack_event(attacker_id, defender_id, start_minute, end_minute, attack_quality)
    _maybe_match_injury(attacker_id, start_minute, end_minute)

func _simulate_attack_event(attacker_id: int, defender_id: int, start_minute: int, end_minute: int, attack_quality: float) -> void:
    var event_chance = 0.49 + attack_quality * 0.25
    if rng.randf() > event_chance:
        if rng.randf() < 0.12:
            var quiet_minute = rng.randi_range(start_minute + 1, end_minute)
            _add_match_event("%d' %s контролирует мяч, но оборона закрывает зоны." % [quiet_minute, _team_name(attacker_id)])
        return
    var minute = rng.randi_range(start_minute + 1, end_minute)
    var set_piece_roll = rng.randf()
    if set_piece_roll < 0.024:
        _simulate_penalty_event(attacker_id, defender_id, minute, attack_quality)
        return
    if set_piece_roll < 0.078:
        _simulate_free_kick_event(attacker_id, defender_id, minute, attack_quality)
        return
    if set_piece_roll < 0.145:
        _simulate_corner_event(attacker_id, defender_id, minute, attack_quality)
        return
    var scorer = _pick_goal_scorer(attacker_id)
    var scorer_id = int(scorer.get("id", -1))
    var assister = _pick_assist_provider(attacker_id, scorer_id)
    var assister_id = int(assister.get("id", -1))
    var scorer_rating = float(scorer.get("rating", 70))
    var scorer_role = _player_match_role(attacker_id, scorer_id)
    var position_bonus = {
        "ST": 0.030, "CF": 0.025, "LW": 0.020, "RW": 0.020, "AM": 0.012,
        "LM": 0.006, "RM": 0.006, "CM": 0.002, "DM": -0.009,
        "LWB": -0.001, "RWB": -0.001, "LB": -0.005, "RB": -0.005, "CB": -0.007
    }.get(scorer_role, 0.0)
    var goal_chance = 0.064 + attack_quality * 0.146 + clamp((scorer_rating - 70.0) / 950.0, -0.014, 0.028) + position_bonus
    if _team_tactical_style(attacker_id) == "Атака": goal_chance += 0.011
    if _team_tactical_style(attacker_id) == "Глубокая оборона + контратака" and _sent_off_count(attacker_id) > 0:
        goal_chance += 0.018
    goal_chance = clamp(goal_chance, 0.065, 0.29)
    var roll = rng.randf()
    _add_team_match_stat(attacker_id, "shots", 1)
    if roll < goal_chance:
        _add_team_match_stat(attacker_id, "shots_on_target", 1)
        if attacker_id == int(current_match.get("home", -1)):
            current_match["home_score"] = int(current_match.get("home_score", 0)) + 1
        else:
            current_match["away_score"] = int(current_match.get("away_score", 0)) + 1
        _add_player_stat(scorer_id, "goals", 1)
        _adjust_match_rating(scorer_id, 1.0)
        var credited_assister = -1
        if assister_id >= 0 and assister_id != scorer_id and rng.randf() < 0.80:
            credited_assister = assister_id
            _add_player_stat(assister_id, "assists", 1)
            _adjust_match_rating(assister_id, 0.55)
        _record_goal_event(attacker_id, scorer_id, credited_assister, minute, "с игры")
        if scorer_role == "CB":
            _add_team_match_stat(attacker_id, "corners", 1)
            _add_match_event("%d' ГОЛ! После углового %s выиграл верховую борьбу. %s забивает!" % [minute, scorer.get("name", "Защитник"), _team_name(attacker_id)])
        else:
            _add_match_event("%d' ГОЛ! %s завершил атаку после передачи %s. %s забивает!" % [minute, scorer.get("name", "Игрок"), assister.get("name", "партнёра"), _team_name(attacker_id)])
    elif roll < goal_chance + 0.29:
        _add_team_match_stat(attacker_id, "shots_on_target", 1)
        _adjust_match_rating(scorer_id, 0.08)
        _add_match_event("%d' Опасно! %s пробил в створ, но вратарь %s спас команду." % [minute, scorer.get("name", "Игрок"), _team_name(defender_id)])
    elif roll < goal_chance + 0.54:
        _add_match_event("%d' %s нанёс удар — рядом со штангой ворот %s." % [minute, scorer.get("name", "Игрок"), _team_name(defender_id)])
    elif roll < goal_chance + 0.68:
        _add_team_match_stat(defender_id, "fouls", 1)
        var offender = _pick_card_player(defender_id)
        var offender_id = int(offender.get("id", -1))
        if offender_id >= 0:
            _issue_match_card(defender_id, offender_id, minute)
    else:
        if rng.randf() < 0.30:
            _add_team_match_stat(attacker_id, "corners", 1)
        _add_match_event("%d' %s разогнал атаку %s, но защитники заблокировали удар." % [minute, assister.get("name", "Игрок"), _team_name(attacker_id)])

func _empty_team_match_stats() -> Dictionary:
    return {"shots": 0, "shots_on_target": 0, "possession_points": 0, "possession_segments": 0, "corners": 0, "fouls": 0, "yellow": 0, "red": 0}

func _team_stats_key(team_id: int) -> String:
    return "home_stats" if team_id == int(current_match.get("home", -1)) else "away_stats"

func _add_team_match_stat(team_id: int, field: String, amount: int) -> void:
    var key = _team_stats_key(team_id)
    var stats: Dictionary = current_match.get(key, _empty_team_match_stats())
    stats[field] = int(stats.get(field, 0)) + amount
    current_match[key] = stats

func _set_match_rating(player_id: int, value: float) -> void:
    var ratings: Dictionary = current_match.get("match_ratings", {})
    ratings[str(player_id)] = clamp(value, 1.0, 10.0)
    current_match["match_ratings"] = ratings

func _adjust_match_rating(player_id: int, amount: float) -> void:
    if player_id < 0: return
    var ratings: Dictionary = current_match.get("match_ratings", {})
    ratings[str(player_id)] = clamp(float(ratings.get(str(player_id), 6.5)) + amount, 1.0, 10.0)
    current_match["match_ratings"] = ratings

func _finalize_match_ratings() -> void:
    var home_score = int(current_match.get("home_score", 0))
    var away_score = int(current_match.get("away_score", 0))
    var ratings: Dictionary = current_match.get("match_ratings", {})
    for side in ["home", "away"]:
        var team_id = int(current_match.get(side, -1))
        var scored = home_score if side == "home" else away_score
        var conceded = away_score if side == "home" else home_score
        for raw_id in current_match.get("%s_lineup" % side, []):
            var player_id = int(raw_id)
            var player = _player(player_id)
            var value = float(ratings.get(str(player_id), 6.5))
            if scored > conceded: value += 0.25
            elif scored < conceded: value -= 0.20
            if conceded == 0 and str(player.get("position", "")) in ["GK", "CB", "LB", "RB"]: value += 0.35
            if conceded >= 3 and str(player.get("position", "")) in ["GK", "CB", "LB", "RB"]: value -= 0.30
            value += rng.randf_range(-0.28, 0.28)
            ratings[str(player_id)] = clamp(value, 3.0, 10.0)
    current_match["match_ratings"] = ratings
    for key in ratings.keys():
        var player_id = int(key)
        var value = float(ratings[key])
        var stats: Dictionary = player_stats.get(str(player_id), _empty_player_stat())
        stats["rating_sum"] = float(stats.get("rating_sum", 0.0)) + value
        stats["rating_apps"] = int(stats.get("rating_apps", 0)) + 1
        player_stats[str(player_id)] = stats
        var player = _player(player_id)
        var career_apps = int(player.get("career_rating_apps", 0))
        player["career_avg_rating"] = (float(player.get("career_avg_rating", 6.5)) * career_apps + value) / float(career_apps + 1)
        player["career_rating_apps"] = career_apps + 1

func _team_tactical_style(team_id: int) -> String:
    if team_id == selected_team_id:
        return str(game_state.get("tactical_style", "Сбалансированно"))
    return str(_team(team_id).get("coach_style", "Сбалансированно"))

func _sent_off_count(team_id: int) -> int:
    if current_match.is_empty(): return 0
    return (current_match.get("home_sent_off", []) as Array).size() if team_id == int(current_match.get("home", -1)) else (current_match.get("away_sent_off", []) as Array).size()

func _injured_on_pitch_count(team_id: int) -> int:
    if current_match.is_empty():
        return 0
    var injury_key = "home_injured" if team_id == int(current_match.get("home", -1)) else "away_injured"
    var lineup_key = "home_lineup" if team_id == int(current_match.get("home", -1)) else "away_lineup"
    var injured: Array = current_match.get(injury_key, [])
    var current_ids: Array = current_match.get(lineup_key, [])
    var count = 0
    for raw_id in current_ids:
        if int(raw_id) in injured:
            count += 1
    return count

func _maybe_match_injury(team_id: int, start_minute: int, end_minute: int) -> void:
    var chance = 0.006
    if team_id == selected_team_id and str(game_state.get("tactical_style", "")) == "Прессинг": chance += 0.004
    if rng.randf() > chance: return
    var injury_key = "home_injured" if team_id == int(current_match.get("home", -1)) else "away_injured"
    var event_key = "home_injury_events" if team_id == int(current_match.get("home", -1)) else "away_injury_events"
    var injured_ids: Array = current_match.get(injury_key, [])
    var injury_events: Array = current_match.get(event_key, [])
    var candidates: Array = []
    for raw_id in _active_team_player_ids(team_id):
        var player_id = int(raw_id)
        if player_id in injured_ids or player_id in (current_match.get("home_sent_off", []) as Array) or player_id in (current_match.get("away_sent_off", []) as Array): continue
        candidates.append(player_id)
    if candidates.is_empty(): return
    var player_id = int(candidates[rng.randi_range(0, candidates.size() - 1)])
    var player = _player(player_id)
    var injury = _roll_injury(player)
    var injury_days = int(injury.get("days", 7))
    player["injury_days"] = max(int(player.get("injury_days", 0)), injury_days)
    player["injured_matches"] = int(ceil(float(player["injury_days"]) / float(MATCH_DAYS_STEP)))
    player["injury_name"] = str(injury.get("name", "Повреждение"))
    player["injury_details"] = str(injury.get("details", injury.get("name", "Повреждение")))
    player["injury_severity"] = str(injury.get("severity", "лёгкая"))
    player["injury_history"] = int(player.get("injury_history", 0)) + 1
    if injury_days >= 90: player["severe_injuries"] = int(player.get("severe_injuries", 0)) + 1
    if player_id not in injured_ids: injured_ids.append(player_id)
    if player_id not in injury_events: injury_events.append(player_id)
    current_match[injury_key] = injured_ids
    current_match[event_key] = injury_events
    _adjust_match_rating(player_id, -0.35)
    _add_match_event("%d' Травма: %s — %s. Предварительный срок восстановления: %s." % [rng.randi_range(start_minute + 1, end_minute), player.get("name", "Игрок"), injury.get("details", "повреждение"), _duration_text(injury_days)])

func _roll_injury(player: Dictionary) -> Dictionary:
    var roll = rng.randf()
    if roll < 0.20: return {"name":"ушиб", "details":"сильный ушиб бедра", "severity":"лёгкая", "days":rng.randi_range(3, 8)}
    if roll < 0.34: return {"name":"повреждение пальца", "details":"трещина или перелом пальца", "severity":"лёгкая", "days":rng.randi_range(7, 18)}
    if roll < 0.50: return {"name":"растяжение", "details":"растяжение задней поверхности бедра", "severity":"средняя", "days":rng.randi_range(14, 35)}
    if roll < 0.63: return {"name":"голеностоп", "details":"растяжение связок голеностопа", "severity":"средняя", "days":rng.randi_range(18, 50)}
    if roll < 0.73: return {"name":"паховая мышца", "details":"повреждение паховой мышцы", "severity":"средняя", "days":rng.randi_range(21, 55)}
    if roll < 0.82: return {"name":"сотрясение", "details":"лёгкое сотрясение мозга", "severity":"средняя", "days":rng.randi_range(10, 28)}
    if roll < 0.90: return {"name":"колено", "details":"повреждение боковых связок колена", "severity":"тяжёлая", "days":rng.randi_range(55, 120)}
    if roll < 0.96: return {"name":"перелом", "details":"перелом голени", "severity":"тяжёлая", "days":rng.randi_range(110, 190)}
    return {"name":"крестообразные связки", "details":"разрыв крестообразной связки колена", "severity":"очень тяжёлая", "days":rng.randi_range(210, 270)}

func _advance_injury_recovery() -> void:
    var newly_injured: Array = []
    if not current_match.is_empty():
        newly_injured.append_array(current_match.get("home_injury_events", []))
        newly_injured.append_array(current_match.get("away_injury_events", []))
    for key in players_by_id.keys():
        var player_id = int(key)
        var player = players_by_id[key]
        if player_id in newly_injured:
            continue
        var days = int(player.get("injury_days", int(player.get("injured_matches", 0)) * MATCH_DAYS_STEP))
        if days > 0:
            days = max(0, days - MATCH_DAYS_STEP)
            player["injury_days"] = days
            player["injured_matches"] = int(ceil(float(days) / float(MATCH_DAYS_STEP))) if days > 0 else 0
            if days == 0:
                player["injury_name"] = ""
                player["injury_details"] = ""
                player["injury_severity"] = ""
                player["condition"] = min(82, int(player.get("condition", 100)))

func _advance_suspension_recovery() -> void:
    var newly_suspended: Array = current_match.get("new_suspensions", []) if not current_match.is_empty() else []
    for key in players_by_id.keys():
        var player_id = int(key)
        var player = players_by_id[key]
        if player_id in newly_suspended:
            continue
        var matches = int(player.get("suspended_matches", 0))
        if matches > 0:
            matches -= 1
            player["suspended_matches"] = max(0, matches)
            if matches <= 0:
                player["suspension_reason"] = ""

func _apply_match_development() -> void:
    var ratings: Dictionary = current_match.get("match_ratings", {})
    var current_round = int(game_state.get("development_round", 0))
    for key in ratings.keys():
        var player_id = int(key)
        var player = _player(player_id)
        var rating = float(ratings[key])
        var age = int(player.get("age", 25))
        var age_factor = 0.35 if age <= 21 else (0.15 if age <= 25 else (-0.10 if age >= 32 else 0.0))
        var club_id = _club_for_player(player_id)
        var youth_factor = 0.0
        if club_id >= 0:
            var coach_youth = float(_team(club_id).get("coach_youth", 1.0))
            youth_factor = (coach_youth - 1.0) * (0.80 if age <= 23 else 0.25)
        var points = float(player.get("development_points", 0.0)) + (rating - 6.5) * 0.75 + age_factor + youth_factor
        player["development_points"] = clamp(points, -20.0, 20.0)
        if current_round - int(player.get("last_rating_change_round", -99)) < DEVELOPMENT_CHECK_ROUNDS: continue
        if int(player.get("rating_changes_season", 0)) >= 2: continue
        if points >= 8.5 and int(player.get("rating", 0)) < 95:
            player["rating"] = int(player.get("rating", 0)) + 1
            player["development_points"] = points - 8.5
            player["rating_changes_season"] = int(player.get("rating_changes_season", 0)) + 1
            player["last_rating_change_round"] = current_round
            _add_match_event("Развитие: %s прибавил в рейтинге и теперь имеет %d." % [player.get("name", "Игрок"), int(player.get("rating", 0))])
        elif points <= -8.5 and int(player.get("rating", 0)) > 45:
            player["rating"] = int(player.get("rating", 0)) - 1
            player["development_points"] = points + 8.5
            player["rating_changes_season"] = int(player.get("rating_changes_season", 0)) + 1
            player["last_rating_change_round"] = current_round

func _career_stat_bucket(player: Dictionary, club_id: int) -> Dictionary:
    var history: Dictionary = player.get("career_club_stats", {})
    var key = str(club_id)
    var bucket: Dictionary = history.get(key, {"apps": 0, "goals": 0, "assists": 0, "clean_sheets": 0, "conceded": 0})
    history[key] = bucket
    player["career_club_stats"] = history
    return bucket

func _store_career_stat_bucket(player: Dictionary, club_id: int, bucket: Dictionary) -> void:
    var history: Dictionary = player.get("career_club_stats", {})
    history[str(club_id)] = bucket
    player["career_club_stats"] = history

func _update_career_player_records() -> void:
    var goal_map: Dictionary = current_match.get("player_match_goals", {})
    var assist_map: Dictionary = current_match.get("player_match_assists", {})
    var appeared: Array = current_match.get("appeared", [])
    var home_id = int(current_match.get("home", -1))
    var away_id = int(current_match.get("away", -1))
    var home_conceded = int(current_match.get("away_score", 0))
    var away_conceded = int(current_match.get("home_score", 0))
    for raw_id in appeared:
        var player_id = int(raw_id)
        var player = _player(player_id)
        if player.is_empty():
            continue
        var club_id = _club_for_player(player_id)
        if club_id < 0:
            club_id = home_id if player_id in current_match.get("home_lineup", []) else away_id
        var goals = int(goal_map.get(str(player_id), 0))
        var assists = int(assist_map.get(str(player_id), 0))
        var bucket = _career_stat_bucket(player, club_id)
        bucket["apps"] = int(bucket.get("apps", 0)) + 1
        bucket["goals"] = int(bucket.get("goals", 0)) + goals
        bucket["assists"] = int(bucket.get("assists", 0)) + assists
        player["career_total_apps"] = int(player.get("career_total_apps", 0)) + 1
        player["career_total_goals"] = int(player.get("career_total_goals", 0)) + goals
        player["career_total_assists"] = int(player.get("career_total_assists", 0)) + assists
        if _is_goalkeeper(player):
            var conceded = home_conceded if club_id == home_id else away_conceded
            bucket["conceded"] = int(bucket.get("conceded", 0)) + conceded
            player["career_total_conceded"] = int(player.get("career_total_conceded", 0)) + conceded
            if conceded == 0:
                bucket["clean_sheets"] = int(bucket.get("clean_sheets", 0)) + 1
                player["career_total_clean_sheets"] = int(player.get("career_total_clean_sheets", 0)) + 1
        _store_career_stat_bucket(player, club_id, bucket)

func _finish_match() -> void:
    current_match["finished"] = true
    var fixture_index = int(current_match.get("fixture_index", -1))
    if fixture_index < 0 or fixture_index >= fixtures.size():
        return
    _finalize_match_ratings()
    var fixture: Dictionary = fixtures[fixture_index]
    fixture["played"] = true
    fixture["home_score"] = int(current_match.get("home_score", 0))
    fixture["away_score"] = int(current_match.get("away_score", 0))
    fixture["report"] = {"home_stats": current_match.get("home_stats", {}), "away_stats": current_match.get("away_stats", {}), "ratings": current_match.get("match_ratings", {}).duplicate(true), "goals": current_match.get("goals", []).duplicate(true)}
    fixtures[fixture_index] = fixture
    var competition_type = str(fixture.get("competition_type", "league"))
    if competition_type == "league":
        _apply_result(int(fixture.get("home", -1)), int(fixture.get("away", -1)), int(fixture.get("home_score", 0)), int(fixture.get("away_score", 0)))
        _simulate_other_fixtures(int(fixture.get("round", 1)), fixture_index)
        _sync_user_league_state()
        _simulate_world_round(int(fixture.get("round", 1)))
    else:
        _resolve_cup_fixture(fixture_index)
    _record_clean_sheet(int(fixture.get("home", -1)), int(fixture.get("away_score", 0)), current_match.get("home_lineup", []))
    _record_clean_sheet(int(fixture.get("away", -1)), int(fixture.get("home_score", 0)), current_match.get("away_lineup", []))
    _update_career_player_records()
    _post_match_condition_recovery()
    var user_is_home = int(fixture.get("home", -1)) == selected_team_id
    var user_goals = int(fixture.get("home_score", 0)) if user_is_home else int(fixture.get("away_score", 0))
    var opp_goals = int(fixture.get("away_score", 0)) if user_is_home else int(fixture.get("home_score", 0))
    game_state["career_gf"] = int(game_state.get("career_gf", 0)) + user_goals
    game_state["career_ga"] = int(game_state.get("career_ga", 0)) + opp_goals
    if user_goals > opp_goals: game_state["career_wins"] = int(game_state.get("career_wins", 0)) + 1
    elif user_goals == opp_goals: game_state["career_draws"] = int(game_state.get("career_draws", 0)) + 1
    else: game_state["career_losses"] = int(game_state.get("career_losses", 0)) + 1
    var sponsor_bonus = _sponsor_match_bonus(user_goals, opp_goals)
    if sponsor_bonus > 0:
        game_state["budget"] = int(game_state.get("budget", 0)) + sponsor_bonus
        game_state["sponsor_income"] = int(game_state.get("sponsor_income", 0)) + sponsor_bonus
        game_state["season_sponsor_income"] = int(game_state.get("season_sponsor_income", 0)) + sponsor_bonus
        _add_match_event("Финансы: спонсор перечислил %s." % _money(sponsor_bonus))
    _advance_position_training()
    _advance_injury_recovery()
    _advance_suspension_recovery()
    _apply_match_development()
    _advance_reserve_academy_development()
    _maybe_generate_transfer_offer()
    game_state["development_round"] = int(game_state.get("development_round", 0)) + 1
    if str(_transfer_window_status().get("name", "")) == "winter" and not bool(game_state.get("winter_window_processed", false)):
        _process_ai_transfer_window("winter")
        game_state["winter_window_processed"] = true

func _close_finished_match() -> void:
    var restored_lineup: Dictionary = current_match.get("pre_match_lineup", {}).duplicate(true)
    if not restored_lineup.is_empty():
        lineup = restored_lineup
        game_state["formation"] = str(current_match.get("pre_match_formation", game_state.get("formation", "4-4-2")))
        game_state["lineup_confirmed"] = true
    current_match.clear()
    _sanitize_lineup()
    _show_dashboard("match")

func _open_substitution_dialog() -> void:
    if int(current_match.get("substitutions", 0)) >= MAX_SUBSTITUTIONS:
        notice_text = "Лимит в пять замен уже использован."
        _show_dashboard("match")
        return
    # Во время матча нельзя очищать травмированного из словаря расстановки:
    # иначе слот становится пустым и его невозможно заполнить заменой.
    var dialog = Window.new()
    dialog.title = "Пакет замен · %d-я минута" % _current_match_minute()
    dialog.transient = true
    dialog.exclusive = true
    dialog.unresizable = false
    var viewport_size = get_viewport_rect().size
    dialog.size = Vector2i(int(min(1180.0, viewport_size.x - 30.0)), int(min(760.0, viewport_size.y - 30.0)))
    var state = {
        "original_lineup": lineup.duplicate(true),
        "working_lineup": lineup.duplicate(true),
        "changes": [],
        "selected": -1,
        "existing_out": current_match.get("subbed_out", []).duplicate(),
        "existing_in": current_match.get("subbed_in", []).duplicate(),
        "message": ""
    }
    dialog.set_meta("sub_state", state)
    add_child(dialog)
    _render_substitution_dialog(dialog)
    dialog.close_requested.connect(_close_substitution_dialog.bind(dialog))
    dialog.popup_centered()

func _render_substitution_dialog(dialog: Window) -> void:
    if not is_instance_valid(dialog):
        return
    for child in dialog.get_children():
        dialog.remove_child(child)
        child.queue_free()
    var state: Dictionary = dialog.get_meta("sub_state")
    var working_lineup: Dictionary = state.get("working_lineup", {})
    var changes: Array = state.get("changes", [])
    var existing_out: Array = state.get("existing_out", [])
    var existing_in: Array = state.get("existing_in", [])
    var staged_out: Array = []
    var staged_in: Array = []
    for change in changes:
        staged_out.append(int(change.get("out", -1)))
        staged_in.append(int(change.get("in", -1)))

    var panel = PanelContainer.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    panel.add_theme_stylebox_override("panel", _panel_style(Color("0d1b29"), colors.cyan, 10, 1))
    dialog.add_child(panel)
    var root = VBoxContainer.new()
    root.add_theme_constant_override("separation", 9)
    panel.add_child(root)
    var remaining = MAX_SUBSTITUTIONS - int(current_match.get("substitutions", 0))
    root.add_child(_label("Запланировано %d из %d доступных замен" % [changes.size(), remaining], 20, colors.text))
    var status_text = "Выберите запасного щелчком или перетащите его на футболиста справа. Окно останется открытым — можно подготовить несколько замен."
    if not str(state.get("message", "")).is_empty():
        status_text = str(state.get("message", ""))
    elif int(state.get("selected", -1)) >= 0:
        status_text = "Выбран %s. Нажмите игрока на поле, которого нужно заменить." % _player(int(state.get("selected", -1))).get("name", "Игрок")
    root.add_child(_label(status_text, 13, colors.warning))

    var split = HBoxContainer.new()
    split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    split.size_flags_vertical = Control.SIZE_EXPAND_FILL
    split.add_theme_constant_override("separation", 12)
    root.add_child(split)

    var bench_panel = PanelContainer.new()
    bench_panel.custom_minimum_size = Vector2(370, 0)
    bench_panel.add_theme_stylebox_override("panel", _panel_style(Color("102434"), Color("31566b"), 8, 1))
    split.add_child(bench_panel)
    var bench_box = VBoxContainer.new()
    bench_box.add_theme_constant_override("separation", 7)
    bench_panel.add_child(bench_box)
    bench_box.add_child(_label("Доступные запасные", 17, colors.mint))
    var bench_scroll = ScrollContainer.new()
    bench_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    bench_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    bench_box.add_child(bench_scroll)
    var bench_list = VBoxContainer.new()
    bench_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    bench_list.add_theme_constant_override("separation", 6)
    bench_scroll.add_child(bench_list)
    var bench_count = 0
    for raw_id in _match_squad(selected_team_id):
        var id = int(raw_id)
        if _is_player_unavailable(_player(id)):
            continue
        if id in working_lineup.values() or id in existing_out or id in existing_in or id in staged_out or id in staged_in:
            continue
        bench_count += 1
        var token = PlayerToken.new()
        token.setup(_player(id))
        token.player_selected.connect(_select_pending_sub_player.bind(dialog))
        bench_list.add_child(token)
    if bench_count == 0:
        bench_list.add_child(_label("Нет доступных запасных.", 13, colors.muted))

    var field_panel = PanelContainer.new()
    field_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    field_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    field_panel.add_theme_stylebox_override("panel", _panel_style(Color("0b2029"), Color("245269"), 8, 1))
    split.add_child(field_panel)
    var field_box = VBoxContainer.new()
    field_box.add_theme_constant_override("separation", 8)
    field_panel.add_child(field_box)
    field_box.add_child(_label("Состав после запланированных замен", 17, colors.mint))
    var active_scroll = ScrollContainer.new()
    active_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    active_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    field_box.add_child(active_scroll)
    var active_grid = GridContainer.new()
    active_grid.columns = 3
    active_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    active_grid.add_theme_constant_override("h_separation", 10)
    active_grid.add_theme_constant_override("v_separation", 10)
    active_scroll.add_child(active_grid)
    for slot_data in _formations().get(str(game_state.get("formation", "4-4-2")), []):
        var slot_id = str(slot_data.get("id", ""))
        var target = PositionSlot.new()
        target.setup(slot_data)
        target.custom_minimum_size = Vector2(180, 92)
        var active_player_id = int(working_lineup.get(slot_id, -1))
        var active_player = _player(active_player_id)
        var red_key = "home_sent_off" if selected_team_id == int(current_match.get("home", -1)) else "away_sent_off"
        var injury_key = "home_injured" if selected_team_id == int(current_match.get("home", -1)) else "away_injured"
        var status = _fit_description(active_player, slot_data.get("accepted", []))
        if active_player_id < 0 and _sent_off_count(selected_team_id) > 0:
            target.set_empty_message("МЕНЬШИНСТВО", "место после удаления", "заменой заполнить нельзя")
        else:
            if active_player_id in (current_match.get(red_key, []) as Array):
                status = "УДАЛЁН · заменить нельзя"
            elif active_player_id in (current_match.get(injury_key, []) as Array):
                status = "ТРАВМА · требуется замена"
            target.set_player(active_player, _effective_rating_for_slot(active_player, slot_data.get("accepted", [])), status)
        target.player_dropped.connect(_stage_substitution.bind(dialog))
        target.slot_pressed.connect(_pending_substitution_slot_clicked.bind(dialog))
        active_grid.add_child(target)

    var plan = _label("План: нет изменений" if changes.is_empty() else "План: " + _substitution_plan_text(changes), 13, colors.text)
    plan.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    root.add_child(plan)
    var buttons = HBoxContainer.new()
    buttons.add_theme_constant_override("separation", 8)
    root.add_child(buttons)
    var undo = _button("ОТМЕНИТЬ ПОСЛЕДНЮЮ")
    undo.disabled = changes.is_empty()
    undo.pressed.connect(_undo_pending_substitution.bind(dialog))
    buttons.add_child(undo)
    var cancel = _button("ОТМЕНИТЬ ВСЕ")
    cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    cancel.pressed.connect(_close_substitution_dialog.bind(dialog))
    buttons.add_child(cancel)
    var confirm = _button("ПОДТВЕРДИТЬ ЗАМЕНЫ", true)
    confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    confirm.disabled = changes.is_empty()
    confirm.pressed.connect(_confirm_substitution_batch.bind(dialog))
    buttons.add_child(confirm)

func _select_pending_sub_player(player_id: int, dialog: Window) -> void:
    var state: Dictionary = dialog.get_meta("sub_state")
    state["selected"] = player_id
    state["message"] = ""
    dialog.set_meta("sub_state", state)
    _render_substitution_dialog(dialog)

func _pending_substitution_slot_clicked(slot_id: String, dialog: Window) -> void:
    var state: Dictionary = dialog.get_meta("sub_state")
    var selected = int(state.get("selected", -1))
    if selected >= 0:
        _stage_substitution(selected, slot_id, dialog)

func _stage_substitution(in_player_id: int, target_slot_id: String, dialog: Window) -> void:
    if not is_instance_valid(dialog): return
    var state: Dictionary = dialog.get_meta("sub_state")
    var changes: Array = state.get("changes", [])
    var remaining = MAX_SUBSTITUTIONS - int(current_match.get("substitutions", 0))
    if changes.size() >= remaining: return
    var working_lineup: Dictionary = state.get("working_lineup", {}).duplicate(true)
    var out_player_id = int(working_lineup.get(target_slot_id, -1))
    if in_player_id < 0 or in_player_id in working_lineup.values():
        return
    if out_player_id < 0:
        state["message"] = "Эта пустая позиция является местом после удаления. Заполнить её заменой нельзя — выберите футболиста, который действительно находится на поле."
        state["selected"] = in_player_id
        dialog.set_meta("sub_state", state)
        _render_substitution_dialog(dialog)
        return
    var red_key = "home_sent_off" if selected_team_id == int(current_match.get("home", -1)) else "away_sent_off"
    if out_player_id in (current_match.get(red_key, []) as Array):
        state["message"] = "Удалённого футболиста заменить нельзя: команда продолжает матч в меньшинстве."
        dialog.set_meta("sub_state", state)
        _render_substitution_dialog(dialog)
        return
    var target_slot = _formation_slot(target_slot_id)
    var target_is_goalkeeper = "GK" in target_slot.get("accepted", [])
    if target_is_goalkeeper != _is_goalkeeper(_player(in_player_id)): return
    var forbidden: Array = state.get("existing_out", []).duplicate()
    forbidden.append_array(state.get("existing_in", []))
    for change in changes:
        forbidden.append(int(change.get("out", -1)))
        forbidden.append(int(change.get("in", -1)))
    if in_player_id in forbidden: return
    working_lineup[target_slot_id] = in_player_id
    changes.append({"slot": target_slot_id, "out": out_player_id, "in": in_player_id})
    state["working_lineup"] = working_lineup
    state["changes"] = changes
    state["selected"] = -1
    state["message"] = ""
    dialog.set_meta("sub_state", state)
    _render_substitution_dialog(dialog)

func _undo_pending_substitution(dialog: Window) -> void:
    var state: Dictionary = dialog.get_meta("sub_state")
    var changes: Array = state.get("changes", [])
    if changes.is_empty():
        return
    changes.pop_back()
    var working: Dictionary = state.get("original_lineup", {}).duplicate(true)
    for change in changes:
        working[str(change.get("slot", ""))] = int(change.get("in", -1))
    state["changes"] = changes
    state["working_lineup"] = working
    state["selected"] = -1
    dialog.set_meta("sub_state", state)
    _render_substitution_dialog(dialog)

func _confirm_substitution_batch(dialog: Window) -> void:
    var state: Dictionary = dialog.get_meta("sub_state")
    var changes: Array = state.get("changes", [])
    if changes.is_empty():
        return
    var subbed_out: Array = current_match.get("subbed_out", [])
    var subbed_in: Array = current_match.get("subbed_in", [])
    for change in changes:
        var slot_id = str(change.get("slot", ""))
        var out_id = int(change.get("out", -1))
        var in_id = int(change.get("in", -1))
        lineup[slot_id] = in_id
        if out_id not in subbed_out:
            subbed_out.append(out_id)
        if in_id not in subbed_in:
            subbed_in.append(in_id)
        _replace_current_match_player(selected_team_id, out_id, in_id)
        _clear_injured_on_pitch_after_substitution(selected_team_id, out_id)
        _register_match_appearance(in_id)
        _set_match_rating(in_id, 6.3)
        _add_match_event("%d' Замена у %s: %s уходит, %s выходит на поле." % [_current_match_minute(), _team_name(selected_team_id), _player(out_id).get("name", "Игрок"), _player(in_id).get("name", "Игрок")])
    current_match["subbed_out"] = subbed_out
    current_match["subbed_in"] = subbed_in
    current_match["substitutions"] = int(current_match.get("substitutions", 0)) + changes.size()
    var user_side = _side_key_for_team(selected_team_id)
    current_match["%s_substitutions" % user_side] = int(current_match.get("%s_substitutions" % user_side, 0)) + changes.size()
    var user_bench_key = "%s_bench" % user_side
    var user_bench: Array = current_match.get(user_bench_key, []).duplicate()
    for change in changes:
        user_bench.erase(int(change.get("in", -1)))
        user_bench.append(int(change.get("out", -1)))
    current_match[user_bench_key] = user_bench
    _sanitize_lineup()
    notice_text = "Подтверждено замен: %d. Снятые футболисты не смогут вернуться." % changes.size()
    _close_substitution_dialog(dialog)
    _show_dashboard("match")

func _substitution_plan_text(changes: Array) -> String:
    var parts: Array = []
    for change in changes:
        parts.append("%s → %s" % [_player(int(change.get("out", -1))).get("name", "Игрок"), _player(int(change.get("in", -1))).get("name", "Игрок")])
    return "; ".join(parts)

func _close_substitution_dialog(dialog: Window) -> void:
    selected_substitution_player_id = -1
    if is_instance_valid(dialog):
        dialog.queue_free()

func _render_post_match_report() -> void:
    var panel = PanelContainer.new()
    panel.add_theme_stylebox_override("panel", _panel_style(Color("0c202d"), Color("245269"), 10, 1))
    content_area.add_child(panel)
    var root = VBoxContainer.new()
    root.add_theme_constant_override("separation", 10)
    panel.add_child(root)
    root.add_child(_label("Послематчевая статистика", 20, colors.mint))
    var home_id = int(current_match.get("home", -1))
    var away_id = int(current_match.get("away", -1))
    var home: Dictionary = current_match.get("home_stats", {})
    var away: Dictionary = current_match.get("away_stats", {})
    var header = HBoxContainer.new()
    root.add_child(header)
    var h1 = _label(_team_name(home_id), 14, colors.cyan); h1.custom_minimum_size.x = 220; header.add_child(h1)
    var h2 = _label("Показатель", 14, colors.mint); h2.custom_minimum_size.x = 220; header.add_child(h2)
    header.add_child(_label(_team_name(away_id), 14, colors.cyan))
    var home_pos = int(round(float(home.get("possession_points", 0)) / max(1, int(home.get("possession_segments", 1)))))
    var away_pos = 100 - home_pos
    var rows = [
        [home.get("shots", 0), "Удары", away.get("shots", 0)],
        [home.get("shots_on_target", 0), "Удары в створ", away.get("shots_on_target", 0)],
        ["%d%%" % home_pos, "Владение", "%d%%" % away_pos],
        [home.get("corners", 0), "Угловые", away.get("corners", 0)],
        [home.get("fouls", 0), "Фолы", away.get("fouls", 0)],
        [home.get("yellow", 0), "Жёлтые", away.get("yellow", 0)],
        [home.get("red", 0), "Красные", away.get("red", 0)]
    ]
    for data in rows:
        var row = HBoxContainer.new(); root.add_child(row)
        var left = _label(str(data[0]), 14, colors.text); left.custom_minimum_size.x = 220; row.add_child(left)
        var name = _label(str(data[1]), 13, colors.muted); name.custom_minimum_size.x = 220; row.add_child(name)
        row.add_child(_label(str(data[2]), 14, colors.text))
    root.add_child(_label("Оценки игроков", 18, colors.mint))
    var ratings: Dictionary = current_match.get("match_ratings", {})
    var rating_rows: Array = []
    for key in ratings.keys(): rating_rows.append({"id": int(key), "rating": float(ratings[key])})
    rating_rows.sort_custom(func(a, b): return float(a["rating"]) > float(b["rating"]))
    var grid = GridContainer.new(); grid.columns = 2; grid.add_theme_constant_override("h_separation", 12); grid.add_theme_constant_override("v_separation", 5); root.add_child(grid)
    for data in rating_rows:
        var color = colors.mint if float(data["rating"]) >= 7.5 else (colors.danger if float(data["rating"]) <= 5.5 else colors.text)
        grid.add_child(_label("%s — %.1f" % [_player(int(data["id"])).get("name", "Игрок"), float(data["rating"])], 13, color))

func _render_calendar() -> void:
    content_area.add_child(_title("Календарь сезона"))
    var scroll = ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content_area.add_child(scroll)
    var list = VBoxContainer.new()
    list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    list.add_theme_constant_override("separation", 7)
    scroll.add_child(list)
    var calendar_fixtures = fixtures.duplicate(true)
    calendar_fixtures.sort_custom(func(a, b): return int(a.get("calendar_order", a.get("round", 999) * 10)) < int(b.get("calendar_order", b.get("round", 999) * 10)))
    for fixture in calendar_fixtures:
        var involves_user = int(fixture.get("home", -1)) == selected_team_id or int(fixture.get("away", -1)) == selected_team_id
        var row = PanelContainer.new()
        row.add_theme_stylebox_override("panel", _panel_style(Color("102838") if involves_user else Color("0d1d29"), colors.cyan if involves_user else Color("19374a"), 8, 1))
        var h = HBoxContainer.new()
        h.add_theme_constant_override("separation", 10)
        row.add_child(h)
        var competition_type = str(fixture.get("competition_type", "league"))
        var round_text = "Тур %d" % int(fixture.get("round", 1)) if competition_type == "league" else str(fixture.get("round_name", fixture.get("competition_name", "Кубок")))
        var round_label = _label(round_text, 13, colors.mint if involves_user else colors.muted)
        round_label.custom_minimum_size.x = 80
        h.add_child(round_label)
        var score_text = "—"
        if bool(fixture.get("played", false)):
            score_text = "%d : %d" % [int(fixture.get("home_score", 0)), int(fixture.get("away_score", 0))]
        var game_label = _label("%s   %s   %s" % [_team_name(int(fixture.get("home", -1))), score_text, _team_name(int(fixture.get("away", -1)))], 14, colors.text)
        game_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        h.add_child(game_label)
        list.add_child(row)

func _render_table() -> void:
    content_area.add_child(_title("Турнирная таблица"))
    content_area.add_child(_label("Нажмите на название клуба, чтобы открыть тренера, схему, полный состав и статистику футболистов.", 13, colors.muted))
    var header = HBoxContainer.new()
    for item in [["#",45],["Клуб",300],["И",55],["В",55],["Н",55],["П",55],["Мячи",100],["РМ",70],["О",65]]:
        var l=_label(item[0],12,colors.mint); l.custom_minimum_size.x=item[1]; header.add_child(l)
    content_area.add_child(header)
    var rows=_sorted_table()
    var list=VBoxContainer.new(); list.add_theme_constant_override("separation",6); content_area.add_child(list)
    for i in range(rows.size()):
        var team_id=int(rows[i]["team_id"]); var st:Dictionary=rows[i]["stats"]
        var row=PanelContainer.new(); var is_user=team_id==selected_team_id
        row.add_theme_stylebox_override("panel",_panel_style(Color("12374a") if is_user else Color("0d1f2d"),colors.cyan if is_user else Color("193447"),7,1))
        var h=HBoxContainer.new(); row.add_child(h)
        var place=_label(str(i+1),14,colors.text); place.custom_minimum_size.x=45; h.add_child(place)
        h.add_child(_team_link_button(team_id,_team_name(team_id),300))
        var gd=int(st.get("gf",0))-int(st.get("ga",0))
        var values=[[st.get("p",0),55],[st.get("w",0),55],[st.get("d",0),55],[st.get("l",0),55],["%d–%d"%[st.get("gf",0),st.get("ga",0)],100],[("+" if gd>0 else "")+str(gd),70],[st.get("pts",0),65]]
        for value in values:
            var l=_label(str(value[0]),14,colors.warning if is_user and value==values[-1] else colors.text); l.custom_minimum_size.x=value[1]; h.add_child(l)
        list.add_child(row)

func _render_statistics() -> void:
    _ensure_player_stats()
    content_area.add_child(_title("Статистика сезона"))
    content_area.add_child(_label("Голы распределяются по ролям на поле; оценки игроков и развитие зависят от качества выступлений.", 13, colors.muted))
    var tabs = TabContainer.new()
    tabs.custom_minimum_size.y = 520
    tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content_area.add_child(tabs)
    _add_statistics_tab(tabs, "Бомбардиры", "goals")
    _add_statistics_tab(tabs, "Голевые передачи", "assists")
    _add_statistics_tab(tabs, "Средняя оценка", "average_rating")
    _add_statistics_tab(tabs, "Сухие матчи", "clean_sheets", true)
    _add_statistics_tab(tabs, "Карточки", "cards")

func _add_statistics_tab(tabs: TabContainer, tab_name: String, category: String, goalkeepers_only = false) -> void:
    var scroll = ScrollContainer.new()
    scroll.name = tab_name
    tabs.add_child(scroll)
    var list = VBoxContainer.new()
    list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    list.add_theme_constant_override("separation", 6)
    scroll.add_child(list)
    var header = HBoxContainer.new()
    header.add_theme_constant_override("separation", 8)
    list.add_child(header)
    var columns = [["#", 42], ["Игрок", 260], ["Клуб", 210], ["И", 55]]
    if category == "cards":
        columns.append(["ЖК", 70]); columns.append(["КК", 70])
    else:
        columns.append(["Показатель", 110])
    for column in columns:
        var label = _label(column[0], 12, colors.mint)
        label.custom_minimum_size.x = column[1]
        header.add_child(label)
    var rows = _sorted_statistics(category, goalkeepers_only)
    for i in range(min(30, rows.size())):
        var row_data: Dictionary = rows[i]
        var player_id = int(row_data.get("player_id", -1))
        var stats: Dictionary = row_data.get("stats", {})
        var row = PanelContainer.new()
        row.add_theme_stylebox_override("panel", _panel_style(Color("12374a") if _club_for_player(player_id) == selected_team_id else Color("0d1f2d"), Color("24485c"), 7, 1))
        var h = HBoxContainer.new(); h.add_theme_constant_override("separation", 8); row.add_child(h)
        var base_values = [[str(i + 1), 42], [_player(player_id).get("name", "Игрок"), 260], [_team_name(_club_for_player(player_id)), 210], [str(stats.get("apps", 0)), 55]]
        for value in base_values:
            var label = _label(str(value[0]), 13, colors.text); label.custom_minimum_size.x = value[1]; h.add_child(label)
        if category == "cards":
            var yellow = _label(str(stats.get("yellow", 0)), 13, colors.warning); yellow.custom_minimum_size.x = 70; h.add_child(yellow)
            var red = _label(str(stats.get("red", 0)), 13, colors.danger); red.custom_minimum_size.x = 70; h.add_child(red)
        else:
            var display_value = "0"
            if category == "average_rating":
                display_value = "%.2f" % _average_player_rating(stats)
            else:
                display_value = str(stats.get(category, 0))
            var value_label = _label(display_value, 14, colors.warning if display_value != "0" else colors.muted)
            value_label.custom_minimum_size.x = 110
            h.add_child(value_label)
        list.add_child(row)

func _sorted_statistics(category: String, goalkeepers_only = false) -> Array:
    var competition_id = str(_team(selected_team_id).get("competition", "eng1_demo"))
    return _sorted_statistics_for_comp(category, competition_id, goalkeepers_only)

func _average_player_rating(stats: Dictionary) -> float:
    var apps = int(stats.get("rating_apps", 0))
    return float(stats.get("rating_sum", 0.0)) / float(apps) if apps > 0 else 0.0

func _render_training() -> void:
    if not game_state.has("position_training") or not game_state.get("position_training") is Dictionary:
        game_state["position_training"] = {}
    content_area.add_child(_title("Тренировки и позиции"))
    var intro = _label("Обычная тренировка постепенно открывает дополнительную позицию после матчей. Специалист за £5 млн мгновенно доводит обучение до 100%. Изученную дополнительную позицию можно назначить основной.", 13, colors.muted)
    intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content_area.add_child(intro)

    var setup_panel = PanelContainer.new()
    setup_panel.add_theme_stylebox_override("panel", _panel_style(colors.panel, Color("1a3e52"), 10, 1))
    content_area.add_child(setup_panel)
    var setup_box = VBoxContainer.new()
    setup_box.add_theme_constant_override("separation", 10)
    setup_panel.add_child(setup_box)
    setup_box.add_child(_label("Обучение новой позиции", 18, colors.text))

    var controls = HFlowContainer.new()
    controls.add_theme_constant_override("h_separation", 10)
    controls.add_theme_constant_override("v_separation", 8)
    setup_box.add_child(controls)
    controls.add_child(_label("Игрок:", 13, colors.text))
    var player_option = OptionButton.new()
    var squad = _squad(selected_team_id).duplicate()
    squad.sort_custom(func(a, b): return str(_player(int(a)).get("name", "")) < str(_player(int(b)).get("name", "")))
    for player_id in squad:
        var player = _player(int(player_id))
        var secondary: Array = player.get("secondary", [])
        var positions = str(player.get("position", "?"))
        if not secondary.is_empty():
            positions += " / " + ", ".join(secondary)
        player_option.add_item("%s · %s" % [player.get("name", "Игрок"), positions], int(player_id))
    _style_option_button(player_option, 330)
    controls.add_child(player_option)

    controls.add_child(_label("Позиция:", 13, colors.text))
    var target_option = OptionButton.new()
    for position in POSITION_CODES:
        target_option.add_item("%s · %s" % [position, _position_name(position)])
    _style_option_button(target_option, 190)
    controls.add_child(target_option)

    controls.add_child(_label("Интенсивность:", 13, colors.text))
    var intensity_option = OptionButton.new()
    intensity_option.add_item("Лёгкая · медленно")
    intensity_option.add_item("Обычная · средне")
    intensity_option.add_item("Интенсивная · быстро")
    intensity_option.select(1)
    _style_option_button(intensity_option, 210)
    controls.add_child(intensity_option)

    var start = _button("НАЧАТЬ ОБЫЧНУЮ")
    start.pressed.connect(_start_position_training.bind(player_option, target_option, intensity_option))
    controls.add_child(start)
    var specialist = _button("НАНЯТЬ СПЕЦИАЛИСТА · %s" % _money(SPECIALIST_POSITION_COST), true)
    specialist.disabled = int(game_state.get("budget", 0)) < SPECIALIST_POSITION_COST
    specialist.pressed.connect(_specialist_position_training.bind(player_option, target_option))
    controls.add_child(specialist)

    var primary_panel = PanelContainer.new()
    primary_panel.add_theme_stylebox_override("panel", _panel_style(Color("10283a"), Color("245269"), 8, 1))
    content_area.add_child(primary_panel)
    var primary_box = HFlowContainer.new()
    primary_box.add_theme_constant_override("h_separation", 10)
    primary_box.add_theme_constant_override("v_separation", 8)
    primary_panel.add_child(primary_box)
    primary_box.add_child(_label("Смена основной позиции:", 14, colors.mint))
    var primary_player = OptionButton.new()
    for player_id in squad:
        var player = _player(int(player_id))
        if not (player.get("secondary", []) as Array).is_empty():
            primary_player.add_item("%s · сейчас %s" % [player.get("name", "Игрок"), player.get("position", "?")], int(player_id))
    _style_option_button(primary_player, 300)
    primary_box.add_child(primary_player)
    var primary_position = OptionButton.new()
    _style_option_button(primary_position, 190)
    primary_box.add_child(primary_position)
    if primary_player.item_count > 0:
        _fill_primary_position_options(primary_player.get_selected_id(), primary_position)
        primary_player.item_selected.connect(_primary_player_selected.bind(primary_player, primary_position))
    var make_primary = _button("СДЕЛАТЬ ОСНОВНОЙ", true)
    make_primary.disabled = primary_player.item_count == 0
    make_primary.pressed.connect(_set_trained_position_primary.bind(primary_player, primary_position))
    primary_box.add_child(make_primary)

    var active_panel = PanelContainer.new()
    active_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    active_panel.add_theme_stylebox_override("panel", _panel_style(colors.panel, Color("1a3e52"), 10, 1))
    content_area.add_child(active_panel)
    var active_box = VBoxContainer.new()
    active_box.add_theme_constant_override("separation", 8)
    active_panel.add_child(active_box)
    var trainings: Dictionary = game_state.get("position_training", {})
    active_box.add_child(_label("Активные тренировки: %d из %d" % [trainings.size(), MAX_POSITION_TRAININGS], 18, colors.text))
    if trainings.is_empty():
        active_box.add_child(_label("Сейчас никто не осваивает новую позицию.", 13, colors.muted))
    for key in trainings.keys():
        var player_id = int(key)
        var training: Dictionary = trainings[key]
        var player = _player(player_id)
        if player.is_empty():
            continue
        var row = PanelContainer.new()
        row.add_theme_stylebox_override("panel", _panel_style(Color("0d1f2d"), Color("24485c"), 8, 1))
        active_box.add_child(row)
        var row_box = HBoxContainer.new()
        row_box.add_theme_constant_override("separation", 12)
        row.add_child(row_box)
        var text_box = VBoxContainer.new()
        text_box.custom_minimum_size.x = 320
        row_box.add_child(text_box)
        text_box.add_child(_label("%s → %s" % [player.get("name", "Игрок"), training.get("target", "?")], 14, colors.text))
        text_box.add_child(_label("Интенсивность: %s" % training.get("intensity", "Обычная"), 12, colors.muted))
        var progress = ProgressBar.new()
        progress.min_value = 0
        progress.max_value = 100
        progress.value = float(training.get("progress", 0))
        progress.show_percentage = true
        progress.custom_minimum_size = Vector2(300, 34)
        progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row_box.add_child(progress)
        var stop = _button("ОТМЕНИТЬ")
        stop.custom_minimum_size.x = 120
        stop.pressed.connect(_stop_position_training.bind(player_id))
        row_box.add_child(stop)

func _start_position_training(player_option: OptionButton, target_option: OptionButton, intensity_option: OptionButton) -> void:
    if not current_match.is_empty():
        notice_text = "Новую тренировку нельзя назначить во время незавершённого матча."
        _show_dashboard("training")
        return
    var player_id = int(player_option.get_selected_id())
    var target = str(target_option.get_item_text(target_option.selected)).split(" · ")[0]
    var intensity = ["Лёгкая", "Обычная", "Интенсивная"][intensity_option.selected]
    var player = _player(player_id)
    if player.is_empty():
        return
    var known_positions = _normalize_positions(player)
    if target in known_positions:
        notice_text = "%s уже умеет играть на позиции %s." % [player.get("name", "Игрок"), target]
        _show_dashboard("training")
        return
    if _is_goalkeeper(player) != (target == "GK"):
        notice_text = "В этой версии полевого игрока нельзя переучить во вратаря, а вратаря — в полевого."
        _show_dashboard("training")
        return
    var trainings: Dictionary = game_state.get("position_training", {})
    if not trainings.has(str(player_id)) and trainings.size() >= MAX_POSITION_TRAININGS:
        notice_text = "Одновременно можно вести не больше %d индивидуальных тренировок." % MAX_POSITION_TRAININGS
        _show_dashboard("training")
        return
    trainings[str(player_id)] = {"target": target, "progress": 0, "intensity": intensity}
    game_state["position_training"] = trainings
    notice_text = "%s начал осваивать позицию %s. Прогресс появится после следующего матча." % [player.get("name", "Игрок"), target]
    _show_dashboard("training")

func _specialist_position_training(player_option: OptionButton, target_option: OptionButton) -> void:
    var player_id = int(player_option.get_selected_id())
    var target = str(target_option.get_item_text(target_option.selected)).split(" · ")[0]
    var player = _player(player_id)
    if player.is_empty():
        return
    if target in _normalize_positions(player):
        notice_text = "%s уже знает позицию %s." % [player.get("name", "Игрок"), target]
        _show_dashboard("training")
        return
    if _is_goalkeeper(player) != (target == "GK"):
        notice_text = "Специалист не переучивает полевого игрока во вратаря и наоборот."
        _show_dashboard("training")
        return
    if int(game_state.get("budget", 0)) < SPECIALIST_POSITION_COST:
        notice_text = "Не хватает денег на специалиста."
        _show_dashboard("training")
        return
    game_state["budget"] = int(game_state.get("budget", 0)) - SPECIALIST_POSITION_COST
    var secondary: Array = player.get("secondary", []).duplicate()
    if target != str(player.get("position", "")) and target not in secondary:
        secondary.append(target)
    player["secondary"] = secondary
    var trainings: Dictionary = game_state.get("position_training", {})
    trainings.erase(str(player_id))
    game_state["position_training"] = trainings
    notice_text = "%s полностью освоил позицию %s. Специалисту выплачено %s." % [player.get("name", "Игрок"), target, _money(SPECIALIST_POSITION_COST)]
    _show_dashboard("training")

func _primary_player_selected(_index: int, player_option: OptionButton, position_option: OptionButton) -> void:
    _fill_primary_position_options(player_option.get_selected_id(), position_option)

func _fill_primary_position_options(player_id: int, position_option: OptionButton) -> void:
    position_option.clear()
    var player = _player(player_id)
    for position in player.get("secondary", []):
        position_option.add_item("%s · %s" % [position, _position_name(str(position))])

func _set_trained_position_primary(player_option: OptionButton, position_option: OptionButton) -> void:
    if player_option.item_count == 0 or position_option.item_count == 0:
        return
    var player_id = int(player_option.get_selected_id())
    var new_primary = str(position_option.get_item_text(position_option.selected)).split(" · ")[0]
    var player = _player(player_id)
    var old_primary = str(player.get("position", ""))
    var secondary: Array = player.get("secondary", []).duplicate()
    if new_primary not in secondary:
        return
    secondary.erase(new_primary)
    if not old_primary.is_empty() and old_primary not in secondary:
        secondary.append(old_primary)
    player["position"] = new_primary
    player["secondary"] = secondary
    notice_text = "%s: позиция %s теперь основная, %s стала дополнительной." % [player.get("name", "Игрок"), new_primary, old_primary]
    _show_dashboard("training")

func _stop_position_training(player_id: int) -> void:
    var trainings: Dictionary = game_state.get("position_training", {})
    trainings.erase(str(player_id))
    game_state["position_training"] = trainings
    notice_text = "Индивидуальная тренировка отменена."
    _show_dashboard("training")

func _advance_position_training() -> void:
    var trainings: Dictionary = game_state.get("position_training", {})
    if trainings.is_empty():
        return
    var completed: Array = []
    for key in trainings.keys():
        var player_id = int(key)
        var training: Dictionary = trainings[key]
        var player = _player(player_id)
        if player.is_empty():
            completed.append(str(key))
            continue
        var intensity = str(training.get("intensity", "Обычная"))
        var gain = 10
        var fatigue = 1
        if intensity == "Лёгкая":
            gain = 7
            fatigue = 0
        elif intensity == "Интенсивная":
            gain = 15
            fatigue = 3
        var age = int(player.get("age", 25))
        if age <= 21:
            gain += 3
        elif age >= 30:
            gain -= 2
        var progress = min(100, int(training.get("progress", 0)) + max(3, gain))
        training["progress"] = progress
        player["condition"] = max(55, int(player.get("condition", 100)) - fatigue)
        var target = str(training.get("target", ""))
        if progress >= 100:
            var secondary: Array = player.get("secondary", []).duplicate()
            if target != str(player.get("position", "")) and target not in secondary:
                secondary.append(target)
            player["secondary"] = secondary
            completed.append(str(key))
            _add_match_event("Тренировка: %s освоил дополнительную позицию %s." % [player.get("name", "Игрок"), target])
        else:
            trainings[str(key)] = training
    for key in completed:
        trainings.erase(str(key))
    game_state["position_training"] = trainings

func _position_name(position: String) -> String:
    return {
        "GK": "вратарь", "RB": "правый защитник", "RWB": "правый латераль", "LB": "левый защитник", "LWB": "левый латераль", "CB": "центральный защитник",
        "DM": "опорный полузащитник", "CM": "центральный полузащитник", "AM": "атакующий полузащитник",
        "RM": "правый полузащитник", "LM": "левый полузащитник", "RW": "правый вингер",
        "LW": "левый вингер", "CF": "оттянутый форвард", "ST": "нападающий"
    }.get(position, position)

func _render_transfers() -> void:
    content_area.add_child(_title("Трансферы и контракты"))
    var window = _transfer_window_status()
    var window_open = bool(window.get("open", false))
    content_area.add_child(_label("Бюджет: %s · %s" % [_money(int(game_state.get("budget", 0))), window.get("text", "Трансферное окно закрыто")], 14, colors.mint if window_open else colors.warning))
    content_area.add_child(_label("Покупка, продажа и аренда доступны только в летнее или зимнее окно. При покупке срок контракта выбирается от 1 до 6 лет.", 13, colors.muted))
    var search_row = HBoxContainer.new()
    search_row.add_theme_constant_override("separation", 8)
    var search = LineEdit.new()
    search.placeholder_text = "Поиск по имени или фамилии"
    search.text = str(game_state.get("transfer_search", ""))
    search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    search.custom_minimum_size.y = 42
    search_row.add_child(search)
    var search_button = _button("НАЙТИ", true)
    search_button.pressed.connect(_apply_transfer_search.bind(search))
    search_row.add_child(search_button)
    var clear_button = _button("СБРОСИТЬ")
    clear_button.pressed.connect(_clear_transfer_search)
    search_row.add_child(clear_button)
    content_area.add_child(search_row)
    _render_incoming_transfer_offers()
    var tabs = TabContainer.new()
    tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content_area.add_child(tabs)

    var market_scroll = ScrollContainer.new()
    market_scroll.name = "Рынок"
    tabs.add_child(market_scroll)
    var market_list = VBoxContainer.new()
    market_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    market_list.add_theme_constant_override("separation", 7)
    market_scroll.add_child(market_list)
    for player_id in _transfer_market_view_ids():
        var player = _player(int(player_id))
        if player.is_empty() or bool(player.get("retired", false)):
            continue
        var row = PanelContainer.new()
        row.add_theme_stylebox_override("panel", _panel_style(Color("0d1f2d"), Color("193447"), 7, 1))
        var h = HBoxContainer.new()
        h.add_theme_constant_override("separation", 8)
        row.add_child(h)
        h.add_child(_player_link_button(int(player_id), "%s · %s · %d · %d лет" % [player.get("name", "Игрок"), player.get("position", "?"), int(player.get("rating", 0)), int(player.get("age", 0))], 460))
        h.add_child(_label(_money(int(player.get("value", 0))), 14, colors.mint))
        var buy = _button("КУПИТЬ")
        buy.custom_minimum_size.x = 120
        buy.disabled = not window_open or int(player.get("value", 0)) > int(game_state.get("budget", 0))
        buy.pressed.connect(_open_contract_offer_dialog.bind(int(player_id)))
        h.add_child(buy)
        market_list.add_child(row)

    var squad_scroll = ScrollContainer.new()
    squad_scroll.name = "Мои игроки"
    tabs.add_child(squad_scroll)
    var squad_list = VBoxContainer.new()
    squad_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    squad_list.add_theme_constant_override("separation", 7)
    squad_scroll.add_child(squad_list)
    for player_id in _squad(selected_team_id):
        var player = _player(int(player_id))
        var row = PanelContainer.new()
        row.add_theme_stylebox_override("panel", _panel_style(Color("0d1f2d"), Color("193447"), 7, 1))
        var h = HBoxContainer.new()
        h.add_theme_constant_override("separation", 8)
        row.add_child(h)
        var list_mark = " · НА ТРАНСФЕРЕ" if _is_transfer_listed(int(player_id)) else ""
        h.add_child(_player_link_button(int(player_id), "%s · %s · %d%s" % [player.get("name", "Игрок"), player.get("position", "?"), int(player.get("rating", 0)), list_mark], 420))
        var contract = _label("Контракт: %d г. · %s" % [int(player.get("contract_years", 1)), _weekly_money(int(player.get("wage_weekly", 0)))], 13, colors.muted)
        contract.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        h.add_child(contract)
        var details = _button("УПРАВЛЕНИЕ")
        details.pressed.connect(_open_player_dialog.bind(int(player_id)))
        h.add_child(details)
        squad_list.add_child(row)

    var loan_scroll = ScrollContainer.new()
    loan_scroll.name = "Аренды"
    tabs.add_child(loan_scroll)
    var loan_list = VBoxContainer.new()
    loan_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    loan_list.add_theme_constant_override("separation", 7)
    loan_scroll.add_child(loan_list)
    var loans: Dictionary = game_state.get("loans_out", {})
    if loans.is_empty():
        loan_list.add_child(_label("Игроков в аренде нет.", 13, colors.muted))
    else:
        for key in loans.keys():
            var loan: Dictionary = loans[key]
            loan_list.add_child(_label("%s · возврат в сезоне %d · получено %s" % [_player(int(key)).get("name", "Игрок"), int(loan.get("return_season", 2)), _money(int(loan.get("fee", 0)))], 14, colors.text))

func _buy_player(player_id: int, contract_years = 3) -> void:
    if not bool(_transfer_window_status().get("open", false)):
        notice_text = "Трансферное окно закрыто."
        _show_dashboard("transfers")
        return
    var player = _player(player_id)
    var owner_id = _club_for_player(player_id)
    if owner_id == selected_team_id: return
    if owner_id >= 0 and _squad(owner_id).size() <= 14:
        notice_text = "%s отказался продавать игрока: состав клуба слишком мал." % _team_name(owner_id)
        _show_dashboard("transfers")
        return
    var price = _purchase_price(player_id)
    var years = clamp(int(contract_years), 1, MAX_CONTRACT_YEARS)
    if price > int(game_state.get("budget", 0)): return
    if owner_id >= 0:
        _detach_player_from_all_clubs(player_id)
    game_state["budget"] = int(game_state.get("budget", 0)) - price
    if player_id not in club_squads[str(selected_team_id)]: club_squads[str(selected_team_id)].append(player_id)
    player["contract_years"] = years
    var wage_multiplier = 0.92 + float(years) * 0.035
    player["wage_weekly"] = max(int(player.get("wage_weekly", 1000)), int(round(float(player.get("rating", 60)) * 300.0 * wage_multiplier / 500.0) * 500))
    var market: Array = game_state.get("market_ids", [])
    market.erase(player_id)
    game_state["market_ids"] = market
    notice_text = "%s подписан за %s. Контракт: %d г., зарплата %s." % [player.get("name", "Игрок"), _money(price), years, _weekly_money(int(player.get("wage_weekly", 0)))]
    _sanitize_lineup()
    _show_dashboard("transfers")

func _open_contract_offer_dialog(player_id: int) -> void:
    if not bool(_transfer_window_status().get("open", false)):
        notice_text = "Трансферное окно закрыто."
        _show_dashboard("transfers")
        return
    var player = _player(player_id)
    if player.is_empty():
        return
    var dialog = Window.new()
    dialog.title = "Предложение контракта"
    dialog.transient = true
    dialog.exclusive = true
    dialog.size = Vector2i(600, 390)
    add_child(dialog)
    var panel = PanelContainer.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    panel.add_theme_stylebox_override("panel", _panel_style(Color("0d1b29"), colors.cyan, 10, 1))
    dialog.add_child(panel)
    var root = VBoxContainer.new()
    root.add_theme_constant_override("separation", 12)
    panel.add_child(root)
    root.add_child(_label("Покупка: %s" % player.get("name", "Игрок"), 22, colors.text))
    root.add_child(_label("Трансферная стоимость: %s" % _money(_purchase_price(player_id)), 15, colors.mint))
    root.add_child(_label("Выберите срок соглашения от 1 до 6 лет. Более длинный контракт немного повышает зарплату.", 13, colors.muted))
    var row = HBoxContainer.new()
    row.add_theme_constant_override("separation", 12)
    root.add_child(row)
    row.add_child(_label("Срок контракта:", 14, colors.text))
    var years = OptionButton.new()
    for value in range(1, MAX_CONTRACT_YEARS + 1):
        years.add_item("%d год(а)" % value, value)
    years.select(2)
    _style_option_button(years, 180)
    row.add_child(years)
    var spacer = Control.new()
    spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(spacer)
    var buttons = HBoxContainer.new()
    buttons.add_theme_constant_override("separation", 10)
    root.add_child(buttons)
    var cancel = _button("ОТМЕНА")
    cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    cancel.pressed.connect(_close_window.bind(dialog))
    buttons.add_child(cancel)
    var confirm = _button("ПОДПИСАТЬ", true)
    confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    confirm.pressed.connect(_confirm_contract_offer.bind(player_id, years, dialog))
    buttons.add_child(confirm)
    dialog.close_requested.connect(_close_window.bind(dialog))
    dialog.popup_centered()

func _confirm_contract_offer(player_id: int, years: OptionButton, dialog: Window) -> void:
    var contract_years = int(years.get_selected_id())
    _close_window(dialog)
    _buy_player(player_id, contract_years)

func _played_user_matches() -> int:
    var result = 0
    for fixture in fixtures:
        if bool(fixture.get("played", false)) and (int(fixture.get("home", -1)) == selected_team_id or int(fixture.get("away", -1)) == selected_team_id):
            result += 1
    return result

func _transfer_window_status() -> Dictionary:
    var played = _played_user_matches()
    var total = 0
    for fixture in fixtures:
        if int(fixture.get("home", -1)) == selected_team_id or int(fixture.get("away", -1)) == selected_team_id:
            total += 1
    var half = int(total / 2)
    if played <= 1:
        return {"open": true, "name": "summer", "text": "Летнее трансферное окно открыто"}
    if played >= half and played <= half + 1:
        return {"open": true, "name": "winter", "text": "Зимнее трансферное окно открыто"}
    return {"open": false, "name": "closed", "text": "Трансферное окно закрыто"}

func _sell_player(player_id: int, price: int) -> void:
    if not _squad_has_player(selected_team_id, player_id):
        notice_text = "Игрок уже не принадлежит вашему клубу."
        _show_dashboard("transfers")
        return
    if not bool(_transfer_window_status().get("open", false)):
        notice_text = "Продажа недоступна: трансферное окно закрыто."
        _show_dashboard("transfers")
        return
    if _is_important_player(player_id):
        notice_text = "Важный игрок защищён от продажи. Сначала снимите этот статус."
        _show_dashboard("transfers")
        return
    if _squad(selected_team_id).size() <= 14: return
    _detach_player_from_all_clubs(player_id)
    _remove_player_from_transfer_system(player_id)
    game_state["budget"] = int(game_state.get("budget", 0)) + price
    var market: Array = game_state.get("market_ids", [])
    if player_id not in market: market.append(player_id)
    game_state["market_ids"] = market
    _remove_from_lineup(player_id)
    notice_text = "%s продан за %s." % [_player(player_id).get("name", "Игрок"), _money(price)]
    _show_dashboard("transfers")

func _initial_ai_budgets() -> Dictionary:
    var result: Dictionary = {}
    for team in database.get("teams", []):
        var team_id = int(team.get("id", -1))
        if team_id != selected_team_id:
            result[str(team_id)] = int(team.get("budget", 0))
    return result

func _process_ai_transfer_window(window_name: String) -> void:
    if game_state.is_empty():
        return
    var season_key = "%d_%s" % [int(game_state.get("season", 1)), window_name]
    var markers: Dictionary = game_state.get("ai_window_actions", {})
    if bool(markers.get(season_key, false)):
        return
    var market: Array = game_state.get("market_ids", []).duplicate()
    var budgets: Dictionary = game_state.get("ai_budgets", {})
    for team in _playable_teams():
        var team_id = int(team.get("id", -1))
        if team_id == selected_team_id:
            continue
        var squad: Array = _squad(team_id).duplicate()
        var budget = int(budgets.get(str(team_id), int(team.get("budget", 0))))
        var weakest = _ai_weakest_position(team_id)
        var candidates: Array = []
        for raw_id in market:
            var player = _player(int(raw_id))
            if player.is_empty() or bool(player.get("retired", false)) or int(player.get("value", 0)) > budget:
                continue
            if weakest in _normalize_positions(player) or _role_fit(player, [weakest]) >= 0.80:
                candidates.append(int(raw_id))
        candidates.sort_custom(func(a, b): return int(_player(a).get("rating", 0)) > int(_player(b).get("rating", 0)))
        if not candidates.is_empty() and rng.randf() < 0.78:
            var bought = int(candidates[0])
            var price = int(_player(bought).get("value", 0))
            squad.append(bought)
            market.erase(bought)
            budget -= price
            _player(bought)["contract_years"] = rng.randi_range(2, 5)
        if squad.size() > 22 and rng.randf() < 0.55:
            var surplus = _ai_surplus_player(team_id, squad)
            if surplus >= 0:
                squad.erase(surplus)
                if surplus not in market:
                    market.append(surplus)
                budget += int(float(_player(surplus).get("value", 0)) * 0.70)
        if squad.size() > 20 and rng.randf() < 0.35:
            var loan_candidate = _ai_loan_candidate(squad)
            if loan_candidate >= 0:
                squad.erase(loan_candidate)
                var ai_loans: Dictionary = game_state.get("ai_loans", {})
                ai_loans[str(loan_candidate)] = {"owner": team_id, "return_season": int(game_state.get("season", 1)) + 1}
                game_state["ai_loans"] = ai_loans
        club_squads[str(team_id)] = squad
        budgets[str(team_id)] = budget
    game_state["market_ids"] = market
    game_state["ai_budgets"] = budgets
    markers[season_key] = true
    game_state["ai_window_actions"] = markers

func _ai_weakest_position(team_id: int) -> String:
    var roles = ["GK", "RB", "LB", "CB", "DM", "CM", "AM", "RW", "LW", "ST"]
    var weakest = "CM"
    var weakest_score = 999.0
    for role in roles:
        var best = 0
        for raw_id in _match_squad(team_id):
            var player = _player(int(raw_id))
            if _is_player_unavailable(player):
                continue
            var score = int(round(float(player.get("rating", 0)) * _role_fit(player, [role])))
            best = max(best, score)
        if best < weakest_score:
            weakest_score = best
            weakest = role
    return weakest

func _ai_loan_candidate(squad: Array) -> int:
    var candidates: Array = []
    for raw_id in squad:
        var player = _player(int(raw_id))
        if int(player.get("age", 99)) <= 22 and int(player.get("rating", 99)) <= 76 and not _is_goalkeeper(player):
            candidates.append(int(raw_id))
    candidates.sort_custom(func(a, b): return int(_player(a).get("rating", 0)) < int(_player(b).get("rating", 0)))
    return int(candidates[0]) if not candidates.is_empty() else -1

func _ai_surplus_player(team_id: int, squad: Array) -> int:
    var ranked = squad.duplicate()
    ranked.sort_custom(func(a,b): return int(_player(a).get("rating",0)) > int(_player(b).get("rating",0)))
    var protected: Array = ranked.slice(0, min(3, ranked.size()))
    var candidates: Array = []
    for raw_id in squad:
        var player = _player(int(raw_id))
        if player.is_empty() or _is_goalkeeper(player) or int(raw_id) in protected:
            continue
        if int(player.get("age",20)) < 23:
            continue
        if str(player.get("squad_level","first")) == "first" and int(player.get("rating",0)) >= int(_team(team_id).get("strength_seed",70)):
            continue
        candidates.append(int(raw_id))
    candidates.sort_custom(func(a,b): return int(_player(a).get("rating",0)) < int(_player(b).get("rating",0)))
    return int(candidates[0]) if not candidates.is_empty() else -1

func _country_league_ids(country: String) -> Dictionary:
    var result = {"top": "", "second": ""}
    for league in database.get("leagues", []):
        if str(league.get("country", "")) != country:
            continue
        if int(league.get("tier", 1)) == 1:
            result["top"] = str(league.get("id", ""))
        elif int(league.get("tier", 1)) == 2:
            result["second"] = str(league.get("id", ""))
    return result

func _initialize_cup_competitions() -> void:
    var cups: Dictionary = {}
    var user_team = _team(selected_team_id)
    var country = str(user_team.get("country", ""))
    var country_teams: Array = []
    for team in database.get("teams", []):
        if str(team.get("country", "")) == country:
            country_teams.append(int(team.get("id", -1)))
    country_teams.erase(selected_team_id)
    country_teams.shuffle()
    cups["domestic"] = {"name": "%s — Национальный кубок" % country, "active": true, "eliminated": false, "round_index": 0, "round_names": ["1/32 финала", "1/16 финала", "1/8 финала", "Четвертьфинал", "Полуфинал", "Финал"], "pool": country_teams, "champion": -1}

    var tier = int(user_team.get("tier", 1))
    var seed = int(user_team.get("rank_seed", 99))
    var last_place = int(game_state.get("last_season_place", 0))
    var qualifies_champions = tier == 1 and ((int(game_state.get("season", 1)) == 1 and seed <= 4) or (last_place > 0 and last_place <= 4))
    var qualifies_uefa = tier == 1 and not qualifies_champions and ((int(game_state.get("season", 1)) == 1 and seed <= 8) or (last_place >= 5 and last_place <= 8))
    if qualifies_champions:
        cups["champions"] = _make_european_cup_state("Кубок чемпионов Европы", "champions")
    elif qualifies_uefa:
        cups["uefa"] = _make_european_cup_state("Кубок УЕФА", "uefa")
    game_state["cups"] = cups
    _schedule_next_cup_fixture("domestic")
    if cups.has("champions"):
        _schedule_next_cup_fixture("champions")
    if cups.has("uefa"):
        _schedule_next_cup_fixture("uefa")

func _make_european_cup_state(name: String, kind: String) -> Dictionary:
    var candidates: Array = []
    for team in database.get("teams", []):
        if int(team.get("tier", 1)) != 1 or int(team.get("id", -1)) == selected_team_id:
            continue
        var rank = int(team.get("rank_seed", 99))
        if (kind == "champions" and rank <= 4) or (kind == "uefa" and rank >= 4 and rank <= 9):
            candidates.append(int(team.get("id", -1)))
    candidates.sort_custom(func(a, b): return float(_team(int(a)).get("strength_seed", 60)) > float(_team(int(b)).get("strength_seed", 60)))
    candidates = candidates.slice(0, min(31, candidates.size()))
    candidates.shuffle()
    return {"name": name, "active": true, "eliminated": false, "round_index": 0, "round_names": ["1/16 финала", "1/8 финала", "Четвертьфинал", "Полуфинал", "Финал"], "pool": candidates, "champion": -1}

func _cup_schedule_order(cup_key: String, round_index: int) -> int:
    var domestic_orders = [45, 95, 145, 205, 265, 325]
    var europe_orders = [65, 125, 185, 245, 315]
    var source = domestic_orders if cup_key == "domestic" else europe_orders
    return int(source[min(round_index, source.size() - 1)])

func _schedule_next_cup_fixture(cup_key: String) -> void:
    var cups: Dictionary = game_state.get("cups", {})
    if not cups.has(cup_key):
        return
    var cup: Dictionary = cups[cup_key]
    if bool(cup.get("eliminated", false)) or not bool(cup.get("active", true)):
        return
    var round_index = int(cup.get("round_index", 0))
    var round_names: Array = cup.get("round_names", [])
    if round_index >= round_names.size():
        return
    var pool: Array = cup.get("pool", [])
    if pool.is_empty():
        cup["champion"] = selected_team_id
        cup["active"] = false
        var trophies: Array = game_state.get("trophies", [])
        trophies.append({"season": int(game_state.get("season", 1)), "name": cup.get("name", "Кубок")})
        game_state["trophies"] = trophies
        cups[cup_key] = cup
        game_state["cups"] = cups
        return
    var opponent_index = rng.randi_range(0, pool.size() - 1)
    var opponent = int(pool[opponent_index])
    pool.remove_at(opponent_index)
    cup["pool"] = pool
    cups[cup_key] = cup
    game_state["cups"] = cups
    var user_home = rng.randf() < 0.5
    var fixture = {"round": 0, "calendar_order": _cup_schedule_order(cup_key, round_index), "competition_type": "cup", "cup_key": cup_key, "competition_name": str(cup.get("name", "Кубок")), "round_name": str(round_names[round_index]), "home": selected_team_id if user_home else opponent, "away": opponent if user_home else selected_team_id, "played": false, "home_score": 0, "away_score": 0}
    fixture["index"] = fixtures.size()
    fixtures.append(fixture)

func _resolve_cup_fixture(fixture_index: int) -> void:
    if fixture_index < 0 or fixture_index >= fixtures.size():
        return
    var fixture: Dictionary = fixtures[fixture_index]
    var cup_key = str(fixture.get("cup_key", "domestic"))
    var cups: Dictionary = game_state.get("cups", {})
    if not cups.has(cup_key):
        return
    var cup: Dictionary = cups[cup_key]
    var home_score = int(fixture.get("home_score", 0))
    var away_score = int(fixture.get("away_score", 0))
    var winner = int(fixture.get("home", -1)) if home_score > away_score else int(fixture.get("away", -1))
    if home_score == away_score:
        var user_power = _team_match_power(selected_team_id)
        var opponent_id = int(fixture.get("away", -1)) if int(fixture.get("home", -1)) == selected_team_id else int(fixture.get("home", -1))
        var penalty_chance = clamp(0.50 + (user_power - _team_match_power(opponent_id)) / 160.0, 0.32, 0.68)
        winner = selected_team_id if rng.randf() < penalty_chance else opponent_id
        fixture["penalty_winner"] = winner
        fixtures[fixture_index] = fixture
        _add_match_event("После ничьей победитель определён в серии пенальти: %s." % _team_name(winner))
    if winner != selected_team_id:
        cup["eliminated"] = true
        cup["active"] = false
    else:
        cup["round_index"] = int(cup.get("round_index", 0)) + 1
        if int(cup["round_index"]) >= (cup.get("round_names", []) as Array).size():
            cup["champion"] = selected_team_id
            cup["active"] = false
            var trophies: Array = game_state.get("trophies", [])
            trophies.append({"season": int(game_state.get("season", 1)), "name": cup.get("name", "Кубок")})
            game_state["trophies"] = trophies
            var prize = 7000000 if cup_key == "domestic" else (18000000 if cup_key == "champions" else 11000000)
            game_state["budget"] = int(game_state.get("budget", 0)) + prize
            game_state["prize_income"] = int(game_state.get("prize_income", 0)) + prize
            _add_match_event("ТРОФЕЙ! %s выиграл %s. Призовые: %s." % [_team_name(selected_team_id), cup.get("name", "Кубок"), _money(prize)])
        else:
            cups[cup_key] = cup
            game_state["cups"] = cups
            _schedule_next_cup_fixture(cup_key)
            return
    cups[cup_key] = cup
    game_state["cups"] = cups

func _render_tournaments() -> void:
    content_area.add_child(_title("Кубковые турниры"))
    content_area.add_child(_label("Национальный кубок объединяет клубы обоих дивизионов. Европейские турниры используются в упрощённом формате эпохи 2003/04.", 13, colors.muted))
    var cups: Dictionary = game_state.get("cups", {})
    if cups.is_empty():
        content_area.add_child(_label("В текущем сезоне кубковые турниры ещё не сформированы.", 14, colors.muted))
    for cup_key in cups.keys():
        var cup: Dictionary = cups[cup_key]
        var panel = PanelContainer.new()
        panel.add_theme_stylebox_override("panel", _panel_style(Color("0d1f2d"), Color("31566b"), 8, 1))
        content_area.add_child(panel)
        var box = VBoxContainer.new()
        panel.add_child(box)
        box.add_child(_label(str(cup.get("name", "Кубок")), 19, colors.mint))
        var state_text = "Победитель" if int(cup.get("champion", -1)) == selected_team_id else ("Выбыли" if bool(cup.get("eliminated", false)) else "Участвуем")
        var round_names: Array = cup.get("round_names", [])
        var round_index = int(cup.get("round_index", 0))
        var round_text = "турнир завершён" if round_index >= round_names.size() else str(round_names[round_index])
        box.add_child(_label("Статус: %s · следующий этап: %s" % [state_text, round_text], 14, colors.warning if state_text == "Выбыли" else colors.text))
    var trophies: Array = game_state.get("trophies", [])
    content_area.add_child(_label("Трофеи карьеры", 20, colors.mint))
    if trophies.is_empty():
        content_area.add_child(_label("Трофеев пока нет.", 13, colors.muted))
    else:
        for trophy in trophies:
            content_area.add_child(_label("Сезон %d — %s" % [int(trophy.get("season", 1)), trophy.get("name", "Трофей")], 14, colors.warning))

func _apply_promotions_and_relegations() -> void:
    var world: Dictionary = game_state.get("world_leagues", {})
    var history: Array = game_state.get("promotion_history", [])
    var user_comp = str(_team(selected_team_id).get("competition", ""))
    var user_state: Dictionary = world.get(user_comp, {})
    var user_rows = _sorted_table_data(user_state.get("table", {}))
    for i in range(user_rows.size()):
        if int(user_rows[i].get("team_id", -1)) == selected_team_id:
            game_state["last_season_place"] = i + 1
            break
    var countries: Array = []
    for league in database.get("leagues", []):
        var country = str(league.get("country", ""))
        if country not in countries:
            countries.append(country)
    for country in countries:
        var ids = _country_league_ids(country)
        var top_comp = str(ids.get("top", ""))
        var second_comp = str(ids.get("second", ""))
        if top_comp.is_empty() or second_comp.is_empty() or not world.has(top_comp) or not world.has(second_comp):
            continue
        var top_rows = _sorted_table_data((world[top_comp] as Dictionary).get("table", {}))
        var second_rows = _sorted_table_data((world[second_comp] as Dictionary).get("table", {}))
        var count = min(PROMOTION_RELEGATION_PLACES, min(top_rows.size(), second_rows.size()))
        var relegated: Array = []
        var promoted: Array = []
        for i in range(count):
            relegated.append(int(top_rows[top_rows.size() - 1 - i].get("team_id", -1)))
            promoted.append(int(second_rows[i].get("team_id", -1)))
        for team_id in relegated:
            var team = _team(team_id)
            team["competition"] = second_comp
            team["tier"] = 2
            team["division"] = "Второй дивизион"
            team["league_name"] = _league_name(second_comp)
        for team_id in promoted:
            var team = _team(team_id)
            team["competition"] = top_comp
            team["tier"] = 1
            team["division"] = "Высший дивизион"
            team["league_name"] = _league_name(top_comp)
        history.append({"season": int(game_state.get("season", 1)), "country": country, "promoted": promoted, "relegated": relegated})
    game_state["promotion_history"] = history

func _render_season_finished() -> void:
    var season = int(game_state.get("season", 1))
    var total = int(game_state.get("seasons_total", 3))
    var final_rows = _sorted_table()
    var place = 0
    for i in range(final_rows.size()):
        if int(final_rows[i]["team_id"]) == selected_team_id:
            place = i + 1
            break
    var panel = PanelContainer.new()
    panel.add_theme_stylebox_override("panel", _panel_style(colors.panel, colors.cyan, 12, 1))
    content_area.add_child(panel)
    var box = VBoxContainer.new()
    box.add_theme_constant_override("separation", 14)
    panel.add_child(box)
    box.add_child(_label("Сезон %d завершён" % season, 24, colors.text))
    var award = _ensure_season_financial_award(place)
    box.add_child(_label("Итоговое место: %d. Побед: %d, ничьих: %d, поражений: %d." % [place, int(game_state.get("career_wins", 0)), int(game_state.get("career_draws", 0)), int(game_state.get("career_losses", 0))], 16, colors.mint))
    box.add_child(_label("Финансовая награда сезона: %s. Новый бюджет: %s." % [_money(award), _money(int(game_state.get("budget", 0)))], 15, colors.warning))
    _add_season_leaders(box, str(_team(selected_team_id).get("competition", "eng1_demo")))
    if season < total:
        var next = _button("НАЧАТЬ СЛЕДУЮЩИЙ СЕЗОН", true)
        next.pressed.connect(_next_season)
        box.add_child(next)
    else:
        box.add_child(_label("Карьера завершена. В полной версии здесь появится подробный отчёт тренера, трофеи и лучшие трансферы.", 14, colors.muted))
        var menu = _button("В ГЛАВНОЕ МЕНЮ", true)
        menu.pressed.connect(_show_main_menu)
        box.add_child(menu)

func _season_development_review() -> void:
    for key in players_by_id.keys():
        var player = players_by_id[key]
        if bool(player.get("retired", false)): continue
        var points = float(player.get("development_points", 0.0))
        var age = int(player.get("age", 25))
        var change = 0
        if points >= 5.0 and age <= 29: change = 1
        elif points <= -5.0 or (age >= 34 and float(player.get("career_avg_rating", 6.5)) < 6.2): change = -1
        if age <= 21 and points >= 11.0 and rng.randf() < 0.30: change = 2
        if change != 0:
            player["rating"] = clamp(int(player.get("rating", 60)) + change, 40, 96)
            player["value"] = max(100000, int(float(player.get("value", 1000000)) * (1.10 if change > 0 else 0.88)))
        player["development_points"] = points * 0.30

func _process_retirements() -> void:
    var retired: Array = game_state.get("retired_players", [])
    for key in players_by_id.keys():
        var player_id = int(key)
        var player = players_by_id[key]
        if bool(player.get("retired", false)): continue
        var age = int(player.get("age", 25))
        var severe = int(player.get("severe_injuries", 0))
        var avg = float(player.get("career_avg_rating", 6.5))
        var chance = 0.0
        if age < 30 and severe >= 3 and avg < 5.9: chance = 0.10
        elif age >= 30 and age <= 34: chance = 0.025 * float(age - 29) + (0.08 if avg < 6.0 else 0.0)
        elif age >= 35 and age <= 37: chance = 0.28 + 0.13 * float(age - 35)
        elif age >= 38 and age < 39: chance = 0.72
        elif age >= 39: chance = 1.0
        if rng.randf() < chance:
            player["retired"] = true
            for team_key in club_squads.keys(): club_squads[team_key].erase(player_id)
            var market: Array = game_state.get("market_ids", []); market.erase(player_id); game_state["market_ids"] = market
            retired.append({"player_id": player_id, "season": int(game_state.get("season", 1)), "age": age})
    game_state["retired_players"] = retired
    _sanitize_lineup()

func _return_ai_loans() -> void:
    var loans: Dictionary = game_state.get("ai_loans", {})
    var returned: Array = []
    for key in loans.keys():
        var loan: Dictionary = loans[key]
        if int(loan.get("return_season", 999)) <= int(game_state.get("season", 1)):
            var player_id = int(key)
            var owner = str(int(loan.get("owner", -1)))
            if player_id not in club_squads.get(owner, []): club_squads[owner].append(player_id)
            returned.append(str(key))
    for key in returned: loans.erase(key)
    game_state["ai_loans"] = loans

func _next_season() -> void:
    _season_development_review()
    _process_retirements()
    _apply_promotions_and_relegations()
    game_state["season"] = int(game_state.get("season", 1)) + 1
    current_match.clear()
    _return_loans()
    _return_ai_loans()
    _advance_contracts()
    for key in players_by_id.keys():
        var player = players_by_id[key]
        if bool(player.get("retired", false)): continue
        player["age"] = int(player.get("age", 0)) + 1
        player["condition"] = 100 if not _is_player_injured(player) else min(75, int(player.get("condition", 70)))
        player["morale"] = 75
        player["rating_changes_season"] = 0
        player["last_rating_change_round"] = -99
    _reset_player_stats()
    game_state["season_sponsor_income"] = 0
    game_state["lineup_confirmed"] = true
    game_state["development_round"] = 0
    _sanitize_lineup()
    _start_season()
    notice_text = "Начался сезон %d. Контракты, аренды, развитие, травмы и завершения карьеры обработаны." % int(game_state.get("season", 1))
    _show_dashboard("club")

func _save_game() -> void:
    var save_data = {
        "selected_team_id": selected_team_id,
        "game_state": game_state,
        "lineup": lineup,
        "fixtures": fixtures,
        "league_table": league_table,
        "club_squads": club_squads,
        "players_by_id": players_by_id,
        "player_stats": player_stats,
        "current_match": current_match
    }
    var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        notice_text = "Не удалось записать сохранение."
    else:
        file.store_string(JSON.stringify(save_data))
        notice_text = "Карьера сохранена."
    _show_dashboard("club")

func _load_game() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
    var parsed = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary:
        return

    teams_by_id.clear()
    players_by_id.clear()
    club_squads.clear()
    _load_database()

    selected_team_id = int(parsed.get("selected_team_id", -1))
    game_state = parsed.get("game_state", {})
    if not game_state.has("transfer_search"):
        game_state["transfer_search"] = ""
    if not game_state.has("academy_promotions") or not game_state.get("academy_promotions") is Array:
        game_state["academy_promotions"] = []
    if not game_state.has("lineup_confirmed"):
        game_state["lineup_confirmed"] = true
    if not game_state.has("position_training") or not game_state.get("position_training") is Dictionary:
        game_state["position_training"] = {}
    if not game_state.has("custom_positions") or not game_state.get("custom_positions") is Dictionary:
        game_state["custom_positions"] = {}
    if not game_state.has("custom_roles") or not game_state.get("custom_roles") is Dictionary:
        game_state["custom_roles"] = {}
    if not game_state.has("fullback_duty"):
        game_state["fullback_duty"] = "Поддержка"
    if not game_state.has("sponsor_id"):
        game_state["sponsor_id"] = "balanced"
    if not game_state.has("sponsor_income"):
        game_state["sponsor_income"] = 0
    if not game_state.has("season_sponsor_income"):
        game_state["season_sponsor_income"] = 0
    if not game_state.has("prize_income"):
        game_state["prize_income"] = 0
    if not game_state.has("season_awards_paid") or not game_state.get("season_awards_paid") is Array:
        game_state["season_awards_paid"] = []
    if not game_state.has("season_award_amounts") or not game_state.get("season_award_amounts") is Dictionary:
        game_state["season_award_amounts"] = {}
    if not game_state.has("loans_out") or not game_state.get("loans_out") is Dictionary:
        game_state["loans_out"] = {}
    if not game_state.has("ai_loans") or not game_state.get("ai_loans") is Dictionary:
        game_state["ai_loans"] = {}
    if not game_state.has("ai_budgets") or not game_state.get("ai_budgets") is Dictionary:
        game_state["ai_budgets"] = _initial_ai_budgets()
    if not game_state.has("ai_window_actions") or not game_state.get("ai_window_actions") is Dictionary:
        game_state["ai_window_actions"] = {}
    if not game_state.has("retired_players") or not game_state.get("retired_players") is Array:
        game_state["retired_players"] = []
    if not game_state.has("development_round"):
        game_state["development_round"] = 0
    if not game_state.has("winter_window_processed"):
        game_state["winter_window_processed"] = false
    if not game_state.has("important_players") or not game_state.get("important_players") is Array:
        game_state["important_players"] = []
    if not game_state.has("set_piece_takers") or not game_state.get("set_piece_takers") is Dictionary:
        game_state["set_piece_takers"] = {}
    if not game_state.has("transfer_listed") or not game_state.get("transfer_listed") is Array:
        game_state["transfer_listed"] = []
    if not game_state.has("incoming_offers") or not game_state.get("incoming_offers") is Array:
        game_state["incoming_offers"] = []
    if not game_state.has("transfer_offer_history") or not game_state.get("transfer_offer_history") is Array:
        game_state["transfer_offer_history"] = []
    if not game_state.has("last_transfer_offer_round"):
        game_state["last_transfer_offer_round"] = -99
    if not game_state.has("selected_world_competition"):
        game_state["selected_world_competition"] = str(_team(selected_team_id).get("competition", "eng1_demo"))
    if not game_state.has("world_leagues") or not game_state.get("world_leagues") is Dictionary:
        game_state["world_leagues"] = {}
    if not game_state.has("cups") or not game_state.get("cups") is Dictionary:
        game_state["cups"] = {}
    if not game_state.has("trophies") or not game_state.get("trophies") is Array:
        game_state["trophies"] = []
    if not game_state.has("promotion_history") or not game_state.get("promotion_history") is Array:
        game_state["promotion_history"] = []
    if not game_state.has("last_season_place"):
        game_state["last_season_place"] = 0
    if not game_state.has("data_revision"):
        game_state["data_revision"] = 0
    lineup = parsed.get("lineup", {})
    fixtures = parsed.get("fixtures", [])
    league_table = parsed.get("league_table", {})

    var saved_players: Dictionary = parsed.get("players_by_id", {})
    for key in saved_players.keys():
        var player_key = str(key)
        # Не возвращаем удалённые из базы дубли из старых сохранений.
        if not players_by_id.has(player_key):
            continue
        var merged: Dictionary = players_by_id.get(player_key, {}).duplicate(true)
        var saved: Dictionary = saved_players[key]
        for field in saved.keys():
            if str(field) != "secondary":
                merged[field] = saved[field]
        var secondary: Array = merged.get("secondary", []).duplicate()
        for position in saved.get("secondary", []):
            var normalized = str(position).strip_edges().to_upper()
            if not normalized.is_empty() and normalized != str(merged.get("position", "")).to_upper() and normalized not in secondary:
                secondary.append(normalized)
        merged["secondary"] = secondary
        merged["contract_years"] = int(merged.get("contract_years", 2))
        merged["wage_weekly"] = int(merged.get("wage_weekly", max(1000, int(merged.get("rating", 60)) * 250)))
        var legacy_saved_injury_matches = int(merged.get("injured_matches", 0))
        merged["injury_days"] = int(merged.get("injury_days", legacy_saved_injury_matches * MATCH_DAYS_STEP))
        merged["injured_matches"] = int(ceil(float(merged["injury_days"]) / float(MATCH_DAYS_STEP)))
        merged["injury_name"] = str(merged.get("injury_name", ""))
        merged["injury_details"] = str(merged.get("injury_details", merged.get("injury_name", "")))
        merged["injury_severity"] = str(merged.get("injury_severity", ""))
        merged["injury_history"] = int(merged.get("injury_history", 0))
        merged["severe_injuries"] = int(merged.get("severe_injuries", 0))
        merged["suspended_matches"] = int(merged.get("suspended_matches", 0))
        merged["suspension_reason"] = str(merged.get("suspension_reason", ""))
        merged["development_points"] = float(merged.get("development_points", 0.0))
        merged["rating_changes_season"] = int(merged.get("rating_changes_season", 0))
        merged["last_rating_change_round"] = int(merged.get("last_rating_change_round", -99))
        merged["retired"] = bool(merged.get("retired", false))
        merged["career_avg_rating"] = float(merged.get("career_avg_rating", 6.5))
        merged["career_rating_apps"] = int(merged.get("career_rating_apps", 0))
        merged["career_club_stats"] = merged.get("career_club_stats", {}) if merged.get("career_club_stats", {}) is Dictionary else {}
        merged["career_total_apps"] = int(merged.get("career_total_apps", 0))
        merged["career_total_goals"] = int(merged.get("career_total_goals", 0))
        merged["career_total_assists"] = int(merged.get("career_total_assists", 0))
        merged["career_total_clean_sheets"] = int(merged.get("career_total_clean_sheets", 0))
        merged["career_total_conceded"] = int(merged.get("career_total_conceded", 0))
        players_by_id[player_key] = merged

    var saved_squads: Dictionary = parsed.get("club_squads", {})
    for key in saved_squads.keys():
        var cleaned_saved: Array = []
        for raw_id in saved_squads[key]:
            var saved_id = int(raw_id)
            if players_by_id.has(str(saved_id)) and saved_id not in cleaned_saved:
                cleaned_saved.append(saved_id)
        club_squads[str(key)] = cleaned_saved

    # Игрок, перешедший в другой клуб в сохранении, не должен снова
    # добавляться в исходную команду из статической базы.
    var saved_owned: Dictionary = {}
    for saved_squad in club_squads.values():
        for raw_id in saved_squad:
            saved_owned[str(int(raw_id))] = true
    for team in database.get("teams", []):
        var team_key = str(int(team.get("id", -1)))
        var squad: Array = club_squads.get(team_key, []).duplicate(true)
        for player_id in team.get("players", []):
            var base_id = int(player_id)
            if not saved_owned.has(str(base_id)) and base_id not in squad:
                squad.append(base_id)
                saved_owned[str(base_id)] = true
        club_squads[team_key] = squad

    _clean_all_squad_duplicates()
    _rebuild_player_club_index()

    var owned: Dictionary = {}
    for squad in club_squads.values():
        for player_id in squad:
            owned[str(int(player_id))] = true
    var cleaned_market: Array = []
    for player_id in game_state.get("market_ids", database.get("market_players", [])):
        if not owned.has(str(int(player_id))):
            cleaned_market.append(int(player_id))
    game_state["market_ids"] = cleaned_market

    player_stats = parsed.get("player_stats", {})
    _ensure_player_stats()
    current_match = parsed.get("current_match", {})
    _normalize_current_match_lineups()
    _sanitize_lineup()
    game_state["lineup_confirmed"] = _lineup_is_valid()
    _clean_important_players()
    if (game_state.get("world_leagues", {}) as Dictionary).is_empty():
        _initialize_missing_world_leagues_from_current()
    _clean_transfer_list()
    _ensure_set_piece_assignments()
    notice_text = "Сохранение загружено и обновлено до версии v1.1.0."
    _show_dashboard("match" if not current_match.is_empty() else "club")

func _generate_fixtures(team_ids: Array) -> Array:
    var result: Array = []
    var teams = team_ids.duplicate()
    if teams.size() % 2 == 1:
        teams.append(-1)
    var n = teams.size()
    var first_half: Array = []
    for round_index in range(n - 1):
        for i in range(int(n / 2)):
            var home = int(teams[i])
            var away = int(teams[n - 1 - i])
            if home >= 0 and away >= 0:
                if round_index % 2 == 1:
                    var temp = home
                    home = away
                    away = temp
                first_half.append({"round": round_index + 1, "calendar_order": (round_index + 1) * 10, "competition_type": "league", "competition_name": _league_name(str(_team(home).get("competition", ""))), "home": home, "away": away, "played": false, "home_score": 0, "away_score": 0})
        var fixed = teams[0]
        var rest = teams.slice(1)
        rest.push_front(rest.pop_back())
        teams = [fixed]
        teams.append_array(rest)
    result.append_array(first_half)
    var second_round_start = n - 1
    for fixture in first_half:
        var return_round = int(fixture.get("round", 1)) + second_round_start
        result.append({"round": return_round, "calendar_order": return_round * 10, "competition_type": "league", "competition_name": str(fixture.get("competition_name", "Лига")), "home": int(fixture.get("away", -1)), "away": int(fixture.get("home", -1)), "played": false, "home_score": 0, "away_score": 0})
    for i in range(result.size()):
        result[i]["index"] = i
    return result

func _next_user_fixture() -> Dictionary:
    var candidates: Array = []
    for fixture in fixtures:
        if not bool(fixture.get("played", false)) and (int(fixture.get("home", -1)) == selected_team_id or int(fixture.get("away", -1)) == selected_team_id):
            candidates.append(fixture)
    candidates.sort_custom(func(a, b): return int(a.get("calendar_order", a.get("round", 999) * 10)) < int(b.get("calendar_order", b.get("round", 999) * 10)))
    return candidates[0] if not candidates.is_empty() else {}

func _simulate_other_fixtures(round_number: int, excluded_index: int) -> void:
    for i in range(fixtures.size()):
        if i == excluded_index:
            continue
        var fixture: Dictionary = fixtures[i]
        if str(fixture.get("competition_type", "league")) != "league" or int(fixture.get("round", -1)) != round_number or bool(fixture.get("played", false)):
            continue
        var home = int(fixture.get("home", -1))
        var away = int(fixture.get("away", -1))
        var home_goals = _quick_goals(_team_match_power(home), _team_match_power(away), true)
        var away_goals = _quick_goals(_team_match_power(away), _team_match_power(home), false)
        fixture["played"] = true
        fixture["home_score"] = home_goals
        fixture["away_score"] = away_goals
        fixtures[i] = fixture
        _apply_result(home, away, home_goals, away_goals)
        _record_quick_match_stats(home, away, home_goals, away_goals)

func _quick_goals(attack: float, defense: float, home: bool) -> int:
    var expectation = 1.08 + (attack - defense) / 29.0 + (0.20 if home else 0.0)
    expectation = clamp(expectation, 0.12, 3.15)
    var goals = 0
    for _chance in range(6):
        if rng.randf() < expectation / 6.0:
            goals += 1
    if rng.randf() < 0.025:
        goals += 1
    return min(goals, 6)

func _apply_result(home_id: int, away_id: int, home_goals: int, away_goals: int) -> void:
    var home: Dictionary = league_table[str(home_id)]
    var away: Dictionary = league_table[str(away_id)]
    home["p"] = int(home.get("p", 0)) + 1
    away["p"] = int(away.get("p", 0)) + 1
    home["gf"] = int(home.get("gf", 0)) + home_goals
    home["ga"] = int(home.get("ga", 0)) + away_goals
    away["gf"] = int(away.get("gf", 0)) + away_goals
    away["ga"] = int(away.get("ga", 0)) + home_goals
    if home_goals > away_goals:
        home["w"] = int(home.get("w", 0)) + 1
        home["pts"] = int(home.get("pts", 0)) + 3
        away["l"] = int(away.get("l", 0)) + 1
    elif home_goals < away_goals:
        away["w"] = int(away.get("w", 0)) + 1
        away["pts"] = int(away.get("pts", 0)) + 3
        home["l"] = int(home.get("l", 0)) + 1
    else:
        home["d"] = int(home.get("d", 0)) + 1
        away["d"] = int(away.get("d", 0)) + 1
        home["pts"] = int(home.get("pts", 0)) + 1
        away["pts"] = int(away.get("pts", 0)) + 1
    league_table[str(home_id)] = home
    league_table[str(away_id)] = away

func _sorted_table() -> Array:
    var rows: Array = []
    for team_id_key in league_table.keys():
        rows.append({"team_id": int(team_id_key), "stats": league_table[team_id_key]})
    rows.sort_custom(func(a, b):
        var sa: Dictionary = a["stats"]
        var sb: Dictionary = b["stats"]
        if int(sa.get("pts", 0)) != int(sb.get("pts", 0)):
            return int(sa.get("pts", 0)) > int(sb.get("pts", 0))
        return int(sa.get("gf", 0)) - int(sa.get("ga", 0)) > int(sb.get("gf", 0)) - int(sb.get("ga", 0))
    )
    return rows

func _auto_pick_lineup(formation_name: String) -> Dictionary:
    var result: Dictionary = {}
    var available: Array = []
    for raw_id in _match_squad(selected_team_id):
        var player = _player(int(raw_id))
        if not _is_player_unavailable(player) and not bool(player.get("retired", false)):
            available.append(int(raw_id))
    for raw_slot in _formations().get(formation_name, []):
        var slot = _dynamic_slot_data(raw_slot)
        var best_id = -1
        var best_score = -999.0
        for player_id in available:
            var player = _player(int(player_id))
            var fit = _role_fit(player, slot.get("accepted", []))
            var score = float(player.get("rating", 0)) * fit + float(player.get("condition", 100)) * 0.04 + float(player.get("morale", 75)) * 0.02
            if score > best_score:
                best_score = score
                best_id = int(player_id)
        if best_id >= 0:
            result[str(slot.get("id", ""))] = best_id
            available.erase(best_id)
    return result

func _normalize_positions(player: Dictionary) -> Array:
    var result: Array = []
    var primary = str(player.get("position", "")).strip_edges().to_upper()
    if not primary.is_empty():
        result.append(primary)
    for raw_position in player.get("secondary", []):
        var position = str(raw_position).strip_edges().to_upper()
        if not position.is_empty() and position not in result:
            result.append(position)
    return result

func _is_goalkeeper(player: Dictionary) -> bool:
    return "GK" in _normalize_positions(player)

func _role_fit(player: Dictionary, accepted: Array) -> float:
    var primary = str(player.get("position", "")).strip_edges().to_upper()
    var secondary: Array = []
    for raw_position in player.get("secondary", []):
        var position = str(raw_position).strip_edges().to_upper()
        if position != primary and position not in secondary:
            secondary.append(position)

    var accepts_goalkeeper = "GK" in accepted
    if accepts_goalkeeper:
        if primary == "GK": return 1.0
        if "GK" in secondary: return 0.90
        return 0.05
    if primary == "GK": return 0.20
    if primary in accepted: return 1.0
    for position in secondary:
        if position in accepted: return 0.92

    var adjacent: Dictionary = {
        "RB": ["CB", "RWB", "RM"], "RWB": ["RB", "RM", "RW"],
        "LB": ["CB", "LWB", "LM"], "LWB": ["LB", "LM", "LW"],
        "CB": ["RB", "LB", "DM"], "DM": ["CM", "CB"],
        "CM": ["DM", "AM", "RM", "LM"], "AM": ["CM", "CF", "ST", "RW", "LW"],
        "RM": ["RW", "CM", "RWB", "RB"], "LM": ["LW", "CM", "LWB", "LB"],
        "RW": ["RM", "RWB", "LW", "CF", "ST", "AM"], "LW": ["LM", "LWB", "RW", "CF", "ST", "AM"],
        "CF": ["ST", "AM", "RW", "LW"], "ST": ["CF", "AM", "RW", "LW"]
    }
    for accepted_position in accepted:
        if str(accepted_position) in adjacent.get(primary, []): return 0.80
    return 0.62

func _effective_rating_for_slot(player: Dictionary, accepted: Array) -> int:
    return int(round(float(player.get("rating", 0)) * _role_fit(player, accepted)))

func _fit_description(player: Dictionary, accepted: Array) -> String:
    var fit = _role_fit(player, accepted)
    if fit >= 0.995:
        return "родная позиция"
    if fit >= 0.90:
        return "доп. позиция · −8%"
    if fit >= 0.79:
        return "смежная роль · −20%"
    if fit <= 0.21:
        return "не подходит · −80%"
    return "чужая позиция · −38%"

func _formation_slot(slot_id: String) -> Dictionary:
    for slot in _formations().get(str(game_state.get("formation", "4-4-2")), []):
        if str(slot.get("id", "")) == slot_id:
            return _dynamic_slot_data(slot)
    return {}

func _squad_has_player(team_id: int, player_id: int) -> bool:
    for squad_player_id in _squad(team_id):
        if int(squad_player_id) == player_id:
            return true
    return false

func _user_team_power() -> float:
    if lineup.is_empty():
        return 0.0
    var formation_slots: Array = _formations().get(str(game_state.get("formation", "4-4-2")), [])
    var total = 0.0
    var count = 0
    for raw_slot in formation_slots:
        var slot = _dynamic_slot_data(raw_slot)
        var slot_id = str(slot.get("id", ""))
        var player_id = int(lineup.get(slot_id, -1))
        if player_id < 0:
            continue
        var player = _player(player_id)
        var fit = _role_fit(player, slot.get("accepted", []))
        var effective = float(player.get("rating", 0)) * fit
        effective *= 0.75 + float(player.get("condition", 100)) / 400.0
        effective *= 0.90 + float(player.get("morale", 75)) / 750.0
        total += effective
        count += 1
    var average = total / max(1, count)
    match str(game_state.get("tactical_style", "Сбалансированно")):
        "Атака": average += 1.2
        "Оборона": average += 0.5
        "Прессинг": average += 0.9
        "Контратака": average += 0.7
        "Глубокая оборона + контратака": average -= 0.3
    return average

func _team_match_power(team_id: int) -> float:
    var average = 0.0
    if team_id == selected_team_id:
        average = _user_team_power()
    else:
        var starting_ids = _team_on_pitch_player_ids(team_id) if not current_match.is_empty() and team_id in [int(current_match.get("home", -1)), int(current_match.get("away", -1))] else _team_starting_ids(team_id)
        var total = 0.0
        for player_id in starting_ids:
            var player = _player(int(player_id))
            var condition_factor = 0.74 + float(player.get("condition", 100)) / 385.0
            total += float(player.get("rating", 0)) * condition_factor
        average = total / max(1, starting_ids.size())
        var team = _team(team_id)
        average += float(team.get("coach_attack", 1.0)) * 0.35 + float(team.get("coach_defense", 1.0)) * 0.35
    if not current_match.is_empty():
        if _captain_is_active(team_id):
            average += 0.45
        var sent_off = _sent_off_count(team_id)
        var injured = _injured_on_pitch_count(team_id)
        var red_penalty = 7.8 * sent_off
        if _team_tactical_style(team_id) == "Глубокая оборона + контратака": red_penalty *= 0.72
        average -= red_penalty + 2.8 * injured
    return average

func _team_base_rating(team_id: int) -> int:
    return int(round(_team_match_power(team_id)))

func _pick_attacking_player(team_id: int, exclude_id = -1) -> Dictionary:
    return _weighted_player_pick(_active_team_player_ids(team_id), team_id, "goal", int(exclude_id))

func _add_match_event(text_value: String) -> void:
    var events: Array = current_match.get("events", [])
    events.append(text_value)
    current_match["events"] = events

func _current_match_minute() -> int:
    var index = int(current_match.get("segment_index", 0))
    if index <= 0:
        return 0
    return int(SEGMENTS[min(index - 1, SEGMENTS.size() - 1)])

func _select_tactics_player(player_id: int) -> void:
    if player_id < 0:
        return
    if not current_match.is_empty() and player_id not in lineup.values():
        selected_tactics_player_id = -1
        notice_text = "Во время матча футболиста со скамейки можно выпустить только через официальную замену."
    else:
        selected_tactics_player_id = player_id
        notice_text = "Выбран %s. Нажмите нужную позицию на поле или перетащите карточку." % _player(player_id).get("name", "Игрок")
    _show_dashboard("tactics")

func _tactics_slot_clicked(slot_id: String) -> void:
    if selected_tactics_player_id >= 0:
        _player_dropped(selected_tactics_player_id, slot_id)
        return
    var player_id = int(lineup.get(slot_id, -1))
    if player_id >= 0:
        selected_tactics_player_id = player_id
        notice_text = "Выбран %s. Теперь нажмите другую позицию, чтобы переставить или поменять игроков местами." % _player(player_id).get("name", "Игрок")
        _show_dashboard("tactics")

func _unique_player_ids(values: Array) -> Array:
    var result: Array = []
    var used: Dictionary = {}
    for value in values:
        var player_id = int(value)
        var key = str(player_id)
        if player_id >= 0 and _squad_has_player(selected_team_id, player_id) and not used.has(key):
            used[key] = true
            result.append(player_id)
    return result

func _lineup_from_player_pool(formation_name: String, player_ids: Array, allow_squad_fill: bool) -> Dictionary:
    var result: Dictionary = {}
    var remaining = _unique_player_ids(player_ids)
    if allow_squad_fill:
        for player_id in _match_squad(selected_team_id):
            if int(player_id) not in remaining:
                remaining.append(int(player_id))

    for slot in _formations().get(formation_name, []):
        var best_id = -1
        var best_score = -999.0
        for player_id in remaining:
            var player = _player(int(player_id))
            var fit = _role_fit(player, slot.get("accepted", []))
            var score = float(player.get("rating", 0)) * fit + float(player.get("condition", 100)) * 0.04 + float(player.get("morale", 75)) * 0.02
            if score > best_score:
                best_score = score
                best_id = int(player_id)
        if best_id >= 0:
            result[str(slot.get("id", ""))] = best_id
            remaining.erase(best_id)
    return result

func _sanitize_lineup() -> void:
    if selected_team_id < 0 or game_state.is_empty():
        return
    var formation_name = str(game_state.get("formation", "4-4-2"))
    var slots: Array = _formations().get(formation_name, [])
    var pool: Array = _team_on_pitch_player_ids(selected_team_id) if not current_match.is_empty() else _available_squad_player_ids(selected_team_id)
    var normalized_pool: Array = []
    for raw_id in pool:
        var player_id = int(raw_id)
        if player_id >= 0 and player_id not in normalized_pool and not _player(player_id).is_empty():
            normalized_pool.append(player_id)

    if lineup.is_empty() and not current_match.is_empty():
        var saved_before_match: Dictionary = current_match.get("pre_match_lineup", {})
        lineup = saved_before_match.duplicate(true)

    var repaired: Dictionary = {}
    var used: Dictionary = {}

    # Сохраняем корректные назначения пользователя. Ячейка вратаря всегда
    # принимает только настоящего голкипера, чтобы старые сохранения не
    # блокировали начало матча ложной ошибкой.
    for slot in slots:
        var slot_id = str(slot.get("id", ""))
        var player_id = int(lineup.get(slot_id, -1))
        if player_id < 0 or player_id not in normalized_pool or used.has(str(player_id)):
            continue
        var is_gk_slot = "GK" in slot.get("accepted", [])
        if is_gk_slot != _is_goalkeeper(_player(player_id)):
            continue
        repaired[slot_id] = player_id
        used[str(player_id)] = true

    var candidates: Array = []
    # Сначала используем футболистов, которых пользователь уже держал в схеме,
    # затем добавляем остальных доступных игроков.
    for raw_id in lineup.values():
        var player_id = int(raw_id)
        if player_id in normalized_pool and not used.has(str(player_id)) and player_id not in candidates:
            candidates.append(player_id)
    for player_id in normalized_pool:
        if not used.has(str(int(player_id))) and int(player_id) not in candidates:
            candidates.append(int(player_id))

    for slot in slots:
        var slot_id = str(slot.get("id", ""))
        if repaired.has(slot_id):
            continue
        var is_gk_slot = "GK" in slot.get("accepted", [])
        var best_id = -1
        var best_score = -9999.0
        for player_id in candidates:
            var player = _player(int(player_id))
            if is_gk_slot != _is_goalkeeper(player):
                continue
            var score = float(player.get("rating", 0)) * _role_fit(player, slot.get("accepted", []))
            score += float(player.get("condition", 100)) * 0.04 + float(player.get("morale", 75)) * 0.02
            if score > best_score:
                best_score = score
                best_id = int(player_id)
        if best_id >= 0:
            repaired[slot_id] = best_id
            used[str(best_id)] = true
            candidates.erase(best_id)

    lineup = repaired

func _empty_player_stat() -> Dictionary:
    return {"apps": 0, "goals": 0, "assists": 0, "clean_sheets": 0, "yellow": 0, "red": 0, "rating_sum": 0.0, "rating_apps": 0}

func _reset_player_stats() -> void:
    player_stats.clear()
    for key in players_by_id.keys():
        player_stats[str(key)] = _empty_player_stat()

func _ensure_player_stats() -> void:
    for key in players_by_id.keys():
        var stat_key = str(key)
        if not player_stats.has(stat_key) or not player_stats[stat_key] is Dictionary:
            player_stats[stat_key] = _empty_player_stat()
            continue
        var stats: Dictionary = player_stats[stat_key]
        for field in ["apps", "goals", "assists", "clean_sheets", "yellow", "red", "rating_apps"]:
            if not stats.has(field): stats[field] = 0
        if not stats.has("rating_sum"): stats["rating_sum"] = 0.0
        player_stats[stat_key] = stats

func _add_player_stat(player_id: int, field: String, amount: int) -> void:
    if player_id < 0 or _player(player_id).is_empty():
        return
    var key = str(player_id)
    if not player_stats.has(key):
        player_stats[key] = _empty_player_stat()
    var stats: Dictionary = player_stats[key]
    stats[field] = int(stats.get(field, 0)) + amount
    player_stats[key] = stats
    game_state["data_revision"] = int(game_state.get("data_revision", 0)) + 1
    statistics_cache.clear()

func _register_match_appearance(player_id: int) -> void:
    if player_id < 0:
        return
    var appeared: Array = current_match.get("appeared", [])
    if player_id in appeared:
        return
    appeared.append(player_id)
    current_match["appeared"] = appeared
    _add_player_stat(player_id, "apps", 1)

func _team_starting_ids(team_id: int) -> Array:
    if team_id == selected_team_id and not lineup.is_empty():
        return _unique_player_ids(lineup.values())
    var goalkeepers: Array = []
    var field_players: Array = []
    for player_id in _match_squad(team_id):
        var player = _player(int(player_id))
        if _is_player_unavailable(player) or bool(player.get("retired", false)):
            continue
        if str(player.get("position", "")) == "GK": goalkeepers.append(int(player_id))
        else: field_players.append(int(player_id))
    goalkeepers.sort_custom(func(a, b): return int(_player(a).get("rating", 0)) > int(_player(b).get("rating", 0)))
    var coach_formation = str(_team(team_id).get("coach_formation", "4-4-2"))
    var desired_roles: Array = []
    for slot in _formations().get(coach_formation, _formations().get("4-4-2", [])):
        var accepted: Array = slot.get("accepted", [])
        if not accepted.is_empty() and str(accepted[0]) != "GK": desired_roles.append(str(accepted[0]))
    var result: Array = []
    if not goalkeepers.is_empty(): result.append(int(goalkeepers[0]))
    var remaining = field_players.duplicate()
    for role in desired_roles:
        if result.size() >= 11: break
        var best_id = -1
        var best_score = -1.0
        for raw_id in remaining:
            var player = _player(int(raw_id))
            var score = float(player.get("rating", 0)) * _role_fit(player, [role])
            if score > best_score:
                best_score = score
                best_id = int(raw_id)
        if best_id >= 0:
            result.append(best_id)
            remaining.erase(best_id)
    remaining.sort_custom(func(a, b): return int(_player(a).get("rating", 0)) > int(_player(b).get("rating", 0)))
    for raw_id in remaining:
        if result.size() >= 11: break
        result.append(int(raw_id))
    return result

func _team_on_pitch_player_ids(team_id: int) -> Array:
    # Футболисты, которые формально остаются на поле. Травмированный игрок
    # остаётся здесь до подтверждённой замены, удалённый — удаляется сразу.
    var result: Array = []
    var source: Array = _team_starting_ids(team_id)
    if not current_match.is_empty():
        if team_id == int(current_match.get("home", -1)):
            source = current_match.get("home_lineup", source)
        elif team_id == int(current_match.get("away", -1)):
            source = current_match.get("away_lineup", source)
    var sent_off: Array = []
    if not current_match.is_empty():
        sent_off = current_match.get("home_sent_off", []) if team_id == int(current_match.get("home", -1)) else current_match.get("away_sent_off", [])
    for raw_id in source:
        var player_id = int(raw_id)
        if player_id >= 0 and player_id not in sent_off and player_id not in result:
            result.append(player_id)
    return result

func _active_team_player_ids(team_id: int) -> Array:
    # Реально участвующие в игровых эпизодах. Травмированный до замены
    # числится на поле, но не участвует в атаках и защите.
    var result: Array = []
    var injured: Array = []
    if not current_match.is_empty():
        injured = current_match.get("home_injured", []) if team_id == int(current_match.get("home", -1)) else current_match.get("away_injured", [])
    for raw_id in _team_on_pitch_player_ids(team_id):
        var player_id = int(raw_id)
        if player_id not in injured:
            result.append(player_id)
    return result

func _normalize_current_match_lineups() -> void:
    if current_match.is_empty():
        return
    for side in ["home", "away"]:
        var lineup_key = "%s_lineup" % side
        var sent_off_key = "%s_sent_off" % side
        var ids: Array = current_match.get(lineup_key, []).duplicate()
        for raw_id in current_match.get(sent_off_key, []):
            ids.erase(int(raw_id))
        current_match[lineup_key] = ids

func _sync_user_match_lineup_from_tactics() -> void:
    if current_match.is_empty() or selected_team_id < 0:
        return
    var key = "home_lineup" if selected_team_id == int(current_match.get("home", -1)) else "away_lineup"
    var sent_off_key = "home_sent_off" if selected_team_id == int(current_match.get("home", -1)) else "away_sent_off"
    var sent_off: Array = current_match.get(sent_off_key, [])
    var synced: Array = []
    for raw_id in lineup.values():
        var player_id = int(raw_id)
        if player_id >= 0 and player_id not in sent_off and player_id not in synced:
            synced.append(player_id)
    current_match[key] = synced

func _replace_current_match_player(team_id: int, out_player_id: int, in_player_id: int) -> void:
    var key = "home_lineup" if team_id == int(current_match.get("home", -1)) else "away_lineup"
    var ids: Array = current_match.get(key, []).duplicate()
    var index = ids.find(out_player_id)
    if index >= 0:
        ids[index] = in_player_id
    elif in_player_id not in ids:
        ids.append(in_player_id)
    current_match[key] = ids

func _pick_attacking_player_from_ids(source_ids: Array, exclude_id = -1) -> Dictionary:
    return _weighted_player_pick(source_ids, -1, "goal", int(exclude_id))

func _pick_card_player(team_id: int) -> Dictionary:
    var source_ids = _active_team_player_ids(team_id)
    var sent_off: Array = current_match.get("home_sent_off", []) if team_id == int(current_match.get("home", -1)) else current_match.get("away_sent_off", [])
    var candidates: Array = []
    for player_id in source_ids:
        var id = int(player_id)
        if id in sent_off:
            continue
        var player = _player(id)
        if player.is_empty() or str(player.get("position", "")) == "GK":
            continue
        var repetitions = 3 if str(player.get("position", "")) in ["CB", "LB", "RB", "LWB", "RWB", "DM"] else 1
        for _i in range(repetitions):
            candidates.append(player)
    return candidates[rng.randi_range(0, candidates.size() - 1)] if not candidates.is_empty() else {"name": "Игрок", "id": -1}

func _register_sent_off(team_id: int, player_id: int) -> void:
    var key = "home_sent_off" if team_id == int(current_match.get("home", -1)) else "away_sent_off"
    var sent_off: Array = current_match.get(key, [])
    if player_id not in sent_off:
        sent_off.append(player_id)
    current_match[key] = sent_off

    # Удалённый сразу покидает фактический список игроков матча. Благодаря
    # этому команда действительно остаётся в меньшинстве, а пустое место можно
    # перенести в другую линию перестройкой, но нельзя заполнить заменой.
    var lineup_key = "home_lineup" if team_id == int(current_match.get("home", -1)) else "away_lineup"
    var match_ids: Array = current_match.get(lineup_key, []).duplicate()
    match_ids.erase(player_id)
    current_match[lineup_key] = match_ids

    if team_id == selected_team_id:
        var remove_slot = ""
        for slot_id in lineup.keys():
            if int(lineup.get(slot_id, -1)) == player_id:
                remove_slot = str(slot_id)
                break
        if not remove_slot.is_empty():
            lineup.erase(remove_slot)

func _record_clean_sheet(team_id: int, goals_conceded: int, lineup_ids: Array) -> void:
    if goals_conceded != 0:
        return
    for player_id in lineup_ids:
        if _is_goalkeeper(_player(int(player_id))):
            _add_player_stat(int(player_id), "clean_sheets", 1)
            return

func _record_quick_match_stats(home_id: int, away_id: int, home_goals: int, away_goals: int) -> void:
    var home_ids = _team_starting_ids(home_id)
    var away_ids = _team_starting_ids(away_id)
    _update_quick_career_appearances(home_id, home_ids, away_goals)
    _update_quick_career_appearances(away_id, away_ids, home_goals)
    for player_id in home_ids:
        _add_player_stat(int(player_id), "apps", 1)
        _record_quick_rating(int(player_id), home_goals, away_goals)
    for player_id in away_ids:
        _add_player_stat(int(player_id), "apps", 1)
        _record_quick_rating(int(player_id), away_goals, home_goals)
    _distribute_quick_goals(home_ids, home_goals, home_id)
    _distribute_quick_goals(away_ids, away_goals, away_id)
    _record_quick_cards(home_ids)
    _record_quick_cards(away_ids)
    _record_clean_sheet(home_id, away_goals, home_ids)
    _record_clean_sheet(away_id, home_goals, away_ids)

func _update_quick_career_appearances(team_id: int, lineup_ids: Array, conceded: int) -> void:
    for raw_id in lineup_ids:
        var player_id = int(raw_id)
        var player = _player(player_id)
        var bucket = _career_stat_bucket(player, team_id)
        bucket["apps"] = int(bucket.get("apps", 0)) + 1
        player["career_total_apps"] = int(player.get("career_total_apps", 0)) + 1
        if _is_goalkeeper(player):
            bucket["conceded"] = int(bucket.get("conceded", 0)) + conceded
            player["career_total_conceded"] = int(player.get("career_total_conceded", 0)) + conceded
            if conceded == 0:
                bucket["clean_sheets"] = int(bucket.get("clean_sheets", 0)) + 1
                player["career_total_clean_sheets"] = int(player.get("career_total_clean_sheets", 0)) + 1
        _store_career_stat_bucket(player, team_id, bucket)

func _add_quick_career_goal(player_id: int, team_id: int, field: String) -> void:
    if player_id < 0:
        return
    var player = _player(player_id)
    var bucket = _career_stat_bucket(player, team_id)
    bucket[field] = int(bucket.get(field, 0)) + 1
    if field == "goals":
        player["career_total_goals"] = int(player.get("career_total_goals", 0)) + 1
    elif field == "assists":
        player["career_total_assists"] = int(player.get("career_total_assists", 0)) + 1
    _store_career_stat_bucket(player, team_id, bucket)

func _distribute_quick_goals(lineup_ids: Array, goals: int, team_id = -1) -> void:
    for _goal in range(goals):
        var scorer = _weighted_player_pick(lineup_ids, team_id, "goal")
        var scorer_id = int(scorer.get("id", -1))
        _add_player_stat(scorer_id, "goals", 1)
        _add_quick_career_goal(scorer_id, team_id, "goals")
        if rng.randf() < 0.76:
            var assister = _weighted_player_pick(lineup_ids, team_id, "assist", scorer_id)
            var assister_id = int(assister.get("id", -1))
            _add_player_stat(assister_id, "assists", 1)
            _add_quick_career_goal(assister_id, team_id, "assists")

func _record_quick_rating(player_id: int, goals_for: int, goals_against: int) -> void:
    var rating = 6.45 + rng.randf_range(-0.55, 0.55)
    if goals_for > goals_against: rating += 0.35
    elif goals_for < goals_against: rating -= 0.25
    var player = _player(player_id)
    if goals_against == 0 and str(player.get("position", "")) in ["GK", "CB", "LB", "RB"]: rating += 0.25
    rating = clamp(rating, 4.2, 8.6)
    var stats: Dictionary = player_stats.get(str(player_id), _empty_player_stat())
    stats["rating_sum"] = float(stats.get("rating_sum", 0.0)) + rating
    stats["rating_apps"] = int(stats.get("rating_apps", 0)) + 1
    player_stats[str(player_id)] = stats
    var apps = int(player.get("career_rating_apps", 0))
    player["career_avg_rating"] = (float(player.get("career_avg_rating", 6.5)) * apps + rating) / float(apps + 1)
    player["career_rating_apps"] = apps + 1
    var age = int(player.get("age", 25))
    var age_factor = 0.20 if age <= 22 else (-0.10 if age >= 33 else 0.0)
    player["development_points"] = clamp(float(player.get("development_points", 0.0)) + (rating - 6.5) * 0.30 + age_factor, -20.0, 20.0)

func _record_quick_cards(lineup_ids: Array) -> void:
    var yellow_count = rng.randi_range(0, 2)
    if rng.randf() < 0.20:
        yellow_count += 1
    for _card in range(yellow_count):
        var candidates: Array = []
        for player_id in lineup_ids:
            if str(_player(int(player_id)).get("position", "")) != "GK":
                candidates.append(int(player_id))
        if not candidates.is_empty():
            _add_player_stat(int(candidates[rng.randi_range(0, candidates.size() - 1)]), "yellow", 1)
    if rng.randf() < 0.035:
        var red_candidates: Array = []
        for player_id in lineup_ids:
            if str(_player(int(player_id)).get("position", "")) in ["CB", "LB", "RB", "DM", "CM"]:
                red_candidates.append(int(player_id))
        if not red_candidates.is_empty():
            _add_player_stat(int(red_candidates[rng.randi_range(0, red_candidates.size() - 1)]), "red", 1)

func _clean_all_squad_duplicates() -> void:
    var global_ids: Dictionary = {}
    var ordered_keys: Array = club_squads.keys()
    var selected_key = str(selected_team_id)
    if selected_team_id >= 0 and selected_key in ordered_keys:
        ordered_keys.erase(selected_key)
        ordered_keys.push_front(selected_key)
    for raw_team_key in ordered_keys:
        var team_key = str(raw_team_key)
        var cleaned: Array = []
        var local_names: Dictionary = {}
        for raw_id in club_squads.get(team_key, []):
            var player_id = int(raw_id)
            var player = _player(player_id)
            if player.is_empty() or global_ids.has(str(player_id)):
                continue
            var normalized_name = str(player.get("name", "")).strip_edges().to_lower()
            if normalized_name.is_empty() or local_names.has(normalized_name):
                continue
            cleaned.append(player_id)
            global_ids[str(player_id)] = true
            local_names[normalized_name] = true
        club_squads[team_key] = cleaned

func _rebuild_player_club_index() -> void:
    player_club_index.clear()
    for key in club_squads.keys():
        for raw_id in club_squads[key]:
            player_club_index[str(int(raw_id))] = int(key)
    statistics_cache.clear()
    statistics_cache_revision += 1

func _club_for_player(player_id: int) -> int:
    var key = str(player_id)
    if player_club_index.has(key):
        var team_id = int(player_club_index[key])
        if player_id in club_squads.get(str(team_id), []):
            return team_id
    for team_key in club_squads.keys():
        if player_id in club_squads[team_key]:
            player_club_index[key] = int(team_key)
            return int(team_key)
    player_club_index.erase(key)
    return -1

func _render_finances() -> void:
    var sponsor = _current_sponsor()
    content_area.add_child(_title("Финансы клуба"))
    var intro = _label("Доходы складываются из спонсорских выплат, призовых лиги, продаж и аренд. Зарплаты указаны за неделю; в прототипе пока не списываются из бюджета автоматически.", 13, colors.muted)
    intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content_area.add_child(intro)

    var sponsor_panel = PanelContainer.new()
    sponsor_panel.add_theme_stylebox_override("panel", _panel_style(colors.panel, colors.cyan, 10, 1))
    content_area.add_child(sponsor_panel)
    var sponsor_box = VBoxContainer.new()
    sponsor_box.add_theme_constant_override("separation", 7)
    sponsor_panel.add_child(sponsor_box)
    sponsor_box.add_child(_label("Спонсор: %s" % sponsor.get("name", "Нет спонсора"), 20, colors.mint))
    sponsor_box.add_child(_label(str(sponsor.get("description", "")), 13, colors.muted))
    sponsor_box.add_child(_label("За победу: %s · за ничью: %s · за каждый матч: %s" % [_money(int(sponsor.get("win", 0))), _money(int(sponsor.get("draw", 0))), _money(int(sponsor.get("match", 0)))], 14, colors.text))
    sponsor_box.add_child(_label("Чемпионство: %s · место в тройке: %s" % [_money(int(sponsor.get("champion", 0))), _money(int(sponsor.get("top3", 0)))], 14, colors.text))

    var grid = GridContainer.new()
    grid.columns = 2
    grid.add_theme_constant_override("h_separation", 18)
    grid.add_theme_constant_override("v_separation", 10)
    content_area.add_child(grid)
    var values = [
        ["Текущий бюджет", _money(int(game_state.get("budget", 0)))],
        ["Спонсорские доходы за карьеру", _money(int(game_state.get("sponsor_income", 0)))],
        ["Спонсорские доходы сезона", _money(int(game_state.get("season_sponsor_income", 0)))],
        ["Призовые лиги за карьеру", _money(int(game_state.get("prize_income", 0)))],
        ["Недельная зарплатная ведомость", _weekly_money(_weekly_wage_bill())],
        ["Игроков в аренде", str((game_state.get("loans_out", {}) as Dictionary).size())]
    ]
    for item in values:
        var card = PanelContainer.new()
        card.add_theme_stylebox_override("panel", _panel_style(Color("0d1f2d"), Color("24485c"), 8, 1))
        var box = VBoxContainer.new()
        card.add_child(box)
        box.add_child(_label(str(item[0]), 12, colors.muted))
        box.add_child(_label(str(item[1]), 18, colors.warning))
        grid.add_child(card)

    content_area.add_child(_label("Призовые за место в лиге", 18, colors.text))
    for i in range(LEAGUE_PRIZES.size()):
        content_area.add_child(_label("%d-е место — %s" % [i + 1, _money(int(LEAGUE_PRIZES[i]))], 13, colors.muted))

func _current_sponsor() -> Dictionary:
    var sponsor_id = str(game_state.get("sponsor_id", "balanced"))
    return SPONSORS.get(sponsor_id, SPONSORS["balanced"])

func _sponsor_match_bonus(user_goals: int, opponent_goals: int) -> int:
    var sponsor = _current_sponsor()
    var bonus = int(sponsor.get("match", 0))
    if user_goals > opponent_goals:
        bonus += int(sponsor.get("win", 0))
    elif user_goals == opponent_goals:
        bonus += int(sponsor.get("draw", 0))
    return bonus

func _ensure_season_financial_award(place: int) -> int:
    if not game_state.has("season_awards_paid") or not game_state.get("season_awards_paid") is Array:
        game_state["season_awards_paid"] = []
    if not game_state.has("season_award_amounts") or not game_state.get("season_award_amounts") is Dictionary:
        game_state["season_award_amounts"] = {}
    var season = int(game_state.get("season", 1))
    var paid: Array = game_state.get("season_awards_paid", [])
    var amounts: Dictionary = game_state.get("season_award_amounts", {})
    for raw_season in paid:
        if int(raw_season) == season:
            return int(amounts.get(str(season), 0))
    var league_prize = int(LEAGUE_PRIZES[place - 1]) if place > 0 and place <= LEAGUE_PRIZES.size() else 500000
    var sponsor = _current_sponsor()
    var sponsor_bonus = int(sponsor.get("champion", 0)) if place == 1 else (int(sponsor.get("top3", 0)) if place <= 3 else 0)
    var total = league_prize + sponsor_bonus
    game_state["budget"] = int(game_state.get("budget", 0)) + total
    game_state["prize_income"] = int(game_state.get("prize_income", 0)) + league_prize
    game_state["sponsor_income"] = int(game_state.get("sponsor_income", 0)) + sponsor_bonus
    game_state["season_sponsor_income"] = int(game_state.get("season_sponsor_income", 0)) + sponsor_bonus
    paid.append(season)
    amounts[str(season)] = total
    game_state["season_awards_paid"] = paid
    game_state["season_award_amounts"] = amounts
    return total

func _weekly_wage_bill() -> int:
    var total = 0
    for player_id in _squad(selected_team_id):
        total += int(_player(int(player_id)).get("wage_weekly", 0))
    for key in (game_state.get("loans_out", {}) as Dictionary).keys():
        total += int(_player(int(key)).get("wage_weekly", 0))
    return total

func _weekly_money(value: int) -> String:
    return "%s/нед." % _money(value)

func _player_link_button(player_id: int, text_value: String, width: float) -> Button:
    var button = Button.new()
    button.text = text_value
    button.custom_minimum_size = Vector2(width, 34)
    button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    button.add_theme_font_size_override("font_size", 13)
    button.add_theme_color_override("font_color", colors.text)
    button.add_theme_color_override("font_hover_color", colors.cyan)
    button.add_theme_stylebox_override("normal", _panel_style(Color(0, 0, 0, 0), Color.TRANSPARENT, 4, 0))
    button.add_theme_stylebox_override("hover", _panel_style(Color("15384d"), colors.cyan, 4, 1))
    button.add_theme_stylebox_override("pressed", _panel_style(Color("0d3044"), colors.mint, 4, 1))
    button.pressed.connect(_open_player_dialog.bind(player_id))
    return button

func _open_player_dialog(player_id: int) -> void:
    var player = _player(player_id)
    if player.is_empty():
        return
    var dialog = Window.new()
    dialog.title = str(player.get("name", "Игрок"))
    dialog.transient = true
    dialog.exclusive = true
    dialog.size = Vector2i(800, 700)
    add_child(dialog)
    var panel = PanelContainer.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    panel.add_theme_stylebox_override("panel", _panel_style(Color("0d1b29"), colors.cyan, 10, 1))
    dialog.add_child(panel)
    var scroll = ScrollContainer.new()
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    panel.add_child(scroll)
    var root = VBoxContainer.new()
    root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    root.add_theme_constant_override("separation", 10)
    scroll.add_child(root)
    root.add_child(_label(str(player.get("name", "Игрок")), 25, colors.text))
    var secondaries: Array = player.get("secondary", [])
    root.add_child(_label("Основная позиция: %s · дополнительные: %s" % [player.get("position", "?"), ", ".join(secondaries) if not secondaries.is_empty() else "нет"], 14, colors.cyan))
    root.add_child(_label("Возраст: %d · рейтинг: %d · потенциал: %d · стоимость: %s" % [int(player.get("age", 0)), int(player.get("rating", 0)), int(player.get("potential", player.get("rating", 0))), _money(int(player.get("value", 0)))], 14, colors.text))
    root.add_child(_label("Уровень команды: %s · статус данных: %s" % [_squad_level_name(str(player.get("squad_level", "first"))), str(player.get("data_status", "историческое ядро"))], 12, colors.muted))
    root.add_child(_label("Контракт: %d г. · зарплата: %s" % [int(player.get("contract_years", 1)), _weekly_money(int(player.get("wage_weekly", 0)))], 14, colors.warning))
    if _is_player_injured(player):
        root.add_child(_label("ТРАВМА: %s · %s" % [player.get("injury_details", player.get("injury_name", "Повреждение")), _injury_recovery_text(player)], 14, colors.danger))
    if _is_player_suspended(player):
        root.add_child(_label("ДИСКВАЛИФИКАЦИЯ: %d матч(а) · %s" % [int(player.get("suspended_matches", 0)), player.get("suspension_reason", "удаление")], 14, colors.warning))
    root.add_child(_label("Средняя оценка карьеры: %.2f · история травм: %d" % [float(player.get("career_avg_rating", 6.5)), int(player.get("injury_history", 0))], 13, colors.muted))
    var career_line = "Карьера: %d матчей · %d голов · %d передач" % [int(player.get("career_total_apps", 0)), int(player.get("career_total_goals", 0)), int(player.get("career_total_assists", 0))]
    if _is_goalkeeper(player):
        career_line = "Карьера: %d матчей · %d сухих · %d пропущено" % [int(player.get("career_total_apps", 0)), int(player.get("career_total_clean_sheets", 0)), int(player.get("career_total_conceded", 0))]
    root.add_child(_label(career_line, 14, colors.mint))
    var club_history: Dictionary = player.get("career_club_stats", {})
    if not club_history.is_empty():
        root.add_child(_label("Статистика по клубам", 15, colors.warning))
        for club_key in club_history.keys():
            var club_stats: Dictionary = club_history[club_key]
            var history_text = "%s: %d матчей · %d голов · %d передач" % [_team_name(int(club_key)), int(club_stats.get("apps", 0)), int(club_stats.get("goals", 0)), int(club_stats.get("assists", 0))]
            if _is_goalkeeper(player):
                history_text = "%s: %d матчей · %d сухих · %d пропущено" % [_team_name(int(club_key)), int(club_stats.get("apps", 0)), int(club_stats.get("clean_sheets", 0)), int(club_stats.get("conceded", 0))]
            root.add_child(_label(history_text, 12, colors.muted))
    var stats: Dictionary = player_stats.get(str(player_id), _empty_player_stat())
    root.add_child(_label("Сезон: %d матчей · %d голов · %d передач · ЖК %d · КК %d" % [int(stats.get("apps", 0)), int(stats.get("goals", 0)), int(stats.get("assists", 0)), int(stats.get("yellow", 0)), int(stats.get("red", 0))], 14, colors.muted))
    var training: Dictionary = (game_state.get("position_training", {}) as Dictionary).get(str(player_id), {})
    if not training.is_empty():
        root.add_child(_label("Тренирует позицию %s — %d%%" % [training.get("target", "?"), int(training.get("progress", 0))], 13, colors.mint))
    if _squad_has_player(selected_team_id, player_id) and not secondaries.is_empty():
        var primary_actions = HFlowContainer.new()
        primary_actions.add_theme_constant_override("h_separation", 6)
        primary_actions.add_child(_label("Назначить основной:", 13, colors.mint))
        for position in secondaries:
            var make_primary = _button(str(position))
            make_primary.pressed.connect(_set_primary_from_dialog.bind(player_id, str(position), dialog))
            primary_actions.add_child(make_primary)
        root.add_child(primary_actions)
    var spacer = Control.new()
    spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(spacer)

    var belongs = _squad_has_player(selected_team_id, player_id)
    if belongs:
        var sale_price = int(float(player.get("value", 0)) * 0.75)
        var loan_fee = int(float(player.get("value", 0)) * 0.08)
        var termination_fee = int(player.get("wage_weekly", 0)) * 26
        var important = _button("СНЯТЬ СТАТУС ВАЖНОГО" if _is_important_player(player_id) else "СДЕЛАТЬ ВАЖНЫМ ИГРОКОМ")
        important.disabled = not _is_important_player(player_id) and (game_state.get("important_players", []) as Array).size() >= MAX_IMPORTANT_PLAYERS
        important.pressed.connect(_toggle_important_from_dialog.bind(player_id, dialog))
        root.add_child(important)
        root.add_child(_label("Важных игроков можно выбрать не более трёх. Они защищены от продажи и аренды.", 12, colors.muted))
        root.add_child(_label("Доступные действия", 17, colors.mint))
        var actions = HFlowContainer.new()
        actions.add_theme_constant_override("h_separation", 8)
        actions.add_theme_constant_override("v_separation", 8)
        root.add_child(actions)
        var transfer_list_button = _button("СНЯТЬ С ТРАНСФЕРА" if _is_transfer_listed(player_id) else "ВЫСТАВИТЬ НА ТРАНСФЕР")
        transfer_list_button.disabled = _is_important_player(player_id) or not bool(_transfer_window_status().get("open", false))
        transfer_list_button.pressed.connect(_toggle_transfer_list_from_dialog.bind(player_id, dialog))
        actions.add_child(transfer_list_button)
        var sell = _button("БЫСТРАЯ ПРОДАЖА ЗА %s" % _money(sale_price))
        sell.disabled = _is_important_player(player_id) or _squad(selected_team_id).size() <= 14 or not bool(_transfer_window_status().get("open", false))
        sell.pressed.connect(_sell_from_dialog.bind(player_id, sale_price, dialog))
        actions.add_child(sell)
        var loan = _button("АРЕНДА НА СЕЗОН · %s" % _money(loan_fee))
        loan.disabled = _is_important_player(player_id) or _match_squad(selected_team_id).size() <= 14 or not bool(_transfer_window_status().get("open", false))
        loan.pressed.connect(_loan_from_dialog.bind(player_id, dialog))
        actions.add_child(loan)
        var loan_option = _button("АРЕНДА С ВЫКУПОМ")
        loan_option.disabled = loan.disabled
        loan_option.pressed.connect(_loan_with_option_from_dialog.bind(player_id, dialog))
        actions.add_child(loan_option)
        var renew = _button("ПРОДЛИТЬ КОНТРАКТ", true)
        renew.disabled = int(player.get("contract_years", 1)) >= MAX_TOTAL_CONTRACT_YEARS
        renew.pressed.connect(_open_renewal_from_dialog.bind(player_id, dialog))
        actions.add_child(renew)
        var terminate = _button("РАСТОРГНУТЬ · %s" % _money(termination_fee))
        terminate.disabled = termination_fee > int(game_state.get("budget", 0)) or _squad(selected_team_id).size() <= 14
        terminate.pressed.connect(_terminate_from_dialog.bind(player_id, dialog))
        actions.add_child(terminate)
    else:
        var owner_id = _club_for_player(player_id)
        if owner_id >= 0:
            root.add_child(_label("Клуб: %s" % _team_name(owner_id), 13, colors.muted))
        var buy = _button("КУПИТЬ ЗА %s" % _money(_purchase_price(player_id)), true)
        buy.disabled = _purchase_price(player_id) > int(game_state.get("budget", 0)) or not bool(_transfer_window_status().get("open", false))
        buy.pressed.connect(_buy_from_dialog.bind(player_id, dialog))
        root.add_child(buy)
    var close = _button("ЗАКРЫТЬ")
    close.pressed.connect(_close_window.bind(dialog))
    root.add_child(close)
    dialog.close_requested.connect(_close_window.bind(dialog))
    dialog.popup_centered()

func _set_primary_from_dialog(player_id: int, position: String, dialog: Window) -> void:
    var player = _player(player_id)
    var secondary: Array = player.get("secondary", []).duplicate()
    if position not in secondary: return
    var old = str(player.get("position", ""))
    secondary.erase(position)
    if old not in secondary: secondary.append(old)
    player["position"] = position
    player["secondary"] = secondary
    _close_window(dialog)
    notice_text = "%s теперь имеет основную позицию %s." % [player.get("name", "Игрок"), position]
    _show_dashboard("club")

func _close_window(dialog: Window) -> void:
    if is_instance_valid(dialog):
        dialog.queue_free()

func _sell_from_dialog(player_id: int, price: int, dialog: Window) -> void:
    _close_window(dialog)
    _sell_player(player_id, price)

func _buy_from_dialog(player_id: int, dialog: Window) -> void:
    _close_window(dialog)
    _open_contract_offer_dialog(player_id)

func _loan_from_dialog(player_id: int, dialog: Window) -> void:
    _close_window(dialog)
    _loan_player_out(player_id)

func _open_renewal_from_dialog(player_id: int, dialog: Window) -> void:
    _close_window(dialog)
    _open_contract_renewal_dialog(player_id)

func _terminate_from_dialog(player_id: int, dialog: Window) -> void:
    _close_window(dialog)
    _terminate_contract(player_id)

func _loan_player_out(player_id: int, with_option = false) -> void:
    if not bool(_transfer_window_status().get("open", false)):
        notice_text = "Аренда недоступна: трансферное окно закрыто."
        _show_dashboard("transfers")
        return
    if _is_important_player(player_id):
        notice_text = "Важного игрока нельзя отдать в аренду. Сначала снимите статус."
        _show_dashboard("transfers")
        return
    if not _squad_has_player(selected_team_id, player_id) or _squad(selected_team_id).size() <= 14: return
    var player = _player(player_id)
    var fee_rate = 0.05 if with_option else 0.08
    var fee = int(float(player.get("value", 0)) * fee_rate)
    var borrowers: Array = []
    for team in database.get("teams", []):
        var team_id = int(team.get("id", -1))
        if team_id != selected_team_id and _squad(team_id).size() >= 14:
            borrowers.append(team_id)
    if borrowers.is_empty():
        return
    var borrower = int(borrowers[rng.randi_range(0, borrowers.size() - 1)])
    _detach_player_from_all_clubs(player_id)
    club_squads[str(borrower)].append(player_id)
    _remove_player_from_transfer_system(player_id)
    var option_price = int(float(player.get("value", 0)) * rng.randf_range(0.95, 1.15)) if with_option else 0
    var loans: Dictionary = game_state.get("loans_out", {})
    loans[str(player_id)] = {"return_season": int(game_state.get("season", 1)) + 1, "fee": fee, "borrower": borrower, "with_option": with_option, "option_price": option_price}
    game_state["loans_out"] = loans
    game_state["budget"] = int(game_state.get("budget", 0)) + fee
    _remove_from_lineup(player_id)
    notice_text = "%s арендован клубом %s%s. Получено %s." % [player.get("name", "Игрок"), _team_name(borrower), " с правом выкупа за %s" % _money(option_price) if with_option else "", _money(fee)]
    _show_dashboard("transfers")

func _return_loans() -> void:
    var loans: Dictionary = game_state.get("loans_out", {})
    var completed: Array = []
    for key in loans.keys():
        var loan: Dictionary = loans[key]
        if int(loan.get("return_season", 999)) > int(game_state.get("season", 1)):
            continue
        var player_id = int(key)
        var borrower = int(loan.get("borrower", -1))
        var stats: Dictionary = player_stats.get(str(player_id), _empty_player_stat())
        var average = float(stats.get("rating_sum",0.0)) / max(1, int(stats.get("rating_apps",0)))
        var apps = int(stats.get("apps",0))
        var option_price = int(loan.get("option_price",0))
        var buy = bool(loan.get("with_option",false)) and borrower >= 0 and option_price > 0 and (average >= 7.0 or (apps >= 8 and average >= 6.7))
        var budgets: Dictionary = game_state.get("ai_budgets",{})
        if buy and int(budgets.get(str(borrower), int(_team(borrower).get("budget",0)))) >= option_price:
            game_state["budget"] = int(game_state.get("budget",0)) + option_price
            budgets[str(borrower)] = int(budgets.get(str(borrower),0)) - option_price
            game_state["ai_budgets"] = budgets
            _player(player_id)["contract_years"] = rng.randi_range(2,5)
        else:
            _detach_player_from_all_clubs(player_id)
            club_squads[str(selected_team_id)].append(player_id)
        completed.append(str(key))
    for key in completed:
        loans.erase(key)
    game_state["loans_out"] = loans

func _contract_renewal_fee(player_id: int, extension_years: int) -> int:
    var player = _player(player_id)
    var years = clamp(extension_years, 1, MAX_CONTRACT_EXTENSION_YEARS)
    # Сохраняем прежний баланс: два года стоили примерно 4% стоимости игрока.
    # Теперь цена растёт линейно — около 2% стоимости за каждый добавленный год.
    var one_year_fee = max(125000, int(float(player.get("value", 0)) * 0.02))
    return one_year_fee * years

func _open_contract_renewal_dialog(player_id: int) -> void:
    if not _squad_has_player(selected_team_id, player_id):
        return
    var player = _player(player_id)
    var current_years = int(player.get("contract_years", 1))
    var maximum_extension = min(MAX_CONTRACT_EXTENSION_YEARS, MAX_TOTAL_CONTRACT_YEARS - current_years)
    if maximum_extension <= 0:
        notice_text = "%s уже имеет максимально длинный контракт — %d лет." % [player.get("name", "Игрок"), current_years]
        _show_dashboard("club")
        return

    var dialog = Window.new()
    dialog.title = "Продление контракта"
    dialog.transient = true
    dialog.exclusive = true
    dialog.size = Vector2i(640, 430)
    add_child(dialog)
    var panel = PanelContainer.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    panel.add_theme_stylebox_override("panel", _panel_style(Color("0d1b29"), colors.cyan, 10, 1))
    dialog.add_child(panel)
    var root = VBoxContainer.new()
    root.add_theme_constant_override("separation", 12)
    panel.add_child(root)
    root.add_child(_label("Продление: %s" % player.get("name", "Игрок"), 22, colors.text))
    root.add_child(_label("Текущий остаток контракта: %d г. · зарплата: %s" % [current_years, _weekly_money(int(player.get("wage_weekly", 0)))], 14, colors.muted))
    root.add_child(_label("Выберите, на сколько лет продлить соглашение. Доступно от 1 до 6 лет; более длинный срок дороже и сильнее повышает зарплату.", 13, colors.muted))
    var row = HBoxContainer.new()
    row.add_theme_constant_override("separation", 12)
    root.add_child(row)
    row.add_child(_label("Добавить к контракту:", 14, colors.text))
    var years = OptionButton.new()
    for value in range(1, maximum_extension + 1):
        years.add_item("%d год(а)" % value, value)
    years.select(0)
    _style_option_button(years, 190)
    row.add_child(years)
    var preview = _label("", 15, colors.warning)
    preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    root.add_child(preview)
    years.item_selected.connect(_refresh_renewal_preview.bind(player_id, years, preview))
    _refresh_renewal_preview(0, player_id, years, preview)
    var spacer = Control.new()
    spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(spacer)
    var buttons = HBoxContainer.new()
    buttons.add_theme_constant_override("separation", 10)
    root.add_child(buttons)
    var cancel = _button("ОТМЕНА")
    cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    cancel.pressed.connect(_close_window.bind(dialog))
    buttons.add_child(cancel)
    var confirm = _button("ПРОДЛИТЬ", true)
    confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    confirm.pressed.connect(_confirm_contract_renewal.bind(player_id, years, dialog))
    buttons.add_child(confirm)
    dialog.close_requested.connect(_close_window.bind(dialog))
    dialog.popup_centered()

func _refresh_renewal_preview(_index: int, player_id: int, years: OptionButton, preview: Label) -> void:
    var extension = int(years.get_selected_id())
    var player = _player(player_id)
    var fee = _contract_renewal_fee(player_id, extension)
    var new_total = min(MAX_TOTAL_CONTRACT_YEARS, int(player.get("contract_years", 1)) + extension)
    var new_wage = int(round(float(player.get("wage_weekly", 1000)) * (1.0 + 0.025 * float(extension)) / 500.0) * 500)
    preview.text = "Стоимость продления: %s · новый остаток: %d г. · новая зарплата: %s" % [_money(fee), new_total, _weekly_money(new_wage)]
    preview.add_theme_color_override("font_color", colors.danger if fee > int(game_state.get("budget", 0)) else colors.warning)

func _confirm_contract_renewal(player_id: int, years: OptionButton, dialog: Window) -> void:
    var extension = int(years.get_selected_id())
    _close_window(dialog)
    _renew_contract(player_id, extension)

func _renew_contract(player_id: int, extension_years: int) -> void:
    if not _squad_has_player(selected_team_id, player_id):
        return
    var player = _player(player_id)
    var current_years = int(player.get("contract_years", 1))
    var extension = clamp(extension_years, 1, min(MAX_CONTRACT_EXTENSION_YEARS, MAX_TOTAL_CONTRACT_YEARS - current_years))
    var fee = _contract_renewal_fee(player_id, extension)
    if fee > int(game_state.get("budget", 0)):
        notice_text = "Недостаточно средств для продления контракта %s. Требуется %s." % [player.get("name", "Игрок"), _money(fee)]
        _show_dashboard("club")
        return
    game_state["budget"] = int(game_state.get("budget", 0)) - fee
    player["contract_years"] = min(MAX_TOTAL_CONTRACT_YEARS, current_years + extension)
    player["wage_weekly"] = int(round(float(player.get("wage_weekly", 1000)) * (1.0 + 0.025 * float(extension)) / 500.0) * 500)
    notice_text = "%s продлил контракт на %d г. Стоимость: %s. Новый остаток: %d г., зарплата: %s." % [player.get("name", "Игрок"), extension, _money(fee), int(player.get("contract_years", 1)), _weekly_money(int(player.get("wage_weekly", 0)))]
    _show_dashboard("club")

func _terminate_contract(player_id: int) -> void:
    if not _squad_has_player(selected_team_id, player_id) or _squad(selected_team_id).size() <= 14:
        return
    var player = _player(player_id)
    var compensation = int(player.get("wage_weekly", 0)) * 26
    if compensation > int(game_state.get("budget", 0)):
        return
    game_state["budget"] = int(game_state.get("budget", 0)) - compensation
    _detach_player_from_all_clubs(player_id)
    for slot_id in lineup.keys():
        if int(lineup.get(slot_id, -1)) == player_id:
            lineup.erase(slot_id)
    var market: Array = game_state.get("market_ids", [])
    if player_id not in market:
        market.append(player_id)
    game_state["market_ids"] = market
    _sanitize_lineup()
    notice_text = "Контракт с %s расторгнут. Компенсация составила %s." % [player.get("name", "Игрок"), _money(compensation)]
    _show_dashboard("club")

func _advance_contracts() -> void:
    var expired: Array = []
    for raw_id in _squad(selected_team_id).duplicate():
        var player_id = int(raw_id)
        var player = _player(player_id)
        player["contract_years"] = max(0, int(player.get("contract_years", 1)) - 1)
        if int(player.get("contract_years", 0)) <= 0:
            expired.append(player_id)
    for player_id in expired:
        _detach_player_from_all_clubs(player_id)
        var market: Array = game_state.get("market_ids", [])
        if player_id not in market:
            market.append(player_id)
        game_state["market_ids"] = market
    _sanitize_lineup()

func _toggle_formation_editor() -> void:
    formation_edit_mode = not formation_edit_mode
    selected_tactics_player_id = -1
    notice_text = "Свободный редактор схемы включён. Двигайте позиции по полю." if formation_edit_mode else "Позиции сохранены. Снова доступна замена игроков перетаскиванием."
    _show_dashboard("tactics")

func _reset_custom_positions() -> void:
    var formation = str(game_state.get("formation", "4-4-2"))
    var all_positions: Dictionary = game_state.get("custom_positions", {})
    all_positions.erase(formation)
    game_state["custom_positions"] = all_positions
    var all_roles: Dictionary = game_state.get("custom_roles", {})
    all_roles.erase(formation)
    game_state["custom_roles"] = all_roles
    notice_text = "Расположение и роли позиций возвращены к стандартной схеме."
    _show_dashboard("tactics")

func _formation_slot_moved(slot_id: String, normalized_position: Vector2) -> void:
    var formation = str(game_state.get("formation", "4-4-2"))
    var all_positions: Dictionary = game_state.get("custom_positions", {})
    var formation_positions: Dictionary = all_positions.get(formation, {})
    formation_positions[slot_id] = {"x": normalized_position.x, "y": normalized_position.y}
    all_positions[formation] = formation_positions
    game_state["custom_positions"] = all_positions
    if slot_id != "GK":
        var role = _role_from_coordinates(normalized_position)
        var all_roles: Dictionary = game_state.get("custom_roles", {})
        var formation_roles: Dictionary = all_roles.get(formation, {})
        formation_roles[slot_id] = role
        all_roles[formation] = formation_roles
        game_state["custom_roles"] = all_roles
        var moved_slot = pitch_slots.get(slot_id) as PositionSlot
        if moved_slot != null:
            moved_slot.set_role(role)
            var player_id = int(lineup.get(slot_id, -1))
            if player_id >= 0:
                var player = _player(player_id)
                moved_slot.set_player(player, _effective_rating_for_slot(player, [role]), _fit_description(player, [role]))
        notice_text = "Позиция перемещена. Новая роль на поле: %s." % role

func _slot_coordinates(slot_data: Dictionary) -> Vector2:
    var default_position = Vector2(float(slot_data.get("x", 0.5)), float(slot_data.get("y", 0.5)))
    var formation = str(game_state.get("formation", "4-4-2"))
    var all_positions: Dictionary = game_state.get("custom_positions", {})
    var formation_positions: Dictionary = all_positions.get(formation, {})
    var saved = formation_positions.get(str(slot_data.get("id", "")), {})
    if saved is Dictionary and not saved.is_empty():
        return Vector2(float(saved.get("x", default_position.x)), float(saved.get("y", default_position.y)))
    return default_position

func _fullback_duty_selected(index: int, option: OptionButton) -> void:
    game_state["fullback_duty"] = option.get_item_text(index)
    notice_text = "Роль крайних защитников: %s. Это влияет на их участие в атаках и голах." % game_state["fullback_duty"]
    _show_dashboard("tactics")

func _pick_goal_scorer(team_id: int) -> Dictionary:
    return _weighted_player_pick(_active_team_player_ids(team_id), team_id, "goal")

func _pick_assist_provider(team_id: int, exclude_id = -1) -> Dictionary:
    return _weighted_player_pick(_active_team_player_ids(team_id), team_id, "assist", int(exclude_id))

func _weighted_player_pick(source_ids: Array, team_id: int, purpose: String, exclude_id = -1) -> Dictionary:
    var candidates: Array = []
    var total_weight = 0.0
    for raw_id in source_ids:
        var player_id = int(raw_id)
        if player_id == exclude_id:
            continue
        var player = _player(player_id)
        if player.is_empty() or _is_goalkeeper(player):
            continue
        var role = _player_match_role(team_id, player_id)
        var weight = _role_event_weight(role, purpose, team_id, player_id)
        var rating_factor = pow(max(0.70, float(player.get("rating", 60)) / 78.0), 2.0)
        weight *= rating_factor
        if weight <= 0.0:
            continue
        total_weight += weight
        candidates.append({"player": player, "limit": total_weight})
    if candidates.is_empty():
        return _player(int(source_ids[0])) if not source_ids.is_empty() else {"name": "Игрок", "id": -1}
    var roll = rng.randf_range(0.0, total_weight)
    for candidate in candidates:
        if roll <= float(candidate.get("limit", total_weight)):
            return candidate.get("player", {})
    return candidates[-1].get("player", {})

func _role_event_weight(role: String, purpose: String, team_id: int, player_id: int) -> float:
    if purpose == "corner":
        return {"ST":82.0,"CF":65.0,"LW":34.0,"RW":34.0,"AM":36.0,"LM":22.0,"RM":22.0,"CM":40.0,"DM":52.0,"LWB":45.0,"RWB":45.0,"LB":48.0,"RB":48.0,"CB":95.0}.get(role,30.0)
    if purpose == "assist":
        return {
            "ST":48.0,"CF":76.0,"LW":82.0,"RW":82.0,"AM":94.0,
            "LM":70.0,"RM":70.0,"CM":62.0,"DM":25.0,
            "LWB":_fullback_event_weight(team_id,player_id,25.0,44.0,66.0),
            "RWB":_fullback_event_weight(team_id,player_id,25.0,44.0,66.0),
            "LB":_fullback_event_weight(team_id,player_id,18.0,32.0,52.0),
            "RB":_fullback_event_weight(team_id,player_id,18.0,32.0,52.0),"CB":9.0
        }.get(role,22.0)
    return {
        "ST":105.0,"CF":88.0,"LW":78.0,"RW":78.0,"AM":61.0,
        "LM":46.0,"RM":46.0,"CM":35.0,"DM":11.0,
        "LWB":_fullback_event_weight(team_id,player_id,8.0,16.0,30.0),
        "RWB":_fullback_event_weight(team_id,player_id,8.0,16.0,30.0),
        "LB":_fullback_event_weight(team_id,player_id,5.0,12.0,24.0),
        "RB":_fullback_event_weight(team_id,player_id,5.0,12.0,24.0),"CB":9.0
    }.get(role,18.0)

func _fullback_event_weight(team_id: int, player_id: int, defend_value: float, support_value: float, attack_value: float) -> float:
    if team_id != selected_team_id:
        return support_value
    var duty = str(game_state.get("fullback_duty", "Поддержка"))
    var value = defend_value if duty == "Оборона" else (attack_value if duty == "Атака" else support_value)
    var slot_id = _lineup_slot_for_player(player_id)
    if not slot_id.is_empty():
        var slot = _formation_slot(slot_id)
        var coords = _slot_coordinates(slot)
        if coords.y < 0.58:
            value = max(value, attack_value)
    return value

func _player_match_role(team_id: int, player_id: int) -> String:
    if team_id == selected_team_id:
        var slot_id = _lineup_slot_for_player(player_id)
        if not slot_id.is_empty():
            var accepted: Array = _formation_slot(slot_id).get("accepted", [])
            if not accepted.is_empty():
                return str(accepted[0])
    return str(_player(player_id).get("position", "CM"))

func _lineup_slot_for_player(player_id: int) -> String:
    for slot_id in lineup.keys():
        if int(lineup.get(slot_id, -1)) == player_id:
            return str(slot_id)
    return ""



func _competition_team_ids(competition_id: String) -> Array:
    var result: Array = []
    for team in database.get("teams", []):
        if str(team.get("competition", "")) == competition_id:
            result.append(int(team.get("id", -1)))
    return result

func _league_name(competition_id: String) -> String:
    for league in database.get("leagues", []):
        if str(league.get("id", "")) == competition_id: return str(league.get("name", competition_id))
    return competition_id

func _world_league_state(competition_id: String) -> Dictionary:
    var user_comp = str(_team(selected_team_id).get("competition", "eng1_demo"))
    if competition_id == user_comp:
        return {"fixtures": fixtures, "table": league_table, "round_simulated": _played_user_matches()}
    return (game_state.get("world_leagues", {}) as Dictionary).get(competition_id, {})

func _sync_user_league_state() -> void:
    var comp = str(_team(selected_team_id).get("competition", "eng1_demo"))
    var world: Dictionary = game_state.get("world_leagues", {})
    world[comp] = {"fixtures": fixtures.duplicate(true), "table": league_table.duplicate(true), "round_simulated": _played_user_matches()}
    game_state["world_leagues"] = world

func _simulate_world_round(round_number: int) -> void:
    var user_comp = str(_team(selected_team_id).get("competition", "eng1_demo"))
    var world: Dictionary = game_state.get("world_leagues", {})
    for comp_key in world.keys():
        var comp = str(comp_key)
        if comp == user_comp: continue
        var state: Dictionary = world[comp]
        var comp_fixtures: Array = state.get("fixtures", []).duplicate(true)
        var comp_table: Dictionary = state.get("table", {}).duplicate(true)
        for i in range(comp_fixtures.size()):
            var fixture: Dictionary = comp_fixtures[i]
            if int(fixture.get("round", -1)) != round_number or bool(fixture.get("played", false)): continue
            var home = int(fixture.get("home", -1)); var away = int(fixture.get("away", -1))
            var hg = _quick_goals(_team_match_power(home), _team_match_power(away), true)
            var ag = _quick_goals(_team_match_power(away), _team_match_power(home), false)
            fixture["played"] = true; fixture["home_score"] = hg; fixture["away_score"] = ag
            comp_fixtures[i] = fixture
            _apply_result_to_table(comp_table, home, away, hg, ag)
            _record_quick_match_stats(home, away, hg, ag)
        state["fixtures"] = comp_fixtures; state["table"] = comp_table; state["round_simulated"] = max(int(state.get("round_simulated", 0)), round_number)
        world[comp] = state
    game_state["world_leagues"] = world

func _apply_result_to_table(table_data: Dictionary, home_id: int, away_id: int, home_goals: int, away_goals: int) -> void:
    var home: Dictionary = table_data.get(str(home_id), {"p":0,"w":0,"d":0,"l":0,"gf":0,"ga":0,"pts":0})
    var away: Dictionary = table_data.get(str(away_id), {"p":0,"w":0,"d":0,"l":0,"gf":0,"ga":0,"pts":0})
    home["p"] += 1; away["p"] += 1; home["gf"] += home_goals; home["ga"] += away_goals; away["gf"] += away_goals; away["ga"] += home_goals
    if home_goals > away_goals: home["w"] += 1; home["pts"] += 3; away["l"] += 1
    elif away_goals > home_goals: away["w"] += 1; away["pts"] += 3; home["l"] += 1
    else: home["d"] += 1; away["d"] += 1; home["pts"] += 1; away["pts"] += 1
    table_data[str(home_id)] = home; table_data[str(away_id)] = away

func _initialize_missing_world_leagues_from_current() -> void:
    var current_comp = str(_team(selected_team_id).get("competition", "eng1_demo"))
    var world: Dictionary = {}
    for league in database.get("leagues", []):
        var comp = str(league.get("id", "")); var ids = _competition_team_ids(comp)
        var comp_table: Dictionary = {}
        for id in ids: comp_table[str(id)] = {"p":0,"w":0,"d":0,"l":0,"gf":0,"ga":0,"pts":0}
        world[comp] = {"fixtures": _generate_fixtures(ids), "table": comp_table, "round_simulated": 0}
    world[current_comp] = {"fixtures": fixtures.duplicate(true), "table": league_table.duplicate(true), "round_simulated": _played_user_matches()}
    game_state["world_leagues"] = world

func _world_league_selected(index: int, option: OptionButton) -> void:
    game_state["selected_world_competition"] = str(option.get_item_metadata(index))
    _show_dashboard("other_leagues")

func _render_other_leagues() -> void:
    content_area.add_child(_title("Другие лиги сезона 2003/04"))
    var selector = OptionButton.new()
    var selected_comp = str(game_state.get("selected_world_competition", "eng1_demo"))
    var selected_index = 0
    for league in database.get("leagues", []):
        selector.add_item(str(league.get("name", "Лига")))
        selector.set_item_metadata(selector.item_count - 1, str(league.get("id", "")))
        if str(league.get("id", "")) == selected_comp: selected_index = selector.item_count - 1
    selector.select(selected_index); _style_option_button(selector, 430)
    selector.item_selected.connect(_world_league_selected.bind(selector))
    content_area.add_child(selector)
    selected_comp = str(selector.get_item_metadata(selector.selected))
    var tabs = TabContainer.new(); tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL; content_area.add_child(tabs)
    _add_world_table_tab(tabs, selected_comp)
    _add_world_statistics_tab(tabs, selected_comp)
    _add_world_clubs_tab(tabs, selected_comp)

func _add_world_table_tab(tabs: TabContainer, competition_id: String) -> void:
    var scroll = ScrollContainer.new(); scroll.name = "Таблица"; tabs.add_child(scroll)
    var list = VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list.add_theme_constant_override("separation", 6); scroll.add_child(list)
    var state = _world_league_state(competition_id); var rows = _sorted_table_data(state.get("table", {}))
    var pos = 1
    for row in rows:
        var team_id = int(row.get("team_id", -1)); var s: Dictionary = row.get("stats", {})
        var panel = PanelContainer.new(); panel.add_theme_stylebox_override("panel", _panel_style(colors.panel_2, Color("24465a"), 6, 1)); list.add_child(panel)
        var h = HBoxContainer.new(); panel.add_child(h)
        h.add_child(_label(str(pos), 13, colors.mint)); h.add_child(_team_link_button(team_id, _team_name(team_id), 260))
        var summary = _label("И %d  В %d  Н %d  П %d  М %d:%d  О %d" % [s.get("p",0),s.get("w",0),s.get("d",0),s.get("l",0),s.get("gf",0),s.get("ga",0),s.get("pts",0)], 13, colors.text)
        summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(summary); pos += 1

func _add_world_statistics_tab(tabs: TabContainer, competition_id: String) -> void:
    var scroll = ScrollContainer.new(); scroll.name = "Лидеры"; scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; tabs.add_child(scroll)
    var root = VBoxContainer.new(); root.size_flags_horizontal = Control.SIZE_EXPAND_FILL; root.add_theme_constant_override("separation", 8); scroll.add_child(root)
    var categories = [["Бомбардиры","goals",false],["Ассистенты","assists",false],["Сухие матчи","clean_sheets",true],["Жёлтые карточки","yellow",false],["Красные карточки","red",false],["Лучшие оценки","average_rating",false]]
    for item in categories:
        root.add_child(_label(item[0], 17, colors.mint))
        var rows = _sorted_statistics_for_comp(str(item[1]), competition_id, bool(item[2]))
        for i in range(min(5, rows.size())):
            var data: Dictionary = rows[i]; var pid = int(data.get("player_id", -1)); var st: Dictionary = data.get("stats", {})
            var value = _stat_value_text(str(item[1]), st)
            root.add_child(_player_link_button(pid, "%d. %s — %s (%s)" % [i+1,_player(pid).get("name","Игрок"),value,_team_name(_club_for_player(pid))], 650))

func _add_world_clubs_tab(tabs: TabContainer, competition_id: String) -> void:
    var root = VBoxContainer.new(); root.name = "Клубы"; root.add_theme_constant_override("separation", 8); tabs.add_child(root)
    for team_id in _competition_team_ids(competition_id):
        var team = _team(int(team_id)); var button = _button("%s · тренер %s · схема %s" % [team.get("name","Клуб"),team.get("coach_name","—"),team.get("coach_formation","4-4-2")])
        button.pressed.connect(_open_team_dialog.bind(int(team_id))); root.add_child(button)

func _team_link_button(team_id: int, text_value: String, width: float) -> Button:
    var b = Button.new(); b.text = text_value; b.custom_minimum_size = Vector2(width, 38); b.alignment = HORIZONTAL_ALIGNMENT_LEFT
    b.add_theme_stylebox_override("normal", StyleBoxEmpty.new()); b.add_theme_color_override("font_color", colors.cyan); b.pressed.connect(_open_team_dialog.bind(team_id)); return b

func _open_team_dialog(team_id: int) -> void:
    var team = _team(team_id)
    if team.is_empty(): return
    var dialog = Window.new(); dialog.title = str(team.get("name","Клуб")); dialog.transient = true; dialog.exclusive = false; dialog.size = Vector2i(900, 720); add_child(dialog)
    var panel = PanelContainer.new(); panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); panel.add_theme_stylebox_override("panel", _panel_style(colors.panel, colors.cyan, 10, 1)); dialog.add_child(panel)
    var root = VBoxContainer.new(); root.add_theme_constant_override("separation", 8); panel.add_child(root)
    root.add_child(_label("%s" % team.get("name","Клуб"), 25, colors.text)); root.add_child(_label("%s · тренер %s · схема %s · стиль %s" % [team.get("league_name",""),team.get("coach_name","—"),team.get("coach_formation","4-4-2"),team.get("coach_style","Сбалансированно")], 13, colors.mint))
    var scroll = ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; root.add_child(scroll)
    var list = VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list.add_theme_constant_override("separation", 5); scroll.add_child(list)
    var squad = _squad(team_id).duplicate(); squad.sort_custom(func(a,b): return int(_player(a).get("rating",0)) > int(_player(b).get("rating",0)))
    for raw_id in squad:
        var pid = int(raw_id); var pl = _player(pid); var st: Dictionary = player_stats.get(str(pid), _empty_player_stat())
        list.add_child(_player_link_button(pid, "%s · %s · %d · %d игр, %d голов, %d передач" % [pl.get("name","Игрок"),pl.get("position","?"),pl.get("rating",0),st.get("apps",0),st.get("goals",0),st.get("assists",0)], 800))
    var close = _button("ЗАКРЫТЬ"); close.pressed.connect(_close_window.bind(dialog)); root.add_child(close); dialog.close_requested.connect(_close_window.bind(dialog)); dialog.popup_centered()

func _sorted_table_data(table_data: Dictionary) -> Array:
    var rows: Array = []
    for key in table_data.keys(): rows.append({"team_id":int(key),"stats":table_data[key]})
    rows.sort_custom(func(a,b):
        var sa: Dictionary=a["stats"]; var sb: Dictionary=b["stats"]
        if int(sa.get("pts",0)) != int(sb.get("pts",0)): return int(sa.get("pts",0)) > int(sb.get("pts",0))
        return int(sa.get("gf",0))-int(sa.get("ga",0)) > int(sb.get("gf",0))-int(sb.get("ga",0)))
    return rows

func _sorted_statistics_for_comp(category: String, competition_id: String, goalkeepers_only = false) -> Array:
    var cache_key = "%s|%s|%s|%d" % [competition_id, category, str(goalkeepers_only), int(game_state.get("data_revision", 0))]
    if statistics_cache.has(cache_key):
        return (statistics_cache[cache_key] as Array).duplicate(true)
    var rows: Array = []
    for key in player_stats.keys():
        var pid = int(key)
        var owner = _club_for_player(pid)
        if owner < 0 or str(_team(owner).get("competition","")) != competition_id:
            continue
        var pl = _player(pid)
        if pl.is_empty() or bool(pl.get("retired",false)):
            continue
        if goalkeepers_only and not _is_goalkeeper(pl):
            continue
        rows.append({"player_id":pid,"stats":player_stats[key]})
    rows.sort_custom(func(a,b):
        var sa:Dictionary=a["stats"]
        var sb:Dictionary=b["stats"]
        var va = _stat_numeric_value(category,sa)
        var vb = _stat_numeric_value(category,sb)
        if not is_equal_approx(va,vb):
            return va>vb
        return int(sa.get("apps",0))>int(sb.get("apps",0)))
    statistics_cache[cache_key] = rows.duplicate(true)
    return rows

func _stat_numeric_value(category: String, stats: Dictionary) -> float:
    if category == "cards": return float(int(stats.get("red",0))*5 + int(stats.get("yellow",0)))
    if category == "average_rating": return _average_player_rating(stats)
    return float(stats.get(category,0))

func _stat_value_text(category: String, stats: Dictionary) -> String:
    if category == "cards": return "%d ЖК / %d КК" % [stats.get("yellow",0),stats.get("red",0)]
    if category == "average_rating": return "%.2f" % _average_player_rating(stats)
    return str(stats.get(category,0))

func _add_season_leaders(parent: VBoxContainer, competition_id: String) -> void:
    parent.add_child(_label("Итоговые таблицы лучших игроков сезона", 19, colors.mint))
    var categories = [["Бомбардиры","goals",false],["Ассистенты","assists",false],["Сухие матчи","clean_sheets",true],["Жёлтые карточки","yellow",false],["Красные карточки","red",false],["Лучшие по средней оценке","average_rating",false]]
    for item in categories:
        var panel = PanelContainer.new()
        panel.add_theme_stylebox_override("panel", _panel_style(Color("102434"), Color("31566b"), 7, 1))
        parent.add_child(panel)
        var box = VBoxContainer.new(); box.add_theme_constant_override("separation", 4); panel.add_child(box)
        box.add_child(_label(str(item[0]), 16, colors.warning))
        var rows = _sorted_statistics_for_comp(str(item[1]), competition_id, bool(item[2]))
        if rows.is_empty():
            box.add_child(_label("Нет данных.", 13, colors.muted))
            continue
        for i in range(min(5, rows.size())):
            var data: Dictionary = rows[i]
            var pid = int(data.get("player_id", -1))
            var st: Dictionary = data.get("stats", {})
            box.add_child(_label("%d. %s — %s · %s" % [i + 1, _player(pid).get("name", "Игрок"), _stat_value_text(str(item[1]), st), _team_name(_club_for_player(pid))], 13, colors.text))

func _purchase_price(player_id: int) -> int:
    var owner = _club_for_player(player_id); var base = int(_player(player_id).get("value",0))
    return int(round(float(base) * (1.15 if owner >= 0 and owner != selected_team_id else 1.0)))

func _remove_from_lineup(player_id: int) -> void:
    var remove_slots: Array = []
    for slot_id in lineup.keys():
        if int(lineup.get(slot_id,-1)) == player_id: remove_slots.append(str(slot_id))
    for slot_id in remove_slots: lineup.erase(slot_id)
    _sanitize_lineup()
    game_state["lineup_confirmed"] = _lineup_is_valid()


func _clean_important_players() -> void:
    var cleaned: Array = []
    for raw_id in game_state.get("important_players", []):
        var pid = int(raw_id)
        if _squad_has_player(selected_team_id, pid) and not bool(_player(pid).get("retired", false)) and pid not in cleaned:
            cleaned.append(pid)
    while cleaned.size() > MAX_IMPORTANT_PLAYERS: cleaned.pop_back()
    game_state["important_players"] = cleaned

func _is_important_player(player_id: int) -> bool:
    return player_id in (game_state.get("important_players", []) as Array)

func _toggle_important_player(player_id: int) -> void:
    var important: Array = game_state.get("important_players", []).duplicate()
    if player_id in important:
        important.erase(player_id)
    elif important.size() < MAX_IMPORTANT_PLAYERS:
        important.append(player_id)
        _remove_player_from_transfer_system(player_id)
    game_state["important_players"] = important

func _toggle_important_from_dialog(player_id: int, dialog: Window) -> void:
    _toggle_important_player(player_id); _close_window(dialog)
    notice_text = "%s: %s" % [_player(player_id).get("name","Игрок"), "важный игрок" if _is_important_player(player_id) else "статус важного игрока снят"]
    _show_dashboard("club")

func _is_player_injured(player: Dictionary) -> bool:
    return int(player.get("injury_days", int(player.get("injured_matches", 0)) * MATCH_DAYS_STEP)) > 0

func _is_player_suspended(player: Dictionary) -> bool:
    return int(player.get("suspended_matches", 0)) > 0

func _is_player_unavailable(player: Dictionary) -> bool:
    return _is_player_injured(player) or _is_player_suspended(player) or bool(player.get("retired", false))

func _available_squad_player_ids(team_id: int) -> Array:
    var result: Array = []
    for raw_id in _match_squad(team_id):
        var player = _player(int(raw_id))
        if not player.is_empty() and not _is_player_unavailable(player):
            result.append(int(raw_id))
    return result

func _duration_text(days: int) -> String:
    if days <= 0: return "здоров"
    if days < 14: return "%d дн." % days
    if days < 60: return "%d нед." % int(ceil(float(days) / 7.0))
    return "около %.1f мес." % (float(days) / 30.0)

func _injury_recovery_text(player: Dictionary) -> String:
    return "восстановление %s" % _duration_text(int(player.get("injury_days", 0)))

func _player_availability_text(player: Dictionary) -> String:
    if _is_player_injured(player):
        return "%s · %s" % [player.get("injury_name", "травма"), _duration_text(int(player.get("injury_days", 0)))]
    if _is_player_suspended(player):
        return "дисквалификация · %d мат." % int(player.get("suspended_matches", 0))
    return "Готов · форма %d%%" % int(player.get("condition", 100))

func _issue_match_card(team_id: int, player_id: int, minute: int) -> void:
    var player = _player(player_id)
    if player.is_empty(): return
    if rng.randf() < 0.070:
        var sanction = _direct_red_sanction()
        _add_player_stat(player_id, "red", 1)
        _add_team_match_stat(team_id, "red", 1)
        _register_sent_off(team_id, player_id)
        _apply_match_suspension(player_id, int(sanction.get("matches", 1)), str(sanction.get("reason", "прямая красная карточка")))
        _adjust_match_rating(player_id, -1.6)
        _add_match_event("%d' ПРЯМАЯ КРАСНАЯ! %s удалён: %s. Дисквалификация — %d матч(а)." % [minute, player.get("name", "Игрок"), sanction.get("reason", "грубое нарушение"), int(sanction.get("matches", 1))])
        return
    _add_player_stat(player_id, "yellow", 1)
    _add_team_match_stat(team_id, "yellow", 1)
    _adjust_match_rating(player_id, -0.20)
    var counts: Dictionary = current_match.get("yellow_counts", {})
    var count = int(counts.get(str(player_id), 0)) + 1
    counts[str(player_id)] = count
    current_match["yellow_counts"] = counts
    if count >= 2:
        _add_player_stat(player_id, "red", 1)
        _add_team_match_stat(team_id, "red", 1)
        _register_sent_off(team_id, player_id)
        _apply_match_suspension(player_id, 1, "две жёлтые карточки в одном матче")
        _adjust_match_rating(player_id, -1.25)
        _add_match_event("%d' ВТОРАЯ ЖЁЛТАЯ! %s удалён у команды %s и пропустит следующий матч." % [minute, player.get("name", "Игрок"), _team_name(team_id)])
    else:
        _add_match_event("%d' Жёлтая карточка: %s (%s)." % [minute, player.get("name", "Игрок"), _team_name(team_id)])

func _direct_red_sanction() -> Dictionary:
    var roll = rng.randf()
    if roll < 0.50: return {"matches":1, "reason":"срыв очевидной голевой атаки"}
    if roll < 0.84: return {"matches":2, "reason":"опасный грубый подкат"}
    return {"matches":3, "reason":"агрессивное поведение"}

func _apply_match_suspension(player_id: int, matches: int, reason: String) -> void:
    var player = _player(player_id)
    player["suspended_matches"] = max(int(player.get("suspended_matches", 0)), matches)
    player["suspension_reason"] = reason
    var new_suspensions: Array = current_match.get("new_suspensions", [])
    if player_id not in new_suspensions: new_suspensions.append(player_id)
    current_match["new_suspensions"] = new_suspensions

func _clear_injured_on_pitch_after_substitution(team_id: int, out_player_id: int) -> void:
    var key = "home_injured" if team_id == int(current_match.get("home", -1)) else "away_injured"
    var injured: Array = current_match.get(key, []).duplicate()
    injured.erase(out_player_id)
    current_match[key] = injured

func _render_set_piece_assignments() -> void:
    _ensure_set_piece_assignments()
    var panel = PanelContainer.new()
    panel.add_theme_stylebox_override("panel", _panel_style(Color("102434"), Color("31566b"), 8, 1))
    content_area.add_child(panel)
    var root = VBoxContainer.new()
    root.add_theme_constant_override("separation", 7)
    panel.add_child(root)
    root.add_child(_label("Капитан и исполнители стандартов", 17, colors.mint))
    root.add_child(_label("Назначенный пенальтист и исполнитель штрафных получают бонус к реализации. Подающий угловые чаще записывает голевые передачи.", 12, colors.muted))
    var flow = HFlowContainer.new()
    flow.add_theme_constant_override("h_separation", 12)
    flow.add_theme_constant_override("v_separation", 8)
    root.add_child(flow)
    var roles = [
        {"key":"captain","label":"Капитан"}, {"key":"penalties","label":"Пенальти"},
        {"key":"free_kicks","label":"Штрафные"}, {"key":"corners","label":"Угловые"}
    ]
    var assignments: Dictionary = game_state.get("set_piece_takers", {})
    var players = _lineup_player_ids_ordered()
    for role_data in roles:
        var box = VBoxContainer.new()
        box.custom_minimum_size.x = 220
        box.add_child(_label(str(role_data["label"]), 12, colors.text))
        var option = OptionButton.new()
        var selected_index = 0
        for player_id in players:
            var index = option.item_count
            option.add_item(str(_player(int(player_id)).get("name", "Игрок")))
            option.set_item_metadata(index, int(player_id))
            if int(assignments.get(str(role_data["key"]), -1)) == int(player_id): selected_index = index
        if option.item_count > 0: option.select(selected_index)
        option.item_selected.connect(_set_piece_assignment_selected.bind(str(role_data["key"]), option))
        _style_option_button(option, 215)
        box.add_child(option)
        flow.add_child(box)

func _set_piece_assignment_selected(index: int, assignment_key: String, option: OptionButton) -> void:
    if index < 0 or index >= option.item_count: return
    var assignments: Dictionary = game_state.get("set_piece_takers", {})
    assignments[assignment_key] = int(option.get_item_metadata(index))
    game_state["set_piece_takers"] = assignments
    notice_text = "%s назначен: %s." % [_assignment_label(assignment_key), _player(int(assignments[assignment_key])).get("name", "Игрок")]
    _show_dashboard("tactics")

func _assignment_label(key: String) -> String:
    return {"captain":"Капитан", "penalties":"Пенальтист", "free_kicks":"Исполнитель штрафных", "corners":"Исполнитель угловых"}.get(key, key)

func _lineup_player_ids_ordered() -> Array:
    var result: Array = []
    for raw_slot in _formations().get(str(game_state.get("formation", "4-4-2")), []):
        var player_id = int(lineup.get(str(raw_slot.get("id", "")), -1))
        if player_id >= 0 and player_id not in result: result.append(player_id)
    return result

func _ensure_set_piece_assignments() -> void:
    if game_state.is_empty() or lineup.is_empty(): return
    var assignments: Dictionary = game_state.get("set_piece_takers", {})
    var active = _lineup_player_ids_ordered()
    for key in ["captain", "penalties", "free_kicks", "corners"]:
        if int(assignments.get(key, -1)) not in active:
            assignments[key] = _best_assignment_candidate(str(key), active)
    game_state["set_piece_takers"] = assignments

func _best_assignment_candidate(kind: String, candidates: Array) -> int:
    var best_id = -1
    var best_score = -9999.0
    for raw_id in candidates:
        var player_id = int(raw_id)
        var player = _player(player_id)
        if player.is_empty(): continue
        var role = _player_match_role(selected_team_id, player_id)
        var score = float(player.get("rating", 0))
        if kind == "captain": score += float(player.get("age", 20)) * 0.35
        elif kind == "penalties" and role in ["ST","CF","AM","RW","LW"]: score += 12.0
        elif kind == "free_kicks" and role in ["AM","CM","RW","LW","LM","RM"]: score += 10.0
        elif kind == "corners" and role in ["RW","LW","AM","LM","RM","CM"]: score += 10.0
        if score > best_score:
            best_score = score
            best_id = player_id
    return best_id

func _assigned_player(team_id: int, kind: String) -> int:
    var active = _active_team_player_ids(team_id)
    if active.is_empty(): return -1
    if team_id == selected_team_id:
        var assignments: Dictionary = game_state.get("set_piece_takers", {})
        var assigned = int(assignments.get(kind, -1))
        if assigned in active: return assigned
    var best = -1
    var score = -9999.0
    for raw_id in active:
        var player_id = int(raw_id)
        var player = _player(player_id)
        if _is_goalkeeper(player): continue
        var role = _player_match_role(team_id, player_id)
        var value = float(player.get("rating", 0))
        if kind == "penalties" and role in ["ST","CF","AM"]: value += 10.0
        elif kind == "free_kicks" and role in ["AM","CM","RW","LW"]: value += 9.0
        elif kind == "corners" and role in ["RW","LW","AM","LM","RM"]: value += 8.0
        if value > score: score = value; best = player_id
    return best

func _captain_is_active(team_id: int) -> bool:
    if team_id != selected_team_id: return false
    var captain = int((game_state.get("set_piece_takers", {}) as Dictionary).get("captain", -1))
    return captain in _active_team_player_ids(team_id)

func _is_named_set_piece_taker(team_id: int, kind: String, player_id: int) -> bool:
    return team_id == selected_team_id and int((game_state.get("set_piece_takers", {}) as Dictionary).get(kind, -1)) == player_id

func _simulate_penalty_event(attacker_id: int, defender_id: int, minute: int, attack_quality: float) -> void:
    var taker_id = _assigned_player(attacker_id, "penalties")
    if taker_id < 0: return
    var taker = _player(taker_id)
    var chance = 0.70 + clamp((float(taker.get("rating", 70)) - 70.0) * 0.004, 0.0, 0.10)
    if _is_named_set_piece_taker(attacker_id, "penalties", taker_id): chance += 0.06
    chance = clamp(chance + attack_quality * 0.04, 0.70, 0.92)
    _add_team_match_stat(attacker_id, "shots", 1)
    _add_team_match_stat(attacker_id, "shots_on_target", 1)
    if rng.randf() < chance:
        _register_set_piece_goal(attacker_id, taker_id, -1)
        _record_goal_event(attacker_id, taker_id, -1, minute, "пенальти")
        _adjust_match_rating(taker_id, 0.85)
        _add_match_event("%d' ПЕНАЛЬТИ! %s уверенно реализовал одиннадцатиметровый. %s забивает!" % [minute, taker.get("name", "Игрок"), _team_name(attacker_id)])
    else:
        _adjust_match_rating(taker_id, -0.35)
        _add_match_event("%d' ПЕНАЛЬТИ! %s не сумел переиграть вратаря %s." % [minute, taker.get("name", "Игрок"), _team_name(defender_id)])

func _simulate_free_kick_event(attacker_id: int, defender_id: int, minute: int, attack_quality: float) -> void:
    var taker_id = _assigned_player(attacker_id, "free_kicks")
    if taker_id < 0: return
    var taker = _player(taker_id)
    var chance = 0.065 + clamp((float(taker.get("rating", 70)) - 70.0) * 0.0032, 0.0, 0.075) + attack_quality * 0.035
    if _is_named_set_piece_taker(attacker_id, "free_kicks", taker_id): chance += 0.045
    chance = clamp(chance, 0.07, 0.24)
    _add_team_match_stat(attacker_id, "shots", 1)
    if rng.randf() < chance:
        _add_team_match_stat(attacker_id, "shots_on_target", 1)
        _register_set_piece_goal(attacker_id, taker_id, -1)
        _record_goal_event(attacker_id, taker_id, -1, minute, "штрафной")
        _adjust_match_rating(taker_id, 0.90)
        _add_match_event("%d' ГОЛ СО ШТРАФНОГО! %s обвёл стенку и попал точно в угол. %s забивает!" % [minute, taker.get("name", "Игрок"), _team_name(attacker_id)])
    elif rng.randf() < 0.48:
        _add_team_match_stat(attacker_id, "shots_on_target", 1)
        _add_match_event("%d' Штрафной: %s пробил в створ, но вратарь %s спас команду." % [minute, taker.get("name", "Игрок"), _team_name(defender_id)])
    else:
        _add_match_event("%d' Штрафной: %s пробил рядом со штангой." % [minute, taker.get("name", "Игрок")])

func _simulate_corner_event(attacker_id: int, defender_id: int, minute: int, attack_quality: float) -> void:
    var taker_id = _assigned_player(attacker_id, "corners")
    _add_team_match_stat(attacker_id, "corners", 1)
    var scorer = _weighted_player_pick(_active_team_player_ids(attacker_id), attacker_id, "corner", taker_id)
    var scorer_id = int(scorer.get("id", -1))
    var chance = clamp(0.055 + attack_quality * 0.055, 0.06, 0.12)
    _add_team_match_stat(attacker_id, "shots", 1)
    if scorer_id >= 0 and rng.randf() < chance:
        _add_team_match_stat(attacker_id, "shots_on_target", 1)
        _register_set_piece_goal(attacker_id, scorer_id, taker_id)
        _record_goal_event(attacker_id, scorer_id, taker_id, minute, "угловой")
        _adjust_match_rating(scorer_id, 0.85)
        if taker_id >= 0: _adjust_match_rating(taker_id, 0.35)
        _add_match_event("%d' ГОЛ ПОСЛЕ УГЛОВОГО! Подача %s, удар %s — мяч в сетке ворот %s." % [minute, _player(taker_id).get("name", "Игрок"), scorer.get("name", "Игрок"), _team_name(defender_id)])
    else:
        _add_match_event("%d' Угловой у %s: подача %s, защита выносит мяч." % [minute, _team_name(attacker_id), _player(taker_id).get("name", "Игрок")])

func _register_set_piece_goal(team_id: int, scorer_id: int, assister_id: int) -> void:
    if team_id == int(current_match.get("home", -1)):
        current_match["home_score"] = int(current_match.get("home_score", 0)) + 1
    else:
        current_match["away_score"] = int(current_match.get("away_score", 0)) + 1
    _add_player_stat(scorer_id, "goals", 1)
    if assister_id >= 0 and assister_id != scorer_id:
        _add_player_stat(assister_id, "assists", 1)

func _is_transfer_listed(player_id: int) -> bool:
    return player_id in (game_state.get("transfer_listed", []) as Array)

func _clean_transfer_list() -> void:
    var cleaned: Array = []
    for raw_id in game_state.get("transfer_listed", []):
        var player_id = int(raw_id)
        if _squad_has_player(selected_team_id, player_id) and not _is_important_player(player_id) and player_id not in cleaned:
            cleaned.append(player_id)
    game_state["transfer_listed"] = cleaned
    var offers: Array = []
    for raw_offer in game_state.get("incoming_offers", []):
        var offer: Dictionary = raw_offer
        if _squad_has_player(selected_team_id, int(offer.get("player_id", -1))) and not _is_important_player(int(offer.get("player_id", -1))):
            offers.append(offer)
    game_state["incoming_offers"] = offers

func _toggle_transfer_list_from_dialog(player_id: int, dialog: Window) -> void:
    _close_window(dialog)
    _toggle_transfer_list(player_id)

func _toggle_transfer_list(player_id: int) -> void:
    if not bool(_transfer_window_status().get("open", false)):
        notice_text = "Трансферное окно закрыто."
        _show_dashboard("transfers")
        return
    if _is_important_player(player_id):
        notice_text = "Важного игрока нельзя выставить на трансфер."
        _show_dashboard("transfers")
        return
    var listed: Array = game_state.get("transfer_listed", []).duplicate()
    if player_id in listed:
        listed.erase(player_id)
        notice_text = "%s снят с трансферного списка." % _player(player_id).get("name", "Игрок")
    else:
        listed.append(player_id)
        notice_text = "%s выставлен на трансфер. Вероятность входящего предложения заметно выросла." % _player(player_id).get("name", "Игрок")
    game_state["transfer_listed"] = listed
    _show_dashboard("transfers")

func _render_incoming_transfer_offers() -> void:
    _clean_transfer_list()
    var offers: Array = game_state.get("incoming_offers", [])
    var panel = PanelContainer.new()
    panel.add_theme_stylebox_override("panel", _panel_style(Color("102434"), Color("31566b"), 8, 1))
    content_area.add_child(panel)
    var box = VBoxContainer.new()
    box.add_theme_constant_override("separation", 7)
    panel.add_child(box)
    box.add_child(_label("Входящие предложения", 18, colors.mint))
    if offers.is_empty():
        box.add_child(_label("Пока предложений нет. Клубы могут заинтересоваться как выставленными, так и обычными игроками — кроме трёх важных.", 12, colors.muted))
        return
    for index in range(offers.size()):
        var offer: Dictionary = offers[index]
        var player_id = int(offer.get("player_id", -1))
        var bidder_id = int(offer.get("club_id", -1))
        var row = HBoxContainer.new()
        row.add_theme_constant_override("separation", 8)
        box.add_child(row)
        var text = "%s предлагает %s за %s (стоимость %s)" % [_team_name(bidder_id), _money(int(offer.get("amount", 0))), _player(player_id).get("name", "Игрок"), _money(int(_player(player_id).get("value", 0)))]
        var label = _label(text, 13, colors.text)
        label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        row.add_child(label)
        var accept = _button("ПРИНЯТЬ", true)
        accept.disabled = not bool(_transfer_window_status().get("open", false)) or _squad(selected_team_id).size() <= 14
        accept.pressed.connect(_accept_transfer_offer.bind(index))
        row.add_child(accept)
        var reject = _button("ОТКЛОНИТЬ")
        reject.pressed.connect(_reject_transfer_offer.bind(index))
        row.add_child(reject)

func _maybe_generate_transfer_offer() -> void:
    if not bool(_transfer_window_status().get("open", false)): return
    var offers: Array = game_state.get("incoming_offers", [])
    if offers.size() >= MAX_INCOMING_OFFERS: return
    var round_index = int(game_state.get("development_round", 0))
    if round_index - int(game_state.get("last_transfer_offer_round", -99)) < TRANSFER_OFFER_COOLDOWN_ROUNDS: return
    _clean_transfer_list()
    var listed: Array = game_state.get("transfer_listed", [])
    var candidates: Array = []
    var listed_mode = not listed.is_empty()
    if listed_mode:
        for raw_id in listed:
            var player_id = int(raw_id)
            if _squad_has_player(selected_team_id, player_id) and not _is_important_player(player_id): candidates.append(player_id)
        if rng.randf() > 0.32: return
    else:
        if rng.randf() > 0.07: return
        for raw_id in _squad(selected_team_id):
            var player_id = int(raw_id)
            var player = _player(player_id)
            if not _is_important_player(player_id) and int(player.get("rating", 0)) >= 76: candidates.append(player_id)
    if candidates.is_empty(): return
    var player_id = int(candidates[rng.randi_range(0, candidates.size() - 1)])
    for offer in offers:
        if int((offer as Dictionary).get("player_id", -1)) == player_id: return
    var budgets: Dictionary = game_state.get("ai_budgets", {})
    var possible_bidders: Array = []
    var base_value = int(_player(player_id).get("value", 0))
    for team in _playable_teams():
        var club_id = int(team.get("id", -1))
        if club_id == selected_team_id: continue
        if int(budgets.get(str(club_id), int(team.get("budget", 0)))) >= int(float(base_value) * 1.08): possible_bidders.append(club_id)
    if possible_bidders.is_empty(): return
    var club_id = int(possible_bidders[rng.randi_range(0, possible_bidders.size() - 1)])
    var amount = int(round(float(base_value) * rng.randf_range(1.08, 1.36) / 50000.0) * 50000.0)
    offers.append({"player_id":player_id, "club_id":club_id, "amount":amount, "season":int(game_state.get("season", 1)), "round":round_index})
    game_state["incoming_offers"] = offers
    game_state["last_transfer_offer_round"] = round_index
    notice_text = "Новое трансферное предложение: %s предлагает %s за %s." % [_team_name(club_id), _money(amount), _player(player_id).get("name", "Игрок")]

func _accept_transfer_offer(index: int) -> void:
    var offers: Array = game_state.get("incoming_offers", []).duplicate()
    if index < 0 or index >= offers.size(): return
    var offer: Dictionary = offers[index]
    var player_id = int(offer.get("player_id", -1))
    var club_id = int(offer.get("club_id", -1))
    var amount = int(offer.get("amount", 0))
    if _is_important_player(player_id) or not _squad_has_player(selected_team_id, player_id) or _squad(selected_team_id).size() <= 14:
        offers.remove_at(index); game_state["incoming_offers"] = offers; _show_dashboard("transfers"); return
    _detach_player_from_all_clubs(player_id)
    if player_id not in club_squads.get(str(club_id), []): club_squads[str(club_id)].append(player_id)
    game_state["budget"] = int(game_state.get("budget", 0)) + amount
    var budgets: Dictionary = game_state.get("ai_budgets", {})
    budgets[str(club_id)] = max(0, int(budgets.get(str(club_id), int(_team(club_id).get("budget", 0)))) - amount)
    game_state["ai_budgets"] = budgets
    _player(player_id)["contract_years"] = rng.randi_range(2, 5)
    offers.remove_at(index)
    game_state["incoming_offers"] = offers
    var history: Array = game_state.get("transfer_offer_history", [])
    history.append({"player_id":player_id,"club_id":club_id,"amount":amount,"accepted":true,"season":int(game_state.get("season",1))})
    game_state["transfer_offer_history"] = history
    _remove_player_from_transfer_system(player_id)
    _remove_from_lineup(player_id)
    notice_text = "Предложение принято: %s перешёл в %s за %s." % [_player(player_id).get("name", "Игрок"), _team_name(club_id), _money(amount)]
    _show_dashboard("transfers")

func _reject_transfer_offer(index: int) -> void:
    var offers: Array = game_state.get("incoming_offers", []).duplicate()
    if index < 0 or index >= offers.size(): return
    var offer: Dictionary = offers[index]
    offers.remove_at(index)
    game_state["incoming_offers"] = offers
    var history: Array = game_state.get("transfer_offer_history", [])
    history.append({"player_id":int(offer.get("player_id",-1)),"club_id":int(offer.get("club_id",-1)),"amount":int(offer.get("amount",0)),"accepted":false,"season":int(game_state.get("season",1))})
    game_state["transfer_offer_history"] = history
    notice_text = "Предложение %s отклонено." % _team_name(int(offer.get("club_id", -1)))
    _show_dashboard("transfers")

func _remove_player_from_transfer_system(player_id: int) -> void:
    var listed: Array = game_state.get("transfer_listed", []).duplicate()
    listed.erase(player_id)
    game_state["transfer_listed"] = listed
    var offers: Array = []
    for raw_offer in game_state.get("incoming_offers", []):
        if int((raw_offer as Dictionary).get("player_id", -1)) != player_id: offers.append(raw_offer)
    game_state["incoming_offers"] = offers

func _squad_level_name(level: String) -> String:
    return {"first":"основной состав", "reserve":"резерв", "academy":"академия"}.get(level, level)

func _squad_level_ids(team_id: int, level: String) -> Array:
    var result: Array = []
    for raw_id in _squad(team_id):
        var player = _player(int(raw_id))
        if str(player.get("squad_level", "first")) == level and not bool(player.get("retired", false)):
            result.append(int(raw_id))
    return result

func _match_squad(team_id: int) -> Array:
    var result: Array = []
    for raw_id in _squad(team_id):
        var player = _player(int(raw_id))
        if str(player.get("squad_level", "first")) == "first" and not bool(player.get("retired", false)):
            result.append(int(raw_id))
    return result

func _render_reserve() -> void:
    _render_development_squad("Резерв", "reserve")

func _render_academy() -> void:
    _render_development_squad("Академия", "academy")

func _render_development_squad(title_text: String, level: String) -> void:
    content_area.add_child(_title(title_text))
    var description = "Резервисты тренируются между турами и могут быть переведены в основу." if level == "reserve" else "Игроки 15–16 лет развиваются по потенциалу. Часть фамилий — альтернативная футбольная история, а не историческая заявка 2003/04."
    var help = _label(description, 13, colors.muted)
    help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content_area.add_child(help)
    var ids = _squad_level_ids(selected_team_id, level)
    ids.sort_custom(func(a,b): return int(_player(a).get("potential",0)) > int(_player(b).get("potential",0)))
    for raw_id in ids:
        var player_id = int(raw_id)
        var player = _player(player_id)
        var row = PanelContainer.new()
        row.add_theme_stylebox_override("panel", _panel_style(Color("0d1f2d"), Color("193447"), 7, 1))
        var h = HBoxContainer.new()
        h.add_theme_constant_override("separation", 8)
        row.add_child(h)
        h.add_child(_player_link_button(player_id, "%s · %s · %d лет" % [player.get("name","Игрок"),player.get("position","?"),player.get("age",0)], 360))
        var prospect = "потенциал %d" % int(player.get("potential", player.get("rating",0)))
        var data_note = " · альтернативная академия" if str(player.get("data_status","")).contains("alternative") else ""
        var details = _label("рейтинг %d · %s%s" % [int(player.get("rating",0)), prospect, data_note], 13, colors.mint)
        details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        h.add_child(details)
        var promote = _button("В ОСНОВУ" if level == "reserve" else "В РЕЗЕРВ")
        promote.pressed.connect(_promote_squad_player.bind(player_id, "first" if level == "reserve" else "reserve", level))
        h.add_child(promote)
        content_area.add_child(row)

func _promote_squad_player(player_id: int, target_level: String, return_tab: String) -> void:
    var player = _player(player_id)
    player["squad_level"] = target_level
    notice_text = "%s переведён: %s." % [player.get("name","Игрок"), "основная команда" if target_level == "first" else "резерв"]
    _show_dashboard(return_tab)

func _advance_reserve_academy_development() -> void:
    for team_key in club_squads.keys():
        var team_id = int(team_key)
        var youth_bonus = float(_team(team_id).get("coach_youth",1.0))
        for raw_id in club_squads[team_key]:
            var player = _player(int(raw_id))
            var level = str(player.get("squad_level","first"))
            if level not in ["reserve","academy"] or _is_player_injured(player):
                continue
            var rating = int(player.get("rating",50))
            var potential = int(player.get("potential",rating))
            if rating >= potential:
                continue
            var chance = (0.035 if level == "reserve" else 0.055) * youth_bonus
            if rng.randf() < chance:
                player["development_points"] = float(player.get("development_points",0.0)) + 1.2
                if float(player.get("development_points",0.0)) >= 7.0:
                    player["rating"] = min(potential, rating + 1)
                    player["development_points"] = float(player.get("development_points",0.0)) - 7.0
                    player["value"] = int(float(player.get("value",100000)) * 1.10)
        if team_id != selected_team_id:
            _auto_promote_ai_youth(team_id)

func _auto_promote_ai_youth(team_id: int) -> void:
    var first_ids = _squad_level_ids(team_id, "first")
    var reserve_ids = _squad_level_ids(team_id, "reserve")
    var academy_ids = _squad_level_ids(team_id, "academy")
    var first_average = 60.0
    if not first_ids.is_empty():
        var total = 0.0
        for raw_id in first_ids:
            total += float(_player(int(raw_id)).get("rating",60))
        first_average = total / float(first_ids.size())
    academy_ids.sort_custom(func(a,b): return int(_player(a).get("potential",0)) > int(_player(b).get("potential",0)))
    for raw_id in academy_ids:
        var player = _player(int(raw_id))
        if (int(player.get("age",15)) >= 17 or int(player.get("rating",0)) >= 68) and rng.randf() < 0.12:
            player["squad_level"] = "reserve"
            break
    reserve_ids.sort_custom(func(a,b): return int(_player(a).get("rating",0)) > int(_player(b).get("rating",0)))
    for raw_id in reserve_ids:
        var player = _player(int(raw_id))
        var ready = int(player.get("rating",0)) >= int(round(first_average - 4.0))
        if (first_ids.size() < 22 or ready) and rng.randf() < 0.10:
            player["squad_level"] = "first"
            break

func _apply_transfer_search(search: LineEdit) -> void:
    game_state["transfer_search"] = search.text.strip_edges()
    _show_dashboard("transfers")

func _clear_transfer_search() -> void:
    game_state["transfer_search"] = ""
    _show_dashboard("transfers")

func _transfer_market_view_ids() -> Array:
    var query = str(game_state.get("transfer_search","")).strip_edges().to_lower()
    var result: Array = []
    if not query.is_empty():
        for key in players_by_id.keys():
            var player_id = int(key)
            var player = players_by_id[key]
            if bool(player.get("retired",false)) or _squad_has_player(selected_team_id, player_id):
                continue
            if query in str(player.get("name","")).to_lower():
                result.append(player_id)
        result.sort_custom(func(a,b): return int(_player(a).get("rating",0)) > int(_player(b).get("rating",0)))
        return result.slice(0, min(100, result.size()))
    for raw_id in game_state.get("market_ids",[]):
        var pid = int(raw_id)
        if not _player(pid).is_empty() and pid not in result:
            result.append(pid)
    var recommended: Array = []
    for team in database.get("teams",[]):
        var team_id = int(team.get("id",-1))
        if team_id == selected_team_id:
            continue
        for raw_id in _squad(team_id):
            var player = _player(int(raw_id))
            if str(player.get("squad_level","first")) == "academy":
                continue
            if int(player.get("age",30)) <= 25 or str(player.get("squad_level","first")) == "reserve":
                recommended.append(int(raw_id))
    recommended.sort_custom(func(a,b): return int(_player(a).get("rating",0)) > int(_player(b).get("rating",0)))
    for pid in recommended:
        if pid not in result:
            result.append(pid)
        if result.size() >= 100:
            break
    return result

func _detach_player_from_all_clubs(player_id: int) -> void:
    for key in club_squads.keys():
        while player_id in club_squads[key]:
            club_squads[key].erase(player_id)
    player_club_index.erase(str(player_id))
    statistics_cache.clear()
    statistics_cache_revision += 1

func _loan_with_option_from_dialog(player_id: int, dialog: Window) -> void:
    _close_window(dialog)
    _loan_player_out(player_id, true)

func _playable_teams() -> Array:
    var result: Array = []
    for team in database.get("teams", []):
        if bool(team.get("playable", false)):
            result.append(team)
    return result

func _team(team_id: int) -> Dictionary:
    return teams_by_id.get(str(team_id), {})

func _team_name(team_id: int) -> String:
    return str(_team(team_id).get("name", "Неизвестный клуб"))

func _player(player_id: int) -> Dictionary:
    return players_by_id.get(str(player_id), {})

func _squad(team_id: int) -> Array:
    return club_squads.get(str(team_id), [])

func _money(value: int) -> String:
    if value >= 1000000:
        return "£%.1f млн" % (float(value) / 1000000.0)
    if value >= 1000:
        return "£%d тыс." % int(value / 1000)
    return "£%d" % value

func _dynamic_slot_data(raw_slot: Dictionary) -> Dictionary:
    var result: Dictionary = raw_slot.duplicate(true)
    var slot_id = str(result.get("id", ""))
    if slot_id == "GK":
        result["label"] = "GK"
        result["accepted"] = ["GK"]
        return result
    var formation = str(game_state.get("formation", "4-4-2"))
    var roles: Dictionary = (game_state.get("custom_roles", {}) as Dictionary).get(formation, {})
    var role = str(roles.get(slot_id, ""))
    if role.is_empty():
        var accepted: Array = result.get("accepted", [])
        role = str(accepted[0]) if not accepted.is_empty() else "CM"
    result["label"] = role
    result["accepted"] = [role]
    return result

func _role_from_coordinates(coords: Vector2) -> String:
    var x = clamp(coords.x, 0.0, 1.0)
    var y = clamp(coords.y, 0.0, 1.0)
    var left = x < 0.34
    var right = x > 0.66
    # Верх поля: наконечник, затем оттянутый форвард, затем атакующая линия.
    if y <= 0.17:
        return "LW" if left else ("RW" if right else "ST")
    if y <= 0.31:
        return "LW" if left else ("RW" if right else "CF")
    if y <= 0.45:
        return "LM" if left else ("RM" if right else "AM")
    if y <= 0.58:
        return "LM" if left else ("RM" if right else "CM")
    # Между полузащитой и линией обороны — латерали, а не крайние полузащитники.
    if y <= 0.72:
        return "LWB" if left else ("RWB" if right else "DM")
    return "LB" if left else ("RB" if right else "CB")

func _current_slot_role(slot_id: String) -> String:
    var slot = _formation_slot(slot_id)
    var accepted: Array = slot.get("accepted", [])
    return str(accepted[0]) if not accepted.is_empty() else "CM"

func _formations() -> Dictionary:
    return {
        "4-4-2": [
            {"id":"GK", "label":"ВР", "x":0.50, "y":0.90, "accepted":["GK"]},
            {"id":"LB", "label":"ЛЗ", "x":0.16, "y":0.72, "accepted":["LB"]},
            {"id":"LCB", "label":"ЦЗ", "x":0.38, "y":0.72, "accepted":["CB"]},
            {"id":"RCB", "label":"ЦЗ", "x":0.62, "y":0.72, "accepted":["CB"]},
            {"id":"RB", "label":"ПЗ", "x":0.84, "y":0.72, "accepted":["RB"]},
            {"id":"LM", "label":"ЛП", "x":0.16, "y":0.45, "accepted":["LM","LW"]},
            {"id":"LCM", "label":"ЦП", "x":0.40, "y":0.48, "accepted":["CM","DM","AM"]},
            {"id":"RCM", "label":"ЦП", "x":0.60, "y":0.48, "accepted":["CM","DM","AM"]},
            {"id":"RM", "label":"ПП", "x":0.84, "y":0.45, "accepted":["RM","RW"]},
            {"id":"LST", "label":"НАП", "x":0.38, "y":0.19, "accepted":["ST","AM"]},
            {"id":"RST", "label":"НАП", "x":0.62, "y":0.19, "accepted":["ST","AM"]}
        ],
        "4-3-3": [
            {"id":"GK", "label":"ВР", "x":0.50, "y":0.90, "accepted":["GK"]},
            {"id":"LB", "label":"ЛЗ", "x":0.16, "y":0.72, "accepted":["LB"]},
            {"id":"LCB", "label":"ЦЗ", "x":0.38, "y":0.72, "accepted":["CB"]},
            {"id":"RCB", "label":"ЦЗ", "x":0.62, "y":0.72, "accepted":["CB"]},
            {"id":"RB", "label":"ПЗ", "x":0.84, "y":0.72, "accepted":["RB"]},
            {"id":"LCM", "label":"ЦП", "x":0.28, "y":0.48, "accepted":["CM","DM"]},
            {"id":"CM", "label":"ЦП", "x":0.50, "y":0.45, "accepted":["CM","DM","AM"]},
            {"id":"RCM", "label":"ЦП", "x":0.72, "y":0.48, "accepted":["CM","DM"]},
            {"id":"LW", "label":"ЛВ", "x":0.19, "y":0.19, "accepted":["LW","LM","ST"]},
            {"id":"ST", "label":"НАП", "x":0.50, "y":0.14, "accepted":["ST"]},
            {"id":"RW", "label":"ПВ", "x":0.81, "y":0.19, "accepted":["RW","RM","ST"]}
        ],
        "4-2-3-1": [
            {"id":"GK", "label":"ВР", "x":0.50, "y":0.90, "accepted":["GK"]},
            {"id":"LB", "label":"ЛЗ", "x":0.16, "y":0.72, "accepted":["LB"]},
            {"id":"LCB", "label":"ЦЗ", "x":0.38, "y":0.72, "accepted":["CB"]},
            {"id":"RCB", "label":"ЦЗ", "x":0.62, "y":0.72, "accepted":["CB"]},
            {"id":"RB", "label":"ПЗ", "x":0.84, "y":0.72, "accepted":["RB"]},
            {"id":"LDM", "label":"ОП", "x":0.39, "y":0.54, "accepted":["DM","CM"]},
            {"id":"RDM", "label":"ОП", "x":0.61, "y":0.54, "accepted":["DM","CM"]},
            {"id":"LAM", "label":"ЛАП", "x":0.20, "y":0.33, "accepted":["LW","LM","AM"]},
            {"id":"AM", "label":"АП", "x":0.50, "y":0.31, "accepted":["AM","CM","ST"]},
            {"id":"RAM", "label":"ПАП", "x":0.80, "y":0.33, "accepted":["RW","RM","AM"]},
            {"id":"ST", "label":"НАП", "x":0.50, "y":0.13, "accepted":["ST"]}
        ],
        "3-5-2": [
            {"id":"GK", "label":"ВР", "x":0.50, "y":0.90, "accepted":["GK"]},
            {"id":"LCB", "label":"ЦЗ", "x":0.28, "y":0.70, "accepted":["CB","LB"]},
            {"id":"CB", "label":"ЦЗ", "x":0.50, "y":0.73, "accepted":["CB"]},
            {"id":"RCB", "label":"ЦЗ", "x":0.72, "y":0.70, "accepted":["CB","RB"]},
            {"id":"LWB", "label":"LWB", "x":0.13, "y":0.48, "accepted":["LWB","LB","LM","LW"]},
            {"id":"LCM", "label":"ЦП", "x":0.36, "y":0.48, "accepted":["CM","DM"]},
            {"id":"CM", "label":"ЦП", "x":0.50, "y":0.42, "accepted":["CM","DM","AM"]},
            {"id":"RCM", "label":"ЦП", "x":0.64, "y":0.48, "accepted":["CM","DM"]},
            {"id":"RWB", "label":"RWB", "x":0.87, "y":0.48, "accepted":["RWB","RB","RM","RW"]},
            {"id":"LST", "label":"НАП", "x":0.39, "y":0.17, "accepted":["ST","AM"]},
            {"id":"RST", "label":"НАП", "x":0.61, "y":0.17, "accepted":["ST","AM"]}
        ],
        "4-3-1-2": [
            {"id":"GK", "label":"GK", "x":0.50, "y":0.90, "accepted":["GK"]},
            {"id":"LB", "label":"LB", "x":0.16, "y":0.72, "accepted":["LB"]},
            {"id":"LCB", "label":"CB", "x":0.38, "y":0.72, "accepted":["CB"]},
            {"id":"RCB", "label":"CB", "x":0.62, "y":0.72, "accepted":["CB"]},
            {"id":"RB", "label":"RB", "x":0.84, "y":0.72, "accepted":["RB"]},
            {"id":"LCM", "label":"CM", "x":0.30, "y":0.50, "accepted":["CM","DM"]},
            {"id":"CM", "label":"DM", "x":0.50, "y":0.57, "accepted":["DM","CM"]},
            {"id":"RCM", "label":"CM", "x":0.70, "y":0.50, "accepted":["CM","DM"]},
            {"id":"AM", "label":"AM", "x":0.50, "y":0.34, "accepted":["AM","CF"]},
            {"id":"LST", "label":"ST", "x":0.40, "y":0.17, "accepted":["ST","CF"]},
            {"id":"RST", "label":"ST", "x":0.60, "y":0.17, "accepted":["ST","CF"]}
        ]
    }
