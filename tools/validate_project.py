#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import shutil
import subprocess
import time
import unicodedata
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DB_PATH = ROOT / "data" / "database.json"
MAIN_SCRIPT = ROOT / "scripts" / "main.gd"
PROJECT_PATH = ROOT / "project.godot"
WORKFLOW_PATH = ROOT / ".github" / "workflows" / "build.yml"
SCRIPT_PATHS = [
    MAIN_SCRIPT,
    ROOT / "scripts" / "pitch.gd",
    ROOT / "scripts" / "player_token.gd",
    ROOT / "scripts" / "position_slot.gd",
    ROOT / "scripts" / "player_portrait.gd",
]
POSITIONS = {"GK", "RB", "RWB", "LB", "LWB", "CB", "DM", "CM", "AM", "RM", "LM", "RW", "LW", "CF", "ST"}
EXPECTED = {"eng1", "eng2", "fra1", "fra2", "ger1", "ger2", "ned1", "ned2", "rus1", "rus2", "ita1", "ita2", "esp1", "esp2", "por1", "por2"}
EXPECTED_COUNTS = {
    "eng1": 20, "eng2": 24, "fra1": 20, "fra2": 20,
    "ger1": 18, "ger2": 18, "ned1": 18, "ned2": 19,
    "rus1": 16, "rus2": 22, "ita1": 18, "ita2": 24,
    "esp1": 20, "esp2": 22, "por1": 18, "por2": 18,
}


def normalized_name(value: str) -> str:
    value = unicodedata.normalize("NFKC", value).casefold()
    return re.sub(r"[^\w]+", " ", value, flags=re.UNICODE).strip()


def validate_gdscript() -> None:
    parser = shutil.which("gdparse")
    if parser:
        for path in SCRIPT_PATHS:
            subprocess.run([parser, str(path)], check=True, stdout=subprocess.DEVNULL)
        print(f"GDScript: синтаксический разбор {len(SCRIPT_PATHS)} файлов — OK")
    else:
        print("GDScript: gdparse не установлен; окончательную проверку выполнит Godot")


def validate_database() -> tuple[dict, dict[int, dict]]:
    data = json.loads(DB_PATH.read_text(encoding="utf-8"))
    teams = data["teams"]
    players = data["players"]
    leagues = data["leagues"]
    assert str(data.get("meta", {}).get("version")) == "1.1.0"
    assert int(data.get("meta", {}).get("players_count", -1)) == len(players)
    assert {league["id"] for league in leagues} == EXPECTED
    counts = Counter(team["competition"] for team in teams)
    assert dict(counts) == EXPECTED_COUNTS, counts

    by_id = {int(player["id"]): player for player in players}
    assert len(by_id) == len(players), "Повторяющиеся ID игроков"
    assigned: set[int] = set()
    levels: Counter[str] = Counter()

    for team in teams:
        assert 28 <= len(team["players"]) <= 45, (team["name"], len(team["players"]))
        assert team.get("coach_name") and team.get("league_name")
        names: defaultdict[str, list[int]] = defaultdict(list)
        for raw_player_id in team["players"]:
            player_id = int(raw_player_id)
            assert player_id in by_id, (team["name"], player_id)
            assert player_id not in assigned, f"Игрок {player_id} находится сразу в нескольких клубах"
            assigned.add(player_id)
            name_key = normalized_name(str(by_id[player_id].get("name", "")))
            assert name_key, (team["name"], player_id, "пустое имя")
            names[name_key].append(player_id)
        duplicates = {name: ids for name, ids in names.items() if len(ids) > 1}
        assert not duplicates, f"Повтор имён в {team['name']}: {duplicates}"

    for player in players:
        assert player["position"] in POSITIONS
        assert all(position in POSITIONS for position in player.get("secondary", []))
        assert 40 <= int(player["rating"]) <= 99
        assert int(player.get("potential", player["rating"])) >= int(player["rating"])
        assert player.get("squad_level") in {"first", "reserve", "academy"}
        levels[str(player["squad_level"])] += 1

    assert len(teams) == 315 and len(players) >= 10000
    assert levels["academy"] >= 1500 and levels["reserve"] >= 2000 and levels["first"] >= 6000
    print(f"База: {len(leagues)} лиг, {len(teams)} клубов, {len(players)} уникальных игроков — OK")
    print("Уровни составов:", dict(levels))
    return data, by_id


def function_body(script: str, function_name: str) -> str:
    marker = f"func {function_name}("
    start = script.find(marker)
    assert start >= 0, function_name
    next_function = script.find("\nfunc ", start + len(marker))
    return script[start:] if next_function < 0 else script[start:next_function]


def validate_features() -> None:
    script = MAIN_SCRIPT.read_text(encoding="utf-8")
    project = PROJECT_PATH.read_text(encoding="utf-8")
    workflow = WORKFLOW_PATH.read_text(encoding="utf-8")
    portrait = (ROOT / "scripts" / "player_portrait.gd").read_text(encoding="utf-8")

    assert 'config/version="1.1.0"' in project
    assert "textures/vram_compression/import_etc2_astc=true" in project
    assert "Версия v1.1.0" in script

    match_squad = function_body(script, "_match_squad")
    assert 'squad_level", "first")) == "first"' in match_squad
    assert "reserve" not in match_squad and "academy" not in match_squad

    required = [
        "func _clean_all_squad_duplicates",
        "func _rebuild_player_club_index",
        "func _club_for_player",
        "statistics_cache",
        "func _apply_segment_fatigue",
        "func _maybe_ai_substitutions",
        "MAX_AI_SUBSTITUTIONS = 5",
        "func _render_post_match_report",
        "func _record_goal_event",
        "func _update_career_player_records",
        "career_total_apps",
        "career_total_conceded",
        "func _initialize_cup_competitions",
        "Кубок чемпионов Европы",
        "Кубок УЕФА",
        "func _apply_promotions_and_relegations",
        '"tournaments"',
        "func _render_tournaments",
        "func _render_reserve",
        "func _render_academy",
        "func _loan_with_option_from_dialog",
        "func _detach_player_from_all_clubs",
    ]
    for fragment in required:
        assert fragment in script, fragment

    assert "class_name PlayerPortrait" in portrait and "draw_circle" in portrait
    assert "УСТАНОВИТЬ_ИГРУ.cmd" in workflow and "УСТАНОВИТЬ_ИГРУ.ps1" in workflow
    assert (ROOT / "tools" / "УСТАНОВИТЬ_ИГРУ.cmd").exists()
    assert (ROOT / "tools" / "УСТАНОВИТЬ_ИГРУ.ps1").exists()
    print("Функции v1.1.0: первая команда, усталость, замены ИИ, отчёт, карьера, кубки и переходы — OK")


def validate_index_performance(data: dict) -> None:
    start = time.perf_counter()
    owner_index: dict[int, int] = {}
    for team in data["teams"]:
        for raw_player_id in team["players"]:
            owner_index[int(raw_player_id)] = int(team["id"])
    checksum = 0
    for player in data["players"]:
        checksum += owner_index[int(player["id"])]
    elapsed = time.perf_counter() - start
    assert len(owner_index) == len(data["players"])
    assert checksum > 0
    assert elapsed < 2.0, elapsed
    print(f"Индекс игрок → клуб: {len(owner_index)} записей за {elapsed:.4f} с — OK")


def validate_strengths(data: dict, players: dict[int, dict]) -> None:
    def average(team: dict) -> float:
        ratings = sorted(
            [int(players[int(player_id)]["rating"]) for player_id in team["players"] if players[int(player_id)]["squad_level"] == "first"],
            reverse=True,
        )[:11]
        return sum(ratings) / len(ratings)

    russian = [average(team) for team in data["teams"] if team["competition"] == "rus1"]
    english = [average(team) for team in data["teams"] if team["competition"] == "eng1"]
    assert max(russian) < max(english)
    assert sum(russian) / len(russian) < sum(english) / len(english) - 5
    print(f"Баланс рейтингов: Россия {sum(russian) / len(russian):.1f}, Англия {sum(english) / len(english):.1f} — OK")


if __name__ == "__main__":
    validate_gdscript()
    database, players_by_id = validate_database()
    validate_features()
    validate_index_performance(database)
    validate_strengths(database, players_by_id)
    print("Проверки проекта v1.1.0 завершены успешно.")
