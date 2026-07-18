#!/usr/bin/env python3
from __future__ import annotations
import json, random, math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DB = ROOT / 'data' / 'database.json'
rng = random.Random(1202003)

LEAGUES = [
    ('bra1','Бразилия — Серия A','Бразилия',1,[
        'Крузейро','Сантос','Сан-Паулу','Сан-Каэтано','Коритиба','Интернасьонал','Атлетико Минейро','Фламенго',
        'Гояс','Парана','Фигейренсе','Гуарани','Атлетико Паранаэнсе','Коринтианс','Витория','Флуминенсе',
        'Гремио','Крисиума','Жувентуде','Форталеза','Васко да Гама','Понте-Прета','Пайсанду','Баия'
    ]),
    ('bra2','Бразилия — Серия B','Бразилия',2,[
        'Палмейрас','Ботафого','Спорт Ресифи','Марилия','Санта-Круз','Наутико','Ремо','Америка Натал','Португеза',
        'Гама','Жоинвиль','Аваи','Сеара','Кашиас','Анаполина','Вила-Нова','Паулиста','Можи-Мирин','Лондрина',
        'КРБ','Униан Сан-Жуан','Америка Минейро','Бразильенсе','Сан-Раймундо'
    ]),
    ('arg1','Аргентина — Примера','Аргентина',1,[
        'Бока Хуниорс','Ривер Плейт','Банфилд','Сан-Лоренсо','Кильмес','Тальерес Кордова','Арсенал Саранди','Велес Сарсфилд',
        "Ньюэллс Олд Бойз",'Расинг Авельянеда','Колон','Индепендьенте','Росарио Сентраль','Эстудиантес',
        'Атлетико Рафаэла','Ланус','Олимпо','Чакарита Хуниорс','Химнасия Ла-Плата','Нуэва Чикаго'
    ]),
    ('arg2','Аргентина — Примера B Насьональ','Аргентина',2,[
        'Уракан Трес-Арройос','Институто Кордова','Архентинос Хуниорс','Альмагро','Годой-Крус','Бельграно',
        'Ферро Карриль Оэсте','Уракан','Эль-Порвенир','Тиро Федераль','Сан-Мартин Сан-Хуан','Химнасия Хухуй',
        'Дефенса и Хустисия','КАИ','Унион Санта-Фе','Дефенсорес де Бельграно','Лос-Андес','Сан-Мартин Мендоса',
        'Хувентуд Антониана','Химнасия Энтре-Риос'
    ])
]

FIRST = {
    'Бразилия':['João','Pedro','Lucas','Matheus','Rafael','Gabriel','Bruno','Felipe','Diego','Thiago','André','Marcos','Paulo','Carlos','Eduardo','Renato','Leandro','Daniel','Vítor','Fábio','Rodrigo','Alex','Roberto','Marcelo'],
    'Аргентина':['Juan','Carlos','Diego','Pablo','Martín','Nicolás','Fernando','Sergio','Javier','Gonzalo','Federico','Matías','Sebastián','Alejandro','Maximiliano','Lucas','Leandro','Ezequiel','Facundo','Hernán','Cristian','Damián','Mariano','Emiliano']
}
LAST = {
    'Бразилия':['Silva','Santos','Oliveira','Souza','Pereira','Costa','Rodrigues','Almeida','Nascimento','Lima','Araújo','Fernandes','Carvalho','Gomes','Martins','Rocha','Ribeiro','Barbosa','Moura','Moreira','Freitas','Cardoso','Correia','Teixeira'],
    'Аргентина':['González','Rodríguez','Fernández','López','Martínez','Pérez','Gómez','Sánchez','Romero','Díaz','Torres','Álvarez','Ruiz','Ramírez','Flores','Acosta','Benítez','Medina','Herrera','Suárez','Aguirre','Giménez','Molina','Castro']
}

POSITIONS=['GK','RB','LB','CB','CB','DM','CM','CM','AM','RM','LM','RW','LW','ST','ST','RB','LB','CB','CM','ST']
SECONDARY={'GK':[],'RB':['RWB','CB'],'LB':['LWB','CB'],'CB':['DM'],'DM':['CM','CB'],'CM':['DM','AM'],'AM':['CM','CF'],'RM':['RW','CM'],'LM':['LW','CM'],'RW':['RM','LW'],'LW':['LM','RW'],'ST':['CF'],'CF':['ST','AM']}

KNOWN = {
    'Крузейро':[('Gomes','GK',22,82),('Maicon','RB',22,82),('Cris','CB',26,84),('Alex','AM',25,88),('Maldonado','DM',23,81),('Zinho','CM',36,79),('Mota','LW',23,81),('Deivid','ST',23,84),('Aristizábal','ST',31,82)],
    'Сантос':[('Fábio Costa','GK',25,83),('Alex','CB',21,80),('Léo','LB',28,81),('Renato','DM',24,83),('Elano','CM',22,83),('Diego','AM',18,86),('Robinho','ST',19,86),('Ricardo Oliveira','ST',23,84)],
    'Сан-Паулу':[('Rogério Ceni','GK',30,86),('Cicinho','RB',23,78),('Fabão','CB',27,80),('Kaká','AM',21,88),('Danilo','AM',24,81),('Luís Fabiano','ST',22,87),('Diego Tardelli','ST',18,75)],
    'Коринтианс':[('Doni','GK',23,78),('Kléber','LB',23,81),('Anderson','CB',23,78),('Vampeta','DM',29,83),('Rogério','CM',26,80),('Gil','ST',23,82),('Liédson','ST',25,84)],
    'Фламенго':[('Júlio César','GK',23,84),('Juan','CB',24,84),('Athirson','LB',26,82),('Felipe','AM',25,84),('Edílson','ST',32,82)],
    'Флуминенсе':[('Kléber','GK',29,79),('Marcão','CB',27,78),('Roger','AM',25,82),('Romário','ST',37,85)],
    'Интернасьонал':[('Clemer','GK',34,80),('Índio','CB',31,79),('Daniel Carvalho','AM',20,80),('Nilmar','ST',19,81)],
    'Атлетико Паранаэнсе':[('Diego','GK',20,78),('Fernandinho','CM',18,75),('Dagoberto','ST',20,80),('Ilan','ST',22,82)],
    'Палмейрас':[('Marcos','GK',29,86),('Lúcio','LB',24,79),('Magrão','DM',24,80),('Pedrinho','AM',26,82),('Vágner Love','ST',19,83)],
    'Ботафого':[('Jefferson','GK',20,76),('Gonçalves','CB',37,76),('Valdo','AM',39,77),('Alex Alves','ST',28,79)],
    'Бока Хуниорс':[('Roberto Abbondanzieri','GK',31,85),('Hugo Ibarra','RB',29,84),('Rolando Schiavi','CB',30,84),('Nicolás Burdisso','CB',22,84),('Sebastián Battaglia','DM',22,85),('Diego Cagna','CM',33,80),('Carlos Tévez','CF',19,87),('Guillermo Barros Schelotto','ST',30,84),('Marcelo Delgado','ST',30,83)],
    'Ривер Плейт':[('Franco Costanzo','GK',23,81),('Horacio Ameli','CB',29,82),('Ricardo Rojas','LB',31,79),('Javier Mascherano','DM',19,84),('Lucho González','CM',22,84),("Andrés D'Alessandro",'AM',22,87),('Fernando Cavenaghi','ST',20,86),('Maxi López','ST',19,79)],
    'Сан-Лоренсо':[('José Ramírez','GK',27,78),('Fabricio Coloccini','CB',21,84),('Leandro Romagnoli','AM',22,84),('Alberto Acosta','ST',37,82)],
    'Расинг Авельянеда':[('Gustavo Campagnuolo','GK',30,80),('Claudio Úbeda','CB',33,79),('Diego Milito','ST',24,85),('Lisandro López','ST',20,77)],
    'Индепендьенте':[('Carlos Navarro Montoya','GK',37,80),('Gabriel Milito','CB',22,85),('Federico Insúa','AM',23,84),('Daniel Montenegro','AM',24,83)],
    'Велес Сарсфилд':[('Gastón Sessa','GK',30,79),('Fabricio Fuentes','CB',26,81),('Leandro Gracián','AM',21,80),('Roberto Nanni','ST',22,80)],
}

FUTURE = {
    'Сантос':[('Neymar','LW',['ST','RW'],15,96),('Rodrygo','RW',['LW','ST'],15,91)],
    'Фламенго':[('Vinícius Júnior','LW',['RW','ST'],15,94)],
    'Палмейрас':[('Endrick','ST',['CF'],15,94)],
    'Ривер Плейт':[('Julián Álvarez','ST',['RW','CF'],15,93),('Enzo Fernández','CM',['DM','AM'],15,92)],
    'Расинг Авельянеда':[('Lautaro Martínez','ST',['CF'],15,93)],
    'Бока Хуниорс':[('Leandro Paredes','CM',['DM','AM'],15,91)],
}
COACHES={
    'Крузейро':('Vanderlei Luxemburgo','4-2-3-1','Атака'), 'Сантос':('Emerson Leão','4-3-3','Атака'),
    'Сан-Паулу':('Roberto Rojas','4-4-2','Сбалансированно'), 'Бока Хуниорс':('Carlos Bianchi','4-4-2','Контратака'),
    'Ривер Плейт':('Manuel Pellegrini','4-3-1-2','Атака'), 'Индепендьенте':('Oscar Ruggeri','4-4-2','Сбалансированно')
}

def sec(pos):
    return [p for p in SECONDARY.get(pos,[]) if rng.random()<0.65]

def value_for(rating, age, potential):
    base=max(60000,int((rating-43)**2*17000))
    if age<=21: base=int(base*(1+max(0,potential-rating)/32))
    if age>=31: base=int(base*.62)
    return max(50000,int(round(base/50000)*50000))

def player(pid,name,age,pos,rating,level,country,potential=None,secondary=None,status='generated_south_america'):
    if potential is None: potential=max(rating,min(97,rating+rng.randint(1,13 if age<=22 else 4)))
    if secondary is None: secondary=sec(pos)
    return {'id':pid,'name':name,'age':age,'position':pos,'secondary':secondary,'rating':rating,'potential':potential,
        'squad_level':level,'value':value_for(rating,age,potential),'condition':100,'morale':75,
        'position_source':status,'data_status':status,'contract_years':rng.randint(1,5),
        'wage_weekly':max(500,int(round((rating**2)*(7 if country=='Бразилия' else 6)/500)*500)),
        'contract_source':'gameplay_estimate_not_historical_contract','injured_matches':0,'injury_name':'','injury_history':0,
        'severe_injuries':0,'development_points':0.0,'rating_changes_season':0,'last_rating_change_round':-99,'retired':False,
        'career_avg_rating':6.5,'career_rating_apps':0,'injury_days':0,'injury_details':'','injury_severity':'',
        'suspended_matches':0,'suspension_reason':'','academy_progress':0.0,'career_club_stats':{},
        'career_total_apps':0,'career_total_goals':0,'career_total_assists':0,'career_total_clean_sheets':0,'career_total_conceded':0}

def strength(country,tier,rank,n):
    if country=='Бразилия': top,bottom=(87,67) if tier==1 else (78,56)
    else: top,bottom=(87,66) if tier==1 else (77,56)
    return top+(bottom-top)*rank/max(1,n-1)

def unique_name(country, used, suffix_seed):
    for _ in range(200):
        name=f"{rng.choice(FIRST[country])} {rng.choice(LAST[country])}"
        if name.casefold() not in used:
            used.add(name.casefold()); return name
    name=f"{rng.choice(FIRST[country])} {rng.choice(LAST[country])} {suffix_seed}"
    used.add(name.casefold()); return name

data=json.loads(DB.read_text(encoding='utf-8'))
# Idempotent rebuild: remove previous South American expansion if present.
remove_comps={x[0] for x in LEAGUES}
remove_team_ids={int(t['id']) for t in data['teams'] if t.get('competition') in remove_comps}
remove_player_ids={int(pid) for t in data['teams'] if int(t['id']) in remove_team_ids for pid in t.get('players',[])}
data['teams']=[t for t in data['teams'] if int(t['id']) not in remove_team_ids]
data['players']=[p for p in data['players'] if int(p['id']) not in remove_player_ids]
data['leagues']=[l for l in data['leagues'] if l.get('id') not in remove_comps]
next_team=max(int(t['id']) for t in data['teams'])+1
next_player=max(int(p['id']) for p in data['players'])+1
used_global={str(p.get('name','')).casefold() for p in data['players']}
new_teams=[]; new_players=[]
for comp_id, league_name, country, tier, names in LEAGUES:
    data['leagues'].append({'id':comp_id,'name':league_name,'country':country,'tier':tier,'team_count':len(names),'promotion_places':2,'relegation_places':2})
    for rank,name in enumerate(names):
        team_id=next_team; next_team+=1
        base=strength(country,tier,rank,len(names))
        coach=COACHES.get(name,(f'Тренер {name}','4-4-2','Сбалансированно'))
        squad=[]; local=set()
        for pname,pos,age,rating in KNOWN.get(name,[]):
            if pname.casefold() in local: continue
            local.add(pname.casefold()); used_global.add(pname.casefold())
            level='reserve' if age<=18 and rating<78 else 'first'
            p=player(next_player,pname,age,pos,rating,level,country,potential=min(97,rating+(10 if age<=20 else 3)),status='historical_core_seed')
            next_player+=1; new_players.append(p); squad.append(p['id'])
        first_count=sum(1 for pid in squad if next(x for x in new_players if x['id']==pid)['squad_level']=='first')
        for i in range(first_count,20):
            pos=POSITIONS[i%len(POSITIONS)]; age=rng.randint(20,33); rating=int(round(base+rng.uniform(-4.2,3.0)-(1.5 if i>14 else 0)))
            pname=unique_name(country,local,next_player)
            p=player(next_player,pname,age,pos,max(48,min(91,rating)),'first',country)
            next_player+=1; new_players.append(p); squad.append(p['id'])
        reserve_count=sum(1 for pid in squad if next(x for x in new_players if x['id']==pid)['squad_level']=='reserve')
        for i in range(reserve_count,7):
            pos=POSITIONS[(i*3+2)%len(POSITIONS)]; age=rng.randint(17,23); rating=int(round(base-rng.uniform(6,12)))
            pname=unique_name(country,local,next_player)
            p=player(next_player,pname,age,pos,max(44,min(81,rating)),'reserve',country,potential=min(94,max(rating+4,rating+rng.randint(5,15))))
            next_player+=1; new_players.append(p); squad.append(p['id'])
        academy_count=0
        for pname,pos,secondary,age,pot in FUTURE.get(name,[]):
            if pname.casefold() in local: continue
            local.add(pname.casefold()); used_global.add(pname.casefold())
            rating=max(48,min(66,pot-rng.randint(28,38)))
            p=player(next_player,pname,age,pos,rating,'academy',country,potential=pot,secondary=secondary,status='alternative_future_star')
            next_player+=1; new_players.append(p); squad.append(p['id']); academy_count+=1
        for i in range(academy_count,5):
            pos=rng.choice(['GK','RB','LB','CB','DM','CM','AM','RW','LW','ST']); age=rng.randint(15,16); rating=int(round(base-rng.uniform(19,28)))
            pname=unique_name(country,local,next_player)
            p=player(next_player,pname,age,pos,max(40,min(64,rating)),'academy',country,potential=min(94,max(rating+8,rating+rng.randint(12,28))),status='generated_academy')
            next_player+=1; new_players.append(p); squad.append(p['id'])
        budget=int(max(1200000,(base-50)**2*30000*(1 if tier==1 else .65)))
        new_teams.append({'id':team_id,'name':name,'country':country,'division':'Высший дивизион' if tier==1 else 'Второй дивизион',
            'competition':comp_id,'playable':True,'budget':budget,'players':squad,'coach_name':coach[0],
            'coach_formation':coach[1] if coach[1] in ('4-4-2','4-3-3','4-2-3-1','3-5-2') else '4-4-2',
            'coach_style':coach[2],'coach_attack':round(.82+(base-55)/35,2),'coach_defense':round(.82+(base-55)/38,2),
            'coach_youth':round(rng.uniform(.88,1.28),2),'league_name':league_name,'tier':tier,'rank_seed':rank+1,
            'strength_seed':round(base,1),'historical_data_level':'historical_core_plus_generated' if name in KNOWN else 'generated_playable_squad'})

data['teams'].extend(new_teams); data['players'].extend(new_players)
data['meta'].update({'version':'1.2.0','teams_count':len(data['teams']),'players_count':len(data['players']),
    'description':'10 стран, по два дивизиона, исправленная статистика, индивидуальные указания и обновлённые карточки игроков.'})
DB.write_text(json.dumps(data,ensure_ascii=False,separators=(',',':')),encoding='utf-8')
print('extended',len(new_teams),'teams',len(new_players),'players','totals',len(data['teams']),len(data['players']))
