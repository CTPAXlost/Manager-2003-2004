from pathlib import Path
p=Path('/mnt/data/fm_v100_work/scripts/main.gd')
s=p.read_text(encoding='utf-8')

def replace_func(name,new):
    global s
    marker=f'func {name}'
    start=s.index(marker)
    nxt=s.find('\nfunc ',start+1)
    if nxt<0: nxt=len(s)
    s=s[:start]+new.rstrip()+"\n\n"+s[nxt+1:]

# Version strings
s=s.replace('Прототип v0.9.1 · Godot 4','Версия v1.0.0 · Godot 4')
s=s.replace('Прототип v0.9.1','Версия v1.0.0')

replace_func('_show_new_game() -> void:', r'''func _show_new_game() -> void:
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
        _populate_new_game_leagues(str(country_option.get_item_metadata(0)), league_option, club_option, start, selected_info)''')

# Insert helper funcs before _new_game_button_group
insert='''func _populate_new_game_leagues(country: String, league_option: OptionButton, club_option: OptionButton, start: Button, info: Label) -> void:
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

'''
pos=s.index('func _new_game_button_group')
s=s[:pos]+insert+s[pos:]

# game_state new fields and market all empty
s=s.replace('"market_ids": database.get("market_players", []).duplicate(true),','"market_ids": database.get("market_players", []).duplicate(true),\n        "transfer_search": "",\n        "academy_promotions": [],')

# nav and dispatch
s=s.replace('["club", "СОСТАВ"], ["tactics", "ТАКТИКА"], ["match", "МАТЧ"],','["club", "СОСТАВ"], ["reserve", "РЕЗЕРВ"], ["academy", "АКАДЕМИЯ"], ["tactics", "ТАКТИКА"], ["match", "МАТЧ"],')
s=s.replace('"club": _render_club()\n        "tactics": _render_tactics()','"club": _render_club()\n        "reserve": _render_reserve()\n        "academy": _render_academy()\n        "tactics": _render_tactics()')

# first team list only
s=s.replace('var squad = _squad(selected_team_id).duplicate()\n    squad.sort_custom', 'var squad = _squad_level_ids(selected_team_id, "first")\n    squad.sort_custom',1)
# tactics bench and auto/starting helpers
s=s.replace('var sorted_squad = _squad(selected_team_id).duplicate()','var sorted_squad = _match_squad(selected_team_id)',1)
s=s.replace('for raw_id in _squad(selected_team_id):\n        var player = _player(int(raw_id))\n        if not _is_player_unavailable(player)', 'for raw_id in _match_squad(selected_team_id):\n        var player = _player(int(raw_id))\n        if not _is_player_unavailable(player)',1)
s=s.replace('for player_id in _squad(selected_team_id):\n            if int(player_id) not in remaining:', 'for player_id in _match_squad(selected_team_id):\n            if int(player_id) not in remaining:',1)
s=s.replace('for player_id in _squad(team_id):\n        var player = _player(int(player_id))\n        if _is_player_unavailable(player)', 'for player_id in _match_squad(team_id):\n        var player = _player(int(player_id))\n        if _is_player_unavailable(player)',1)

# Stronger balance
s=s.replace('var strength_probability = clamp(0.5 + (attack_power - defense_power) / 112.0, 0.15, 0.85)','var strength_probability = clamp(0.5 + (attack_power - defense_power) / 76.0, 0.10, 0.90)')
s=s.replace('var random_component = rng.randf()','var random_component = 0.22 + rng.randf() * 0.56',1)
s=s.replace('var expectation = 1.15 + (attack - defense) / 45.0 + (0.18 if home else 0.0)','var expectation = 1.08 + (attack - defense) / 29.0 + (0.20 if home else 0.0)')
s=s.replace('expectation = clamp(expectation, 0.25, 2.6)','expectation = clamp(expectation, 0.12, 3.15)')
s=s.replace('for _chance in range(5):\n        if rng.randf() < expectation / 5.0:', 'for _chance in range(6):\n        if rng.randf() < expectation / 6.0:')
s=s.replace('if rng.randf() < 0.04:\n        goals += 1','if rng.randf() < 0.025:\n        goals += 1')

# transfer UI search insertion
needle='content_area.add_child(_label("Покупка, продажа и аренда доступны только в летнее или зимнее окно. При покупке срок контракта выбирается от 1 до 6 лет.", 13, colors.muted))\n    _render_incoming_transfer_offers()'
repl='''content_area.add_child(_label("Покупка, продажа и аренда доступны только в летнее или зимнее окно. При покупке срок контракта выбирается от 1 до 6 лет.", 13, colors.muted))
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
    _render_incoming_transfer_offers()'''
s=s.replace(needle,repl)
s=s.replace('for player_id in game_state.get("market_ids", []):','for player_id in _transfer_market_view_ids():',1)

# loan button add option
s=s.replace('var loan = _button("АРЕНДА НА СЕЗОН · %s" % _money(loan_fee))\n        loan.disabled = _is_important_player(player_id) or _squad(selected_team_id).size() <= 14 or not bool(_transfer_window_status().get("open", false))\n        loan.pressed.connect(_loan_from_dialog.bind(player_id, dialog))\n        actions.add_child(loan)', '''var loan = _button("АРЕНДА НА СЕЗОН · %s" % _money(loan_fee))
        loan.disabled = _is_important_player(player_id) or _match_squad(selected_team_id).size() <= 14 or not bool(_transfer_window_status().get("open", false))
        loan.pressed.connect(_loan_from_dialog.bind(player_id, dialog))
        actions.add_child(loan)
        var loan_option = _button("АРЕНДА С ВЫКУПОМ")
        loan_option.disabled = loan.disabled
        loan_option.pressed.connect(_loan_with_option_from_dialog.bind(player_id, dialog))
        actions.add_child(loan_option)''')

# robust sell and buy ownership
s=s.replace('if owner_id >= 0:\n        club_squads[str(owner_id)].erase(player_id)','if owner_id >= 0:\n        _detach_player_from_all_clubs(player_id)')
s=s.replace('func _sell_player(player_id: int, price: int) -> void:\n    if not bool', 'func _sell_player(player_id: int, price: int) -> void:\n    if not _squad_has_player(selected_team_id, player_id):\n        notice_text = "Игрок уже не принадлежит вашему клубу."\n        _show_dashboard("transfers")\n        return\n    if not bool')
s=s.replace('club_squads[str(selected_team_id)].erase(player_id)\n    _remove_player_from_transfer_system(player_id)','_detach_player_from_all_clubs(player_id)\n    _remove_player_from_transfer_system(player_id)',1)

# load defaults
s=s.replace('if not game_state.has("lineup_confirmed"):', 'if not game_state.has("transfer_search"):\n        game_state["transfer_search"] = ""\n    if not game_state.has("academy_promotions") or not game_state.get("academy_promotions") is Array:\n        game_state["academy_promotions"] = []\n    if not game_state.has("lineup_confirmed"):')

# progression call
s=s.replace('_apply_match_development()\n    _maybe_generate_transfer_offer()', '_apply_match_development()\n    _advance_reserve_academy_development()\n    _maybe_generate_transfer_offer()')

# append functions before _playable_teams
append=r'''func _squad_level_ids(team_id: int, level: String) -> Array:
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
        if str(player.get("squad_level", "first")) != "academy" and not bool(player.get("retired", false)):
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

func _loan_with_option_from_dialog(player_id: int, dialog: Window) -> void:
    _close_window(dialog)
    _loan_player_out(player_id, true)

'''
pos=s.index('func _playable_teams() -> Array:')
s=s[:pos]+append+s[pos:]

# loan funcs replace signatures and body
s=s.replace('func _loan_player_out(player_id: int) -> void:', 'func _loan_player_out(player_id: int, with_option = false) -> void:')
old='''    var player = _player(player_id)
    var fee = int(float(player.get("value", 0)) * 0.08)
    club_squads[str(selected_team_id)].erase(player_id)
    _remove_player_from_transfer_system(player_id)
    var loans: Dictionary = game_state.get("loans_out", {})
    loans[str(player_id)] = {"return_season": int(game_state.get("season", 1)) + 1, "fee": fee}
    game_state["loans_out"] = loans
    game_state["budget"] = int(game_state.get("budget", 0)) + fee
    _remove_from_lineup(player_id)
    notice_text = "%s отдан в аренду до следующего сезона. Клуб получил %s." % [player.get("name", "Игрок"), _money(fee)]
    _show_dashboard("transfers")'''
new='''    var player = _player(player_id)
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
    _show_dashboard("transfers")'''
if old not in s: print('loan old not found')
s=s.replace(old,new)

replace_func('_return_loans() -> void:', r'''func _return_loans() -> void:
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
    game_state["loans_out"] = loans''')

# AI sales skip top/important-like players
replace_func('_ai_surplus_player(team_id: int, squad: Array) -> int:', r'''func _ai_surplus_player(team_id: int, squad: Array) -> int:
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
    return int(candidates[0]) if not candidates.is_empty() else -1''')

p.write_text(s,encoding='utf-8')
print('patched',len(s.splitlines()))
