"""造一份番茄帳的狀態檔，給模擬器截圖走查用。用法：python3 make_state.py <情境> <輸出資料夾>

情境：idle 待機、focus 計時中、rest 休息、bell 響了、empty 全新安裝（不寫檔）。
格式跟 app 存的一樣（Core/StateEncoding.swift）。時刻用現在往回推，所以每次造出來的都是「今天」。
"""
import json
import pathlib
import sys
import time

MIN = 60 * 1000
HOUR = 60 * MIN
DAY = 24 * HOUR

scenario, out = sys.argv[1], pathlib.Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)
if scenario == "empty":
    sys.exit(0)

now = int(time.time() * 1000)


def day_key(ms):
    return time.strftime("%Y-%m-%d", time.localtime(ms / 1000))


def bean(start, length, type_id, clue="", flow=0, notes=()):
    return {
        "t": start + (length + flow) * MIN,
        "start": start,
        "typeId": type_id,
        "len": length,
        "clue": clue,
        "notes": list(notes),
        "pings": [],
        "flow": flow,
    }


days = {}


def add(start, length, type_id, **more):
    days.setdefault(day_key(start), {"beans": [], "voids": []})["beans"].append(
        bean(start, length, type_id, **more)
    )


# 今天：往回推，三顆加一次作廢，都在現在以前
add(now - 4 * HOUR, 25, "t1", clue="把第二節寫完")
add(now - 3 * HOUR, 50, "t2", flow=15, notes=["要回信給出版社"])
add(now - 100 * MIN, 30, "t3")
days[day_key(now)]["voids"].append(
    {"t": now - 60 * MIN, "typeId": "t1", "minute": 7, "reason": "訊息", "text": "去看留言"}
)
# 前幾天：有多有少，中間空一天（月檢視那天會掛葉子）
for back, plan in [(1, [(25, "t1"), (25, "t1")]), (3, [(25, "t1"), (50, "t2"), (45, "t4"), (10, "t5")])]:
    base = now - back * DAY - 5 * HOUR
    for index, (length, type_id) in enumerate(plan):
        add(base + index * 70 * MIN, length, type_id)
for back in (8, 9, 12):
    add(now - back * DAY - 6 * HOUR, 25, "t1")
    add(now - back * DAY - 5 * HOUR, 30, "t3")

current = None
if scenario == "focus":
    current = {
        "phase": "focus", "typeId": "t1", "len": 25, "startedAt": now - 9 * MIN,
        "endAt": now + 16 * MIN, "notes": ["查一下引用格式"], "pings": [], "flowed": False,
        "flowMin": 0, "done": False, "draft": "",
    }
elif scenario == "bell":
    current = {
        "phase": "focus", "typeId": "t2", "len": 50, "startedAt": now - 51 * MIN,
        "endAt": now - 1 * MIN, "notes": ["查一下引用格式"], "pings": ["小美：下午的會"],
        "flowed": False, "flowMin": 0, "done": False, "draft": "",
    }
elif scenario == "rest":
    current = {
        "phase": "rest", "typeId": "t1", "len": 25, "restStart": now - 1 * MIN,
        "endAt": now + 4 * MIN, "long": False, "msg": "收下了，這顆是完整的。",
    }

names = ["專注", "工作", "閱讀", "學習", "運動"]
lengths = [25, 50, 30, 45, 10]
colors = ["red", "purple", "orange", "yellow", "pink"]
state = {
    "v": 1,
    "settings": {
        "types": [
            {"id": f"t{i + 1}", "name": names[i], "len": lengths[i], "color": colors[i]}
            for i in range(5)
        ],
        "typeId": "t1", "restMode": "auto", "sound": False, "demo": False, "tilt": False,
        "restShort": "auto", "restLongEvery": 4, "restLongMinutes": 15, "shield": False,
        "ambience": "off", "ambienceVolume": "mid", "autoNext": False,
    },
    "current": current,
    "days": days,
    "lastLine": 0,
}
(out / "douzhang.v1.json").write_text(json.dumps(state, ensure_ascii=False), encoding="utf-8")
