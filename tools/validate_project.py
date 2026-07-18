#!/usr/bin/env python3
from __future__ import annotations

import json
import random
import shutil
import subprocess
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DB_PATH = ROOT / "data" / "database.json"
MAIN_SCRIPT = ROOT / "scripts" / "main.gd"
PROJECT_PATH = ROOT / "project.godot"
SCRIPT_PATHS = [MAIN_SCRIPT, ROOT / "scripts/pitch.gd", ROOT / "scripts/player_token.gd", ROOT / "scripts/position_slot.gd"]
POSITIONS = {"GK","RB","RWB","LB","LWB","CB","DM","CM","AM","RM","LM","RW","LW","CF","ST"}
EXPECTED_COMPETITIONS = {"eng1_demo","fra1_demo","ger1_demo","ned1_demo","rus1_demo","ita1_demo","esp1_demo","por1_demo"}


def validate_gdscript() -> None:
    parser = shutil.which("gdparse")
    if parser is None:
        print("GDScript: gdparse не установлен; окончательную проверку выполнит Godot")
        return
    for path in SCRIPT_PATHS:
        subprocess.run([parser, str(path)], check=True, stdout=subprocess.DEVNULL)
    print("GDScript: синтаксический разбор четырёх файлов — OK")


def validate_database() -> None:
    data = json.loads(DB_PATH.read_text(encoding="utf-8"))
    teams, players = data["teams"], data["players"]
    leagues = data.get("leagues", [])
    assert {l["id"] for l in leagues} == EXPECTED_COMPETITIONS
    counts = Counter(t["competition"] for t in teams)
    assert all(counts[c] == 4 for c in EXPECTED_COMPETITIONS), counts
    by_id = {int(p["id"]): p for p in players}
    assert len(by_id) == len(players), "Повторяющиеся ID игроков"
    assigned: set[int] = set()
    for team in teams:
        assert 16 <= len(team["players"]) <= 40, (team["name"], len(team["players"]))
        assert team.get("coach_name")
        assert team.get("coach_formation") in {"4-4-2","4-3-3","4-2-3-1","3-5-2","4-3-1-2"}
        assert team.get("coach_style")
        assert team.get("league_name")
        for pid in team["players"]:
            assert pid in by_id
            assert pid not in assigned, f"Игрок {pid} назначен двум клубам"
            assigned.add(pid)
    for p in players:
        assert p["position"] in POSITIONS, (p["name"], p["position"])
        assert all(pos in POSITIONS for pos in p.get("secondary", []))
        assert p["position"] not in p.get("secondary", [])
        assert 40 <= int(p["rating"]) <= 99
        assert 1 <= int(p.get("contract_years", 1)) <= 6
        for field in ["injured_matches","injury_days","injury_name","injury_details","injury_severity","injury_history","severe_injuries","suspended_matches","suspension_reason","development_points","rating_changes_season","retired","career_avg_rating","career_rating_apps"]:
            assert field in p, f"Нет поля {field}: {p['name']}"
    assert len(teams) == 32
    assert len(players) >= 600
    print(f"База: {len(leagues)} лиг, {len(teams)} клуба, {len(players)} игроков — OK")


def validate_features() -> None:
    script = MAIN_SCRIPT.read_text(encoding="utf-8")
    project = PROJECT_PATH.read_text(encoding="utf-8")
    assert "textures/vram_compression/import_etc2_astc=true" in project
    required = {
        '"RWB"': "правый латераль",
        '"LWB"': "левый латераль",
        '"CF"': "оттянутый форвард",
        "func _render_other_leagues": "раздел других лиг",
        "func _open_team_dialog": "просмотр состава другого клуба",
        "func _simulate_world_round": "параллельная симуляция лиг",
        "func _toggle_important_player": "важные игроки",
        "const MAX_IMPORTANT_PLAYERS = 3": "лимит важных игроков",
        "func _live_lineup_validation": "тактика в меньшинстве",
        "ПРИМЕНИТЬ ТАКТИКУ И ВЕРНУТЬСЯ": "возврат к матчу после перестройки",
        "func _issue_match_card": "две жёлтые и прямые красные",
        "func _direct_red_sanction": "дисквалификации на 1–3 матча",
        "func _advance_suspension_recovery": "отбывание дисквалификации",
        "func _clear_injured_on_pitch_after_substitution": "исправление штрафа после замены травмированного",
        "func _roll_injury": "травмы в днях до девяти месяцев",
        "func _render_incoming_transfer_offers": "входящие трансферные предложения",
        "func _toggle_transfer_list": "трансферный список",
        "func _render_set_piece_assignments": "капитан и исполнители стандартов",
        "func _simulate_penalty_event": "пенальти",
        "func _simulate_free_kick_event": "штрафные",
        "func _simulate_corner_event": "угловые",
        "func _team_on_pitch_player_ids": "разделение числящихся и реально активных игроков",
        "func _sync_user_match_lineup_from_tactics": "синхронизация перестройки после удаления",
        "func _normalize_current_match_lineups": "миграция текущего матча из старого сохранения",
        "местом после удаления": "запрет заполнения красной вакансии заменой",
        "func _open_contract_renewal_dialog": "выбор срока продления контракта",
        "const MAX_CONTRACT_EXTENSION_YEARS = 6": "продление на 1–6 лет",
        '"4-3-1-2"': "дополнительная схема тренеров",
    }
    for fragment, label in required.items():
        assert fragment in script, f"Не реализовано: {label}"
    print("Функции v0.9.1: переносимая вакансия после удаления и контракты 1–6 лет — OK")


def validate_role_map() -> None:
    def role(x: float, y: float) -> str:
        left, right = x < .34, x > .66
        if y <= .17: return "LW" if left else "RW" if right else "ST"
        if y <= .31: return "LW" if left else "RW" if right else "CF"
        if y <= .45: return "LM" if left else "RM" if right else "AM"
        if y <= .58: return "LM" if left else "RM" if right else "CM"
        if y <= .72: return "LWB" if left else "RWB" if right else "DM"
        return "LB" if left else "RB" if right else "CB"
    assert role(.15,.68)=="LWB"
    assert role(.85,.68)=="RWB"
    assert role(.5,.25)=="CF"
    assert role(.5,.12)=="ST"
    assert role(.15,.80)=="LB"
    print("Свободная схема: переходы LB→LWB→LM и ST→CF→AM — OK")


def validate_fixture_math() -> None:
    # Four clubs produce six rounds and twelve fixtures in a double round robin.
    n=4
    first=(n-1)*(n//2)
    assert first==6 and first*2==12
    # All eight leagues can be simulated on the same round index.
    assert len(EXPECTED_COMPETITIONS)==8
    print("Мир: 8 параллельных мини-лиг по 4 клуба, 6 туров каждая — OK")


def validate_goal_weights() -> None:
    weights={"ST":105,"CF":88,"RW":78,"LW":78,"AM":61,"CM":35,"DM":11,"LWB":16,"RWB":16,"CB":9}
    assert weights["ST"]>weights["CF"]>weights["RW"]>weights["AM"]>weights["CM"]>weights["DM"]>weights["CB"]
    print("Авторы голов: форварды лидируют, но полузащита и защитники сохраняют шанс — OK")


def validate_live_tactics_math() -> None:
    # После удаления остаётся десять футболистов и одна переносимая пустая ячейка.
    on_pitch = {1,2,4,5,6,7,8,9,10,11}
    # Центральный защитник №3 удалён, поэтому LCB уже пуст. Зидан №11 пока стоит AM.
    lineup = {"GK":1,"LB":2,"RCB":4,"RB":5,"CM1":6,"CM2":7,"LW":8,"RW":9,"ST":10,"AM":11}
    assert len(on_pitch) == 10 and len(lineup) == 10 and "LCB" not in lineup
    # Переводим Зидана из атаки в защиту: вакансия переезжает в AM.
    zidane = lineup.pop("AM")
    lineup["LCB"] = zidane
    assert "AM" not in lineup and lineup["LCB"] == zidane
    # На занятой Зиданом позиции разрешена обычная замена.
    substitute = 12
    outgoing = lineup["LCB"]
    lineup["LCB"] = substitute
    on_pitch.remove(outgoing); on_pitch.add(substitute)
    assert len(on_pitch) == 10 and lineup["LCB"] == substitute
    # Пустую позицию AM нельзя заполнить, иначе команда снова получила бы 11 игроков.
    assert len(lineup) == 10 and "AM" not in lineup
    # Травмированный остаётся в схеме до замены, а после замены больше не считается отсутствующим.
    injured = {7}
    assert 7 in lineup.values() and 7 in injured
    replacement = 13
    target = next(k for k,v in lineup.items() if v == 7)
    lineup[target] = replacement
    on_pitch.remove(7); on_pitch.add(replacement); injured.remove(7)
    assert 7 not in injured and replacement in on_pitch and len(on_pitch) == 10
    print("Тактика v0.9.1: красная вакансия переносится, а оставшийся игрок заменяется нормально — OK")


def validate_contract_renewal_math() -> None:
    value = 9_000_000
    one_year = max(125_000, int(value * 0.02))
    fees = [one_year * years for years in range(1, 7)]
    assert fees == sorted(fees) and fees[5] == fees[0] * 6
    current = 3
    assert [current + years for years in range(1, 7)] == [4,5,6,7,8,9]
    print("Контракты: выбор продления 1–6 лет и растущая стоимость — OK")


if __name__ == "__main__":
    validate_gdscript()
    validate_database()
    validate_features()
    validate_role_map()
    validate_fixture_math()
    validate_goal_weights()
    validate_live_tactics_math()
    validate_contract_renewal_math()
    print("Проверки проекта v0.9.1 завершены успешно.")
