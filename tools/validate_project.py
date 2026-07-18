#!/usr/bin/env python3
from __future__ import annotations
import json, shutil, subprocess
from collections import Counter
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
DB_PATH=ROOT/'data'/'database.json'; MAIN_SCRIPT=ROOT/'scripts'/'main.gd'; PROJECT_PATH=ROOT/'project.godot'
SCRIPT_PATHS=[MAIN_SCRIPT,ROOT/'scripts/pitch.gd',ROOT/'scripts/player_token.gd',ROOT/'scripts/position_slot.gd']
POSITIONS={"GK","RB","RWB","LB","LWB","CB","DM","CM","AM","RM","LM","RW","LW","CF","ST"}
EXPECTED={"eng1","eng2","fra1","fra2","ger1","ger2","ned1","ned2","rus1","rus2","ita1","ita2","esp1","esp2","por1","por2"}
EXPECTED_COUNTS={'eng1':20,'eng2':24,'fra1':20,'fra2':20,'ger1':18,'ger2':18,'ned1':18,'ned2':19,'rus1':16,'rus2':22,'ita1':18,'ita2':24,'esp1':20,'esp2':22,'por1':18,'por2':18}

def validate_gdscript():
    parser=shutil.which('gdparse')
    if parser:
        for path in SCRIPT_PATHS: subprocess.run([parser,str(path)],check=True,stdout=subprocess.DEVNULL)
        print('GDScript: синтаксический разбор четырёх файлов — OK')
    else: print('GDScript: gdparse не установлен; окончательную проверку выполнит Godot')

def validate_database():
    data=json.loads(DB_PATH.read_text(encoding='utf-8')); teams=data['teams']; players=data['players']; leagues=data['leagues']
    assert {l['id'] for l in leagues}==EXPECTED
    counts=Counter(t['competition'] for t in teams); assert dict(counts)==EXPECTED_COUNTS, counts
    by_id={int(p['id']):p for p in players}; assert len(by_id)==len(players)
    assigned=set(); levels=Counter()
    for team in teams:
        assert 28<=len(team['players'])<=45,(team['name'],len(team['players']))
        assert team.get('coach_name') and team.get('league_name')
        for pid in team['players']:
            assert pid in by_id and pid not in assigned; assigned.add(pid)
    for p in players:
        assert p['position'] in POSITIONS
        assert all(pos in POSITIONS for pos in p.get('secondary',[]))
        assert 40<=int(p['rating'])<=99
        assert int(p.get('potential',p['rating']))>=int(p['rating'])
        assert p.get('squad_level') in {'first','reserve','academy'}
        levels[p['squad_level']]+=1
    assert len(teams)==315 and len(players)>=10000
    assert levels['academy']>=1500 and levels['reserve']>=2000
    print(f"База: {len(leagues)} лиг, {len(teams)} клубов, {len(players)} игроков — OK")
    print('Уровни составов:',dict(levels))

def validate_features():
    script=MAIN_SCRIPT.read_text(encoding='utf-8'); project=PROJECT_PATH.read_text(encoding='utf-8')
    assert 'textures/vram_compression/import_etc2_astc=true' in project
    required=['func _render_reserve','func _render_academy','func _transfer_market_view_ids','Поиск по имени или фамилии','func _loan_with_option_from_dialog','with_option','func _detach_player_from_all_clubs','func _advance_reserve_academy_development','func _match_squad','Версия v1.0.0','(attack - defense) / 29.0','(attack_power - defense_power) / 76.0']
    for fragment in required: assert fragment in script,fragment
    print('Функции v1.0.0: выбор лиги, резерв, академия, поиск, аренда с выкупом и баланс — OK')

def validate_strengths():
    data=json.loads(DB_PATH.read_text(encoding='utf-8')); players={p['id']:p for p in data['players']}
    def avg(team):
        rs=sorted([players[i]['rating'] for i in team['players'] if players[i]['squad_level']=='first'],reverse=True)[:11]
        return sum(rs)/len(rs)
    rus=[avg(t) for t in data['teams'] if t['competition']=='rus1']; eng=[avg(t) for t in data['teams'] if t['competition']=='eng1']
    assert max(rus)<max(eng) and sum(rus)/len(rus)<sum(eng)/len(eng)-5
    print(f"Баланс рейтингов: Россия {sum(rus)/len(rus):.1f}, Англия {sum(eng)/len(eng):.1f} — OK")

if __name__=='__main__':
    validate_gdscript(); validate_database(); validate_features(); validate_strengths(); print('Проверки проекта v1.0.0 завершены успешно.')
