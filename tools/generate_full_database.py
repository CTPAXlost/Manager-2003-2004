#!/usr/bin/env python3
from __future__ import annotations
import json, random, math
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
DB=ROOT/'data'/'database.json'
rng=random.Random(200304)

# Ordered approximately by the 2003/04 final table (Russia uses calendar 2003).
LEAGUES=[
('eng1','Англия — Премьер-лига','Англия',1,[
'Арсенал','Челси','Манчестер Юнайтед','Ливерпуль','Ньюкасл Юнайтед','Астон Вилла','Чарльтон Атлетик','Болтон Уондерерс','Фулхэм','Бирмингем Сити','Мидлсбро','Саутгемптон','Портсмут','Тоттенхэм Хотспур','Блэкберн Роверс','Манчестер Сити','Эвертон','Лестер Сити','Лидс Юнайтед','Вулверхэмптон']),
('eng2','Англия — Первый дивизион','Англия',2,[
'Норвич Сити','Вест Бромвич Альбион','Сандерленд','Вест Хэм Юнайтед','Ипсвич Таун','Кристал Пэлас','Уиган Атлетик','Шеффилд Юнайтед','Рединг','Миллуолл','Ковентри Сити','Кардифф Сити','Сток Сити','Ротерхэм Юнайтед','Кру Александра','Бернли','Дерби Каунти','Ноттингем Форест','Джиллингем','Уотфорд','Престон Норт Энд','Уолсолл','Брэдфорд Сити','Уимблдон']),
('fra1','Франция — Лига 1','Франция',1,[
'Олимпик Лион','Пари Сен-Жермен','Монако','Осер','Сошо','Нант','Олимпик Марсель','Ланс','Ренн','Лилль','Страсбур','Ницца','Бордо','Тулуза','Мец','Бастия','Аяччо','Генгам','Ле-Ман','Монпелье']),
('fra2','Франция — Лига 2','Франция',2,[
'Сент-Этьен','Кан','Истр','Амьен','Лорьян','Седан','Гавр','Ньор','Геньон','Лаваль','Шатору','Нанси','Клермон','Гренобль','Кретей','Труа','Руан','Безансон','Валанс','Анже']),
('ger1','Германия — Бундеслига','Германия',1,[
'Вердер','Бавария','Байер Леверкузен','Штутгарт','Бохум','Боруссия Дортмунд','Шальке 04','Гамбург','Ганза Росток','Вольфсбург','Боруссия Мёнхенгладбах','Герта','Фрайбург','Ганновер 96','Кайзерслаутерн','Мюнхен 1860','Айнтрахт Франкфурт','Кёльн']),
('ger2','Германия — Вторая Бундеслига','Германия',2,[
'Нюрнберг','Арминия Билефельд','Майнц 05','Энерги Котбус','Алемания Ахен','Рот-Вайсс Оберхаузен','Эрцгебирге Ауэ','Гройтер Фюрт','Карлсруэ','Дуйсбург','Ваккер Бургхаузен','Рот-Вайсс Ален','Айнтрахт Трир','Унтерхахинг','Любек','Унион Берлин','Ян Регенсбург','Оснабрюк']),
('ned1','Нидерланды — Эредивизи','Нидерланды',1,[
'Аякс','ПСВ','Фейеноорд','Херенвен','АЗ Алкмар','Рода','Виллем II','Твенте','Утрехт','РБК Розендал','НЕК','АДО Ден Хааг','Гронинген','НАК Бреда','Витесс','РКК Валвейк','Волендам','Зволле']),
('ned2','Нидерланды — Первый дивизион','Нидерланды',2,[
'Ден Босх','Де Графсхап','Эксельсиор','Спарта Роттердам','Хераклес','ВВВ-Венло','Эммен','Хелмонд Спорт','МВВ Маастрихт','Гоу Эхед Иглз','Камбюр','Вендам','АГОВВ Апелдорн','Харлем','Эйндховен','Телстар','ТОП Осс','Дордрехт','Фортуна Ситтард']),
('rus1','Россия — Премьер-лига','Россия',1,[
'ЦСКА','Зенит','Рубин','Локомотив Москва','Шинник','Динамо Москва','Сатурн','Торпедо Москва','Крылья Советов','Ростов','Спартак Москва','Ротор','Уралан','Торпедо-Металлург','Черноморец Новороссийск','Спартак-Алания']),
('rus2','Россия — Первый дивизион','Россия',2,[
'Амкар','Кубань','Томь','Терек','Спартак Нальчик','Анжи','Химки','Балтика','Металлург Липецк','Динамо Брянск','Газовик-Газпром','СКА-Энергия','Арсенал Тула','Орёл','Кристалл Смоленск','Волгарь-Газпром','Локомотив Чита','Нефтехимик','Сокол Саратов','Факел Воронеж','Лада-Тольятти','Краснодар-2000']),
('ita1','Италия — Серия A','Италия',1,[
'Милан','Рома','Ювентус','Интер','Парма','Лацио','Удинезе','Сампдория','Кьево','Лечче','Брешиа','Болонья','Реджина','Сиена','Перуджа','Модена','Эмполи','Анкона']),
('ita2','Италия — Серия B','Италия',2,[
'Палермо','Кальяри','Ливорно','Мессина','Аталанта','Фиорентина','Тернана','Пьяченца','Триестина','Асколи','Виченца','Торино','Дженоа','Наполи','Венеция','Салернитана','Тревизо','Катания','Пескара','Альбинолеффе','Верона','Бари','Комо','Авеллино']),
('esp1','Испания — Примера','Испания',1,[
'Валенсия','Барселона','Депортиво','Реал Мадрид','Атлетик Бильбао','Севилья','Атлетико Мадрид','Вильярреал','Реал Бетис','Малага','Мальорка','Сарагоса','Альбасете','Реал Сосьедад','Эспаньол','Расинг Сантандер','Осасуна','Вальядолид','Сельта','Мурсия']),
('esp2','Испания — Сегунда','Испания',2,[
'Леванте','Хетафе','Нумансия','Алавес','Спортинг Хихон','Рекреативо','Эйбар','Эльче','Кадис','Херес','Тенерифе','Саламанка','Сьюдад де Мурсия','Кордова','Полидепортиво Эхидо','Альмерия','Террасса','Леганес','Лас-Пальмас','Райо Вальекано','Малага B','Альхесирас']),
('por1','Португалия — Премьер-лига','Португалия',1,[
'Порту','Бенфика','Спортинг','Брага','Насьонал','Маритиму','Витория Гимарайнш','Боавишта','Белененсеш','Жил Висенте','Морейренсе','Риу Аве','Академика','Бейра-Мар','Пасуш де Феррейра','Эштрела Амадора','Униан Лейрия','Алверка']),
('por2','Португалия — Лига де Онра','Португалия',2,[
'Эшторил','Витория Сетубал','Пенафиел','Навал','Лейшойнш','Варзин','Фейренсе','Санта-Клара','Оваренсе','Шавеш','Авеш','Марку','Майя','Портимоненсе','Салгейруш','Фелгейраш','Спортинг Ковильян','Униан Мадейра'])
]

ALIASES={
'Депортиво':'Депортиво','Олимпик Лион':'Олимпик Лион','Пари Сен-Жермен':'Пари Сен-Жермен',
'Байер Леверкузен':'Байер Леверкузен','Штутгарт':'Штутгарт','Локомотив Москва':'Локомотив Москва',
'Спортинг':'Спортинг','Боавишта':'Боавишта'
}

KNOWN={
'Ньюкасл Юнайтед':[('Shay Given','GK',28),('Aaron Hughes','CB',24),('Jonathan Woodgate','CB',23),('Titus Bramble','CB',22),('Olivier Bernard','LB',24),('Nolberto Solano','RM',28),('Kieron Dyer','CM',24),('Gary Speed','CM',34),('Jermaine Jenas','CM',20),('Alan Shearer','ST',33),('Craig Bellamy','ST',24),('Shola Ameobi','ST',21)],
'Эвертон':[('Nigel Martyn','GK',37),('Tony Hibbert','RB',22),('David Weir','CB',33),('Alan Stubbs','CB',31),('Alessandro Pistone','LB',28),('Thomas Gravesen','CM',27),('Lee Carsley','DM',29),('Kevin Kilbane','LM',26),('Wayne Rooney','ST',17),('Duncan Ferguson','ST',31),('Tomasz Radzinski','ST',29)],
'Манчестер Сити':[('David Seaman','GK',39),('Sylvain Distin','CB',25),('Richard Dunne','CB',24),('Sun Jihai','RB',26),('Joey Barton','CM',20),('Paul Bosvelt','DM',33),('Shaun Wright-Phillips','RW',21),('Nicolas Anelka','ST',24),('Robbie Fowler','ST',28)],
'Тоттенхэм Хотспур':[('Kasey Keller','GK',33),('Stephen Carr','RB',27),('Ledley King','CB',22),('Mauricio Taricco','LB',30),('Jamie Redknapp','CM',30),('Simon Davies','RM',23),('Christian Ziege','LM',31),('Robbie Keane','ST',23),('Frédéric Kanouté','ST',26),('Jermain Defoe','ST',20)],
'Атлетико Мадрид':[('Germán Burgos','GK',34),('Cosmin Contra','RB',27),('Santi Denia','CB',29),('Sergi Barjuán','LB',31),('Diego Simeone','DM',33),('Ariel Ibagaza','AM',26),('Jorge Larena','CM',21),('Fernando Torres','ST',19),('Nikolaidis','ST',29)],
'Вильярреал':[('José Reina','GK',20),('Fabricio Coloccini','CB',21),('Arruabarrena','LB',28),('Marcos Senna','DM',27),('Juan Román Riquelme','AM',25),('Roger García','CM',26),('José Mari','ST',24),('Sonny Anderson','ST',32)],
'Севилья':[('Esteban','GK',28),('Dani Alves','RB',20),('Javi Navarro','CB',29),('Pablo Alfaro','CB',34),('David Castedo','LB',29),('Julio Baptista','AM',21),('Renato','CM',24),('Jesús Navas','RW',17),('Antoñito','ST',25),('Sergio Ramos','CB',17)],
'Атлетик Бильбао':[('Dani Aranzubia','GK',24),('Andoni Iraola','RB',21),('Aitor Karanka','CB',30),('Asier del Horno','LB',22),('Carlos Gurpegui','DM',23),('Pablo Orbaiz','CM',24),('Joseba Etxeberria','RW',26),('Yeste','AM',23),('Ismael Urzaiz','ST',31)],
'Боруссия Дортмунд':[('Roman Weidenfeller','GK',23),('Christian Wörns','CB',31),('Christoph Metzelder','CB',22),('Dedê','LB',25),('Torsten Frings','CM',26),('Tomáš Rosický','AM',22),('Lars Ricken','AM',27),('Jan Koller','ST',30),('Ewerthon','ST',22)],
'Шальке 04':[('Frank Rost','GK',30),('Marcelo Bordon','CB',27),('Darío Rodríguez','LB',28),('Niels Oude Kamphuis','RB',25),('Jörg Böhme','LM',29),('Lincoln','AM',24),('Sven Vermant','CM',30),('Ebby Sand','ST',31),('Mike Hanke','ST',19)],
'Гамбург':[('Martin Pieckenhagen','GK',31),('Daniel van Buyten','CB',25),('Tomas Ujfalusi','CB',25),('Mehdi Mahdavikia','RM',26),('Sergej Barbarez','AM',31),('David Jarolím','CM',24),('Naohiro Takahara','ST',24)],
'Манчестер Юнайтед':[],
'АГОВВ Апелдорн':[('Klaas-Jan Huntelaar','ST',20)],
'Спартак Москва':[('Dmitri Khlestov','CB',32),('Dmitri Parfenov','RB',28),('Yegor Titov','AM',27),('Vasili Baranov','CM',30),('Roman Pavlyuchenko','ST',21),('Aleksandr Danishevsky','ST',19)],
'Динамо Москва':[('Roman Berezovsky','GK',29),('Dmitri Khlestov','CB',32),('Dmitri Khokhlov','CM',27),('Rolan Gusev','RM',26),('Dmitri Bulykin','ST',23)],
'Крылья Советов':[('Aleksandr Makarov','GK',25),('Andrei Tikhonov','LM',32),('Andrei Karyaka','AM',25),('Ognjen Koroman','RM',25),('Robertas Poškus','ST',24)],
'Палермо':[('Matteo Guardalben','GK',29),('Andrea Barzagli','CB',22),('Fabio Grosso','LB',25),('Eugenio Corini','CM',33),('Lamberto Zauli','AM',32),('Luca Toni','ST',26)],
'Фиорентина':[('Cristiano Lupatelli','GK',25),('Angelo Di Livio','RM',37),('Christian Riganò','ST',29)],
'Наполи':[('Marco Storari','GK',26),('Roberto Stellone','ST',26)],
'Сент-Этьен':[('Jérémie Janot','GK',25),('Zoumana Camara','CB',24),('Frédéric Mendy','RM',29),('Lilían Compan','ST',26)],
'Монако':[],
'ПСВ':[],
'Аякс':[],
'Порту':[],
'Бенфика':[],
'Спортинг':[]
}

FUTURE_ACADEMY={
'Манчестер Сити':[('Cole Palmer','AM',['RW','RM'],15,93)],
'Арсенал':[('Bukayo Saka','LW',['RW','LM'],15,92)],
'Челси':[('Mason Mount','AM',['CM','RM'],15,89)],
'Ливерпуль':[('Trent Alexander-Arnold','RB',['RWB','CM'],15,91)],
'Манчестер Юнайтед':[('Marcus Rashford','ST',['LW','RW'],15,91)],
'Тоттенхэм Хотспур':[('Harry Kane','ST',['CF'],15,93)],
'Барселона':[('Lionel Messi','RW',['AM','CF'],16,97)],
'Севилья':[('Sergio Ramos','CB',['RB','DM'],17,94)],
'Реал Мадрид':[('Dani Carvajal','RB',['RWB'],15,89)],
'Пари Сен-Жермен':[('Kylian Mbappé','ST',['RW','LW'],15,97)],
'Бавария':[('Thomas Müller','AM',['ST','RM'],15,92)],
'Аякс':[('Frenkie de Jong','CM',['DM','CB'],15,92)],
'Бенфика':[('Bernardo Silva','AM',['RW','CM'],15,92)],
'Спортинг':[('Bruno Fernandes','AM',['CM','RM'],15,91)],
'Милан':[('Gianluigi Donnarumma','GK',[],15,93)],
'Интер':[('Federico Dimarco','LB',['LWB','LM'],15,88)],
'Ювентус':[('Moise Kean','ST',['LW'],15,87)],
'ЦСКА':[('Aleksandr Golovin','CM',['AM','LM'],15,89)],
'Спартак Москва':[('Artem Dzyuba','ST',['CF'],15,87)],
'Виллем II':[('Virgil van Dijk','CB',['DM'],15,93)]
}

FIRST={
'Англия':['James','Michael','David','Paul','John','Steven','Andrew','Chris','Matthew','Daniel','Richard','Lee','Mark','Scott','Gary','Kevin','Wayne','Dean','Jamie','Ryan','Ashley','Darren','Luke','Robbie','Neil','Martin'],
'Франция':['Jean','Nicolas','Julien','Sébastien','David','Franck','Olivier','Mathieu','Anthony','Jérôme','Sylvain','Benoît','Christophe','Loïc','Mickaël','Stéphane','Florent','Pascal','Yohan','Romain'],
'Германия':['Michael','Thomas','Christian','Sebastian','Andreas','Stefan','Oliver','Daniel','Markus','Martin','Torsten','Sven','Patrick','Benjamin','Alexander','Florian','Jens','Tim','Jan','Dennis'],
'Нидерланды':['Jeroen','Mark','Dennis','Rafael','Wesley','Arjen','Robin','Maarten','Sander','Kevin','Niels','Ruud','Klaas','Roy','Danny','Edwin','Patrick','Davy','Ramon','Jordy'],
'Россия':['Александр','Алексей','Дмитрий','Сергей','Андрей','Роман','Евгений','Владимир','Игорь','Максим','Денис','Олег','Антон','Павел','Виктор','Марат','Руслан','Виталий','Константин','Юрий'],
'Италия':['Marco','Andrea','Luca','Alessandro','Matteo','Simone','Davide','Stefano','Fabio','Giuseppe','Daniele','Massimo','Cristian','Antonio','Roberto','Gianluca','Federico','Michele','Paolo','Nicola'],
'Испания':['José','David','Carlos','Sergio','Javier','Miguel','Antonio','Fernando','Raúl','Álvaro','Rubén','Iván','Diego','Víctor','Manuel','Pablo','Jorge','Alberto','Óscar','Jesús'],
'Португалия':['João','Tiago','Ricardo','Bruno','Paulo','Nuno','Hugo','Rui','Miguel','Pedro','Carlos','Fábio','André','Sérgio','Vítor','Diogo','Luís','Marco','Daniel','Jorge']}
LAST={
'Англия':['Taylor','Brown','Smith','Jones','Johnson','Williams','Walker','Wilson','Davies','Clark','White','Hall','Green','Young','Baker','Wright','Turner','Parker','Collins','Evans','Roberts','Phillips','Wood','Ward','Cook','Bell','Morris','Cooper','Morgan','Bailey','Reed','Foster','Gray','Carter','Mitchell','Murphy','Hughes','Bennett','Watson','Brooks'],
'Франция':['Martin','Bernard','Thomas','Robert','Richard','Petit','Durand','Leroy','Moreau','Simon','Laurent','Michel','Garcia','David','Bertrand','Roux','Vincent','Fournier','Girard','André','Mercier','Dupont','Lambert','Bonnet','François','Martinez','Leclerc','Garnier','Faure','Rousseau'],
'Германия':['Müller','Schmidt','Schneider','Fischer','Weber','Meyer','Wagner','Becker','Schulz','Hoffmann','Schäfer','Koch','Bauer','Richter','Klein','Wolf','Schröder','Neumann','Schwarz','Zimmermann','Braun','Krüger','Hartmann','Lange','Schmitt','Werner','Krause','Meier','Lehmann','Schmid'],
'Нидерланды':['de Jong','Jansen','de Vries','van den Berg','van Dijk','Bakker','Janssen','Visser','Smit','Meijer','de Boer','Mulder','de Groot','Bos','Vos','Peters','Hendriks','van Leeuwen','Dekker','Brouwer','de Wit','Dijkstra','Smits','de Graaf','van der Meer','Jacobs','van Dam','Vermeulen','van der Linden','Kok'],
'Россия':['Иванов','Петров','Сидоров','Смирнов','Кузнецов','Попов','Васильев','Соколов','Михайлов','Новиков','Фёдоров','Морозов','Волков','Алексеев','Лебедев','Семёнов','Егоров','Павлов','Козлов','Степанов','Николаев','Орлов','Андреев','Макаров','Захаров','Зайцев','Соловьёв','Борисов','Яковлев','Григорьев'],
'Италия':['Rossi','Russo','Ferrari','Esposito','Bianchi','Romano','Colombo','Ricci','Marino','Greco','Bruno','Gallo','Conti','De Luca','Mancini','Costa','Giordano','Rizzo','Lombardi','Moretti','Barbieri','Fontana','Santoro','Mariani','Rinaldi','Caruso','Ferrara','Galli','Martini','Leone'],
'Испания':['García','Rodríguez','González','Fernández','López','Martínez','Sánchez','Pérez','Gómez','Martín','Jiménez','Ruiz','Hernández','Díaz','Moreno','Muñoz','Álvarez','Romero','Alonso','Gutiérrez','Navarro','Torres','Domínguez','Vázquez','Ramos','Gil','Ramírez','Serrano','Blanco','Molina'],
'Португалия':['Silva','Santos','Ferreira','Pereira','Oliveira','Costa','Rodrigues','Martins','Jesus','Sousa','Fernandes','Gonçalves','Gomes','Lopes','Marques','Alves','Almeida','Ribeiro','Pinto','Carvalho','Teixeira','Moreira','Correia','Mendes','Nunes','Soares','Vieira','Monteiro','Cardoso','Rocha']}

POSITIONS=['GK','RB','LB','CB','CB','DM','CM','CM','AM','RM','LM','RW','LW','ST','ST','RB','LB','CB','CM','ST']
SECONDARY={
'RB':['RWB','CB'],'LB':['LWB','CB'],'CB':['DM'],'DM':['CM','CB'],'CM':['DM','AM'],'AM':['CM','CF'],'RM':['RW','CM'],'LM':['LW','CM'],'RW':['RM','LW'],'LW':['LM','RW'],'ST':['CF'],'CF':['ST','AM'],'GK':[]}

COACHES={
'Арсенал':('Арсен Венгер','4-4-2','Контратака'),'Манчестер Юнайтед':('Алекс Фергюсон','4-4-2','Атака'),'Челси':('Клаудио Раньери','4-3-3','Сбалансированно'),'Ливерпуль':('Жерар Улье','4-4-2','Оборона'),
'Реал Мадрид':('Карлуш Кейруш','4-2-3-1','Атака'),'Барселона':('Франк Райкард','4-3-3','Атака'),'Валенсия':('Рафаэль Бенитес','4-2-3-1','Контратака'),'Милан':('Карло Анчелотти','4-3-1-2','Сбалансированно'),'Ювентус':('Марчелло Липпи','4-4-2','Сбалансированно'),'Интер':('Альберто Дзаккерони','3-4-3','Атака'),'Рома':('Фабио Капелло','3-4-1-2','Атака'),
'Порту':('Жозе Моуринью','4-4-2','Контратака'),'Бенфика':('Хосе Антонио Камачо','4-3-3','Атака'),'Спортинг':('Фернанду Сантуш','4-4-2','Сбалансированно'),'Аякс':('Рональд Куман','4-3-3','Атака'),'ПСВ':('Гус Хиддинк','4-3-3','Сбалансированно'),'Бавария':('Оттмар Хитцфельд','4-4-2','Атака'),'Вердер':('Томас Шааф','4-4-2','Атака'),'ЦСКА':('Валерий Газзаев','4-4-2','Сбалансированно'),'Локомотив Москва':('Юрий Сёмин','4-4-2','Контратака')}


def base_strength(country,tier,rank,n):
    if tier==1:
        top=90 if country in ('Англия','Италия','Испания') else 87
        bottom=69 if country not in ('Россия',) else 62
        if country=='Россия': top=78
        if country=='Португалия': top=85; bottom=67
        if country=='Нидерланды': top=86; bottom=66
        if country=='Франция': top=86; bottom=68
        if country=='Германия': top=87; bottom=68
    else:
        top=78 if country in ('Англия','Италия','Испания','Германия','Франция') else 74
        bottom=58 if country!='Россия' else 52
        if country=='Россия': top=68
    frac=rank/max(1,n-1)
    return top+(bottom-top)*frac

def sec_for(pos):
    vals=SECONDARY.get(pos,[])
    out=[]
    for v in vals:
        if rng.random()<0.62: out.append(v)
    return out

def value_for(rating,age,potential):
    base=max(80000, int((rating-45)**2*21000))
    if age<=21: base=int(base*(1+max(0,potential-rating)/35))
    if age>=31: base=int(base*0.65)
    return max(50000,int(round(base/50000)*50000))

def make_player(pid,name,age,pos,rating,level,country,potential=None,secondary=None,status='generated_expansion'):
    if potential is None:
        potential=max(rating,min(96,rating+rng.randint(0,12 if age<=22 else 3)))
    if secondary is None: secondary=sec_for(pos)
    return {'id':pid,'name':name,'age':age,'position':pos,'secondary':secondary,'rating':rating,'potential':potential,
            'squad_level':level,'value':value_for(rating,age,potential),'condition':100,'morale':75,
            'position_source':status,'data_status':status,'contract_years':rng.randint(1,5),
            'wage_weekly':max(500,int(round((rating**2)*(9 if country!='Россия' else 5)/500)*500)),
            'contract_source':'gameplay_estimate_not_historical_contract','injured_matches':0,'injury_name':'','injury_history':0,
            'severe_injuries':0,'development_points':0.0,'rating_changes_season':0,'last_rating_change_round':-99,
            'retired':False,'career_avg_rating':6.5,'career_rating_apps':0,'injury_days':0,'injury_details':'','injury_severity':'',
            'suspended_matches':0,'suspension_reason':'','academy_progress':0.0}

def generated_name(country,used):
    for _ in range(1000):
        name=f"{rng.choice(FIRST[country])} {rng.choice(LAST[country])}"
        if name not in used:
            used.add(name); return name
    name=f"{rng.choice(FIRST[country])} {rng.choice(LAST[country])} {len(used)}"; used.add(name); return name

old=json.load(open(ROOT/'tools'/'base_database_v091.json',encoding='utf-8'))
old_teams={t['name']:t for t in old['teams']}
old_players={p['id']:p for p in old['players']}
max_team=max(t['id'] for t in old['teams'])
next_team=max_team+1
next_player=max(p['id'] for p in old['players'])+1
new_teams=[]; new_players=[]; used_names=set(p['name'] for p in old['players'])
team_id_by_name={}

# first create/update teams
for comp_id,league_name,country,tier,names in LEAGUES:
    for rank,name in enumerate(names):
        if name in old_teams:
            t=dict(old_teams[name]); tid=t['id']
        else:
            tid=next_team; next_team+=1; t={'id':tid,'name':name,'players':[]}
        team_id_by_name[name]=tid
        strength=base_strength(country,tier,rank,len(names))
        coach=COACHES.get(name,(f'Тренер {name}','4-4-2','Сбалансированно'))
        t.update({'country':country,'division':'Высший дивизион' if tier==1 else 'Второй дивизион','tier':tier,
                  'competition':comp_id,'league_name':league_name,'playable':True,'rank_seed':rank+1,
                  'strength_seed':round(strength,1),'budget':int(max(1000000,(strength-52)**2*38000*(1.0 if tier==1 else .72))),
                  'coach_name':coach[0],'coach_formation':coach[1] if coach[1] in ('4-4-2','4-3-3','4-2-3-1','3-5-2') else '4-4-2',
                  'coach_style':coach[2],'coach_attack':round(0.8+(strength-55)/35,2),'coach_defense':round(0.8+(strength-55)/38,2),
                  'coach_youth':round(rng.uniform(.85,1.25),2),'historical_data_level':'expanded_core' if name in old_teams or name in KNOWN else 'generated_playable_squad'})
        new_teams.append(t)

# players team by team
for t in new_teams:
    name=t['name']; country=t['country']; base=float(t['strength_seed']); squad=[]
    existing=[]
    if name in old_teams:
        existing=[old_players[i] for i in old_teams[name].get('players',[]) if i in old_players]
        existing.sort(key=lambda p:p.get('rating',0),reverse=True)
        for idx,p0 in enumerate(existing):
            p=dict(p0)
            if country=='Россия':
                p['rating']=max(50,int(p.get('rating',60))-6)
                p['value']=int(p.get('value',1000000)*0.65)
            p['squad_level']='academy' if int(p.get('age',25))<=16 else ('reserve' if int(p.get('age',25))<=18 and int(p.get('rating',60))<76 else ('first' if idx<20 else 'reserve'))
            p['potential']=int(p.get('potential',min(96,int(p.get('rating',60))+(8 if int(p.get('age',25))<=22 else 2))))
            p['data_status']='historical_core'
            new_players.append(p); squad.append(p['id']); used_names.add(p['name'])
    # known historical core for new clubs
    known=KNOWN.get(name,[])
    for idx,(pname,pos,age) in enumerate(known):
        if pname in used_names: continue
        rating=int(round(base+rng.uniform(-2.5,3.5)))
        youth_ratings={'Wayne Rooney':84,'Fernando Torres':83,'Sergio Ramos':72,'Klaas-Jan Huntelaar':73,'Jesús Navas':70}
        if pname in youth_ratings: rating=youth_ratings[pname]
        level='reserve' if age<=18 and rating<78 else 'first'
        p=make_player(next_player,pname,age,pos,max(55,min(91,rating)),level,country,status='historical_core_seed')
        next_player+=1; new_players.append(p); squad.append(p['id']); used_names.add(pname)
    # fill first team to 20
    existing_first=sum(1 for pid in squad if next((p for p in new_players if p['id']==pid),{}).get('squad_level')=='first')
    for i in range(existing_first,20):
        pos=POSITIONS[i%len(POSITIONS)]
        age=rng.randint(20,33)
        rating=int(round(base+rng.uniform(-4.5,3.0)-(2.0 if i>=14 else 0)))
        p=make_player(next_player,generated_name(country,used_names),age,pos,max(48,min(92,rating)),'first',country)
        next_player+=1; new_players.append(p); squad.append(p['id'])
    # reserve to 7, preserve historical extras
    existing_res=sum(1 for pid in squad if next((p for p in new_players if p['id']==pid),{}).get('squad_level')=='reserve')
    for i in range(existing_res,7):
        pos=POSITIONS[(i*3+2)%len(POSITIONS)]
        age=rng.randint(17,24)
        rating=int(round(base-rng.uniform(5,11)))
        p=make_player(next_player,generated_name(country,used_names),age,pos,max(44,min(82,rating)),'reserve',country,potential=min(94,max(rating+2,rating+rng.randint(4,14))))
        next_player+=1; new_players.append(p); squad.append(p['id'])
    # academy: special future star + generated 15-16 year olds
    specials=FUTURE_ACADEMY.get(name,[])
    academy_count=0
    for pname,pos,secondary,age,pot in specials:
        if pname in used_names:
            # existing real player (e.g. Sergio Ramos) gets academy/future metadata only if present
            for p in new_players:
                if p['name']==pname and p['id'] in squad:
                    p['potential']=max(int(p.get('potential',p.get('rating',60))),pot); p['data_status']='historical_or_alternative_future_star'
                    if int(p.get('age',20))<=16: p['squad_level']='academy'
                    elif int(p.get('age',20))<=18 and int(p.get('rating',60))<78: p['squad_level']='reserve'
            continue
        rating=max(47,min(68,pot-rng.randint(27,39)))
        p=make_player(next_player,pname,age,pos,rating,'academy',country,potential=pot,secondary=secondary,status='alternative_timeline_academy')
        next_player+=1; new_players.append(p); squad.append(p['id']); used_names.add(pname); academy_count+=1
    while academy_count<5:
        pos=rng.choice(['GK','RB','LB','CB','DM','CM','AM','RW','LW','ST'])
        age=rng.choice([15,16])
        rating=rng.randint(43,61)
        high=rng.random()<0.28
        potential=min(94,rating+rng.randint(18,32)) if high else min(82,rating+rng.randint(4,18))
        p=make_player(next_player,generated_name(country,used_names),age,pos,rating,'academy',country,potential=potential,status='generated_academy')
        next_player+=1; new_players.append(p); squad.append(p['id']); academy_count+=1
    t['players']=squad

leagues=[]
for comp_id,name,country,tier,teams in LEAGUES:
    leagues.append({'id':comp_id,'name':name,'country':country,'tier':tier,'team_count':len(teams),'promotion_places':3 if tier==2 else 0,'relegation_places':3 if tier==1 else 0})

out={'meta':dict(old.get('meta',{})),'teams':new_teams,'players':new_players,'market_players':[],'leagues':leagues}
out['meta'].update({'version':'1.0.0','description':'Полная экспериментальная структура: 8 стран, по два дивизиона, основной состав, резерв и академия.',
                    'note':'Исторические ядра сохранены и расширены. Для большого числа клубов составы и резерв являются авторскими игровыми заполнителями; академии содержат как вымышленных игроков, так и альтернативно молодых будущих звёзд.',
                    'teams_count':len(new_teams),'players_count':len(new_players),'data_limitations':'Не копирует базы Championship Manager/Football Manager; рейтинги, контракты и часть расширенных составов авторские.'})
DB.write_text(json.dumps(out,ensure_ascii=False,indent=2),encoding='utf-8')
print('generated',len(new_teams),'teams',len(new_players),'players',next_team,next_player)
from collections import Counter
print(Counter((t['country'],t['tier']) for t in new_teams))
