import json
import os

path = 'd:/zkgame/scripts/questions.json'
with open(path, 'r', encoding='utf-8') as f:
    db = json.load(f)

db["math_olympiad"] = [
    {
      "id": "mo1",
      "question": "已知非负实数x,y,z满足x+y+z=1，求x^2+y^2+z^2+2xyz的最大值。",
      "options": ["1", "1/2", "3/4", "9/16"],
      "correct": 0
    },
    {
      "id": "mo2",
      "question": "设a,b,c是不全相等的正数，且a+b+c=3，则1/(a^2+b+c)+1/(b^2+a+c)+1/(c^2+a+b)的最大值一定小于：",
      "options": ["1", "3/2", "2", "3"],
      "correct": 0
    },
    {
      "id": "mo3",
      "question": "圆内接四边形ABCD中，AB=2，BC=3，CD=4，DA=5，则该四边形的面积是？",
      "options": ["2√6", "2√30", "4√3", "√35"],
      "correct": 1
    },
    {
      "id": "mo4",
      "question": "对于有多少个正整数n能够使 n^4 + n^2 + 1 成为一个质数？",
      "options": ["0个", "1个", "2个", "无穷多个"],
      "correct": 1
    },
    {
      "id": "mo5",
      "question": "若x,y为整数，方程 x^2 - xy + y^2 = 3 有多少组解？",
      "options": ["2组", "4组", "6组", "8组"],
      "correct": 2
    }
]

with open(path, 'w', encoding='utf-8', newline='\n') as f:
    json.dump(db, f, ensure_ascii=False, indent=2)

print("Appended math_olympiad to questions.json")
