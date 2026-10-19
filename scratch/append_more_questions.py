import json

path = 'd:/zkgame/scripts/questions.json'
with open(path, 'r', encoding='utf-8') as f:
    db = json.load(f)

new_questions = {
  "chinese": [
    {"id": "c7", "question": "《水浒传》中智取生辰纲的关键人物是：", "options": ["宋江", "吴用", "林冲", "鲁智深"], "correct": 1},
    {"id": "c8", "question": "“海内存知己，天涯若比邻”是哪位诗人的名句？", "options": ["李白", "王勃", "杜甫", "白居易"], "correct": 1},
    {"id": "c9", "question": "下列成语出处与项羽无关的是：", "options": ["破釜沉舟", "四面楚歌", "霸王别姬", "草木皆兵"], "correct": 3},
    {"id": "c10", "question": "《朝花夕拾》是鲁迅先生的一部：", "options": ["小说集", "散文集", "诗集", "戏剧选"], "correct": 1},
    {"id": "c11", "question": "“醉翁之意不在酒”的下一句是：", "options": ["在乎山水之间也", "得之心而寓之酒也", "山水之乐", "酿泉为酒"], "correct": 0},
    {"id": "c12", "question": "下列不属于中国四大古典名著的是：", "options": ["《红楼梦》", "《三国演义》", "《封神演义》", "《西游记》"], "correct": 2},
    {"id": "c13", "question": "“出淤泥而不染，濯清涟而不妖”赞美的是什么植物？", "options": ["梅花", "荷花", "菊花", "兰花"], "correct": 1},
    {"id": "c14", "question": "在中国古代科举考试中，殿试第一名称为：", "options": ["解元", "状元", "榜眼", "探花"], "correct": 1},
    {"id": "c15", "question": "《繁星·春水》的作者是：", "options": ["冰心", "老舍", "巴金", "朱自清"], "correct": 0},
    {"id": "c16", "question": "我国第一部纪传体通史是：", "options": ["《春秋》", "《史记》", "《汉书》", "《资治通鉴》"], "correct": 1}
  ],
  "math": [
    {"id": "m7", "question": "在直角三角形中，如果一直角边长为3，斜边长为5，则另一直角边长为：", "options": ["2", "4", "6", "8"], "correct": 1},
    {"id": "m8", "question": "当 x=3 时，多项式 2x^2 - x + 4 的值是多少？", "options": ["19", "25", "13", "34"], "correct": 0},
    {"id": "m9", "question": "一个正多边形的内角和是1080度，它是几边形？", "options": ["六边形", "七边形", "八边形", "九边形"], "correct": 2},
    {"id": "m10", "question": "若x，y互为相反数，则x+y的值是：", "options": ["1", "0", "-1", "无法确定"], "correct": 1},
    {"id": "m11", "question": "下列图形中，不是轴对称图形的是：", "options": ["等腰三角形", "矩形", "平行四边形", "圆"], "correct": 2},
    {"id": "m12", "question": "一件商品标价100元，打八折后的价格是：", "options": ["80元", "90元", "120元", "88元"], "correct": 0},
    {"id": "m13", "question": "抛物线 y = x^2 - 2x + 1 的顶点坐标是：", "options": ["(1, 0)", "(0, 1)", "(-1, 0)", "(1, 1)"], "correct": 0},
    {"id": "m14", "question": "若分式 (x-2)/(x+1) 的值为0，则x的值为：", "options": ["-1", "0", "2", "-2"], "correct": 2},
    {"id": "m15", "question": "绝对值小于3的所有整数的和是：", "options": ["0", "3", "6", "不存在"], "correct": 0},
    {"id": "m16", "question": "数据 3, 5, 5, 8, 9 的中位数是：", "options": ["3", "5", "6", "8"], "correct": 1}
  ],
  "english": [
    {"id": "e7", "question": "Which word has a different vowel sound?", "options": ["Cat", "Hat", "Bat", "Car"], "correct": 3},
    {"id": "e8", "question": "Neither he nor I ___ wrong.", "options": ["is", "am", "are", "were"], "correct": 1},
    {"id": "e9", "question": "I am looking forward ___ you.", "options": ["to see", "seeing", "to seeing", "see"], "correct": 2},
    {"id": "e10", "question": "He has two brothers. ___ of them is a doctor.", "options": ["Both", "Neither", "All", "None"], "correct": 1},
    {"id": "e11", "question": "You’d better ___ late for school again.", "options": ["not be", "not to be", "don't be", "won't be"], "correct": 0},
    {"id": "e12", "question": "The book ___ I borrowed yesterday is interesting.", "options": ["who", "whose", "whom", "which"], "correct": 3},
    {"id": "e13", "question": "She makes her son ___ his room every weekend.", "options": ["cleaning", "cleans", "clean", "to clean"], "correct": 2},
    {"id": "e14", "question": "I don't know if he ___. If he ___, I will call you.", "options": ["comes; comes", "will come; will come", "comes; will come", "will come; comes"], "correct": 3},
    {"id": "e15", "question": "By the end of last month, we ___ five English songs.", "options": ["have learned", "learned", "had learned", "will learn"], "correct": 2},
    {"id": "e16", "question": "There ___ a meeting tomorrow afternoon.", "options": ["is going to be", "will have", "is going to have", "have"], "correct": 0}
  ],
  "science": [
    {"id": "sc7", "question": "在太阳系中，体积最大的行星是：", "options": ["地球", "火星", "土星", "木星"], "correct": 3},
    {"id": "sc8", "question": "将红色的石蕊试液滴入酸性溶液中，试液变：", "options": ["红色", "蓝色", "紫色", "无色"], "correct": 0},
    {"id": "sc9", "question": "植物进行光合作用的主要场所是：", "options": ["线粒体", "叶绿体", "细胞核", "液泡"], "correct": 1},
    {"id": "sc10", "question": "下列哪种能源属于不可再生能源？", "options": ["太阳能", "风能", "石油", "地热能"], "correct": 2},
    {"id": "sc11", "question": "光在真空中的传播速度大致是：", "options": ["3×10^8 m/s", "340 m/s", "3×10^5 m/s", "约零"], "correct": 0},
    {"id": "sc12", "question": "食物链一般开始于：", "options": ["食草动物", "食肉动物", "绿色植物", "微生物"], "correct": 2},
    {"id": "sc13", "question": "人体有几种基本血型（ABO系统）？", "options": ["2种", "3种", "4种", "5种"], "correct": 2},
    {"id": "sc14", "question": "一标准大气压等于多少毫米水银柱？", "options": ["76", "760", "101.3", "10"], "correct": 1},
    {"id": "sc15", "question": "下列元素中，符号为“Fe”的是：", "options": ["铜", "铁", "锌", "铝"], "correct": 1},
    {"id": "sc16", "question": "力的大小单位通常是：", "options": ["千克 (kg)", "焦耳 (J)", "牛顿 (N)", "瓦特 (W)"], "correct": 2}
  ],
  "society": [
    {"id": "so7", "question": "地球仪上，地心指向北极星方向的点被称为？", "options": ["南极", "北极", "赤道", "本初子午线"], "correct": 1},
    {"id": "so8", "question": "世界三大宗教中，主要发源于阿拉伯半岛的是？", "options": ["基督教", "佛教", "伊斯兰教", "犹太教"], "correct": 2},
    {"id": "so9", "question": "我国的根本政治制度是？", "options": ["社会主义制度", "人民代表大会制度", "民族区域自治制度", "基层群众自治制度"], "correct": 1},
    {"id": "so10", "question": "14-16世纪，发源于意大利的以“人文主义”为核心的运动是：", "options": ["启蒙运动", "文艺复兴", "宗教改革", "工业革命"], "correct": 1},
    {"id": "so11", "question": "秦始皇统一六国后，规定的全国通用文字是：", "options": ["大篆", "小篆", "隶书", "楷书"], "correct": 1},
    {"id": "so12", "question": "标志着中国近代史开端的历史事件是：", "options": ["鸦片战争", "第二次鸦片战争", "甲午中日战争", "八国联军侵华战争"], "correct": 0},
    {"id": "so13", "question": "世界上最大的平原是：", "options": ["东欧平原", "西西伯利亚平原", "亚马孙平原", "长江中下游平原"], "correct": 2},
    {"id": "so14", "question": "我国的国家宪法日是每年的：", "options": ["12月4日", "10月1日", "7月1日", "1月1日"], "correct": 0},
    {"id": "so15", "question": "丝绸之路的起点是中国古代的哪座城市？", "options": ["洛阳", "长安", "建康", "燕京"], "correct": 1},
    {"id": "so16", "question": "世界上人口最多的国家目前是：", "options": ["中国", "印度", "美国", "印度尼西亚"], "correct": 1}
  ],
  "math_olympiad": [
    {"id": "mo6", "question": "如果不等式组 { x-a > 0; 3-2x > 0 } 的整数解共有3个，求a的取值范围？", "options": ["-3 < a ≤ -2", "-3 ≤ a < -2", "-4 < a ≤ -3", "-2 < a ≤ -1"], "correct": 0},
    {"id": "mo7", "question": "求方程 1/x + 1/y = 1/2012 的正整数解(x,y)的组数，且x ≤ y：", "options": ["100组", "503组", "48组", "15组"], "correct": 2},
    {"id": "mo8", "question": "已知实数x, y满足 x^3 + y^3 + 3x^2 y^2 = x^3 y^3，且x+y≠0，求x+y的最小值。", "options": ["3", "-3", "2", "-2"], "correct": 1},
    {"id": "mo9", "question": "△ABC中，若三边长分别为 a=5, b=12, c=13，则内切圆半径r与外接圆半径R的和为？", "options": ["8", "8.5", "9", "9.5"], "correct": 1},
    {"id": "mo10", "question": "用1, 2, 3, 4, 5组成没有重复数字的三位数，其中是3的倍数的有多少个？", "options": ["18", "24", "30", "36"], "correct": 1},
    {"id": "mo11", "question": "已知函数 f(x) 满足 f(x)+2f(1/x)=3x (x≠0)，则 f(2) = ?", "options": ["-1/2", "1/2", "-5/2", "5/2"], "correct": 2}
  ]
}

# Append new questions
for sub, q_list in new_questions.items():
    if sub not in db:
        db[sub] = []
    db[sub].extend(q_list)

with open(path, 'w', encoding='utf-8', newline='\n') as f:
    json.dump(db, f, ensure_ascii=False, indent=2)

total_count = sum(len(qs) for qs in db.values())
print(f"Added new questions. Total questions now: {total_count}")
for sub, q_list in db.items():
    print(f" - {sub}: {len(q_list)}")
