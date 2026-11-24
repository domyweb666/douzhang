"""造三份假使用者的番茄帳狀態檔，給分析頁的驗證用（.analytics/09-驗證/驗證計畫.md）。

用法：python3 make_users.py <day5|week3|back>[-bell] <輸出資料夾> [現在的毫秒時刻]

  day5   第 5 天：資料不夠的每一句
  week3  第 3 週：平常的每一句，每個數字都過門檻
  back   回來：前 18 天正常、空 23 天、今天剛回來
  加 -bell：再放一顆剛響的番茄，開起來就是鈴響頁

格式是 v2（Core/StateEncoding.swift）。時刻從現在往回推，所以每次造出來的都是「今天」。
另外用這支腳本自己的算法（沒有抄 app 的程式）把分析頁該出現的字算一次，印出來並存成 expected.json：
那一份就是讀圖題與資料對不對的標準答案。app 畫出來的跟它不一樣，就是其中一邊算錯。
"""
import datetime
import json
import math
import pathlib
import sys
import time

MIN = 60 * 1000
HOUR = 60 * MIN
DAY = 24 * HOUR

arg, out = sys.argv[1], pathlib.Path(sys.argv[2])
bell = arg.endswith("-bell")
who = arg[: -len("-bell")] if bell else arg
now = int(sys.argv[3]) if len(sys.argv) > 3 else int(time.time() * 1000)
out.mkdir(parents=True, exist_ok=True)
# 時區名：雲端機器是 UTC，app 認得；認不得的名字 app 會退回手機現在的時區，日期一樣對得上
ZONE = time.tzname[0]

TYPES = [("t1", "專注", 25, "red"), ("t2", "工作", 50, "purple"), ("t3", "閱讀", 30, "orange"),
         ("t4", "學習", 45, "yellow"), ("t5", "運動", 10, "pink")]
LEN = {type_id: length for type_id, _, length, _ in TYPES}
REMOVED = {"id": "t9", "name": "剪片", "len": 50, "color": "purple"}


def local(ms):
    return time.localtime(ms / 1000)


def day_key(ms):
    return time.strftime("%Y-%m-%d", local(ms))


TODAY = local(now)


def at(back, hour, minute=0):
    """back 天前的本地幾點幾分。"""
    parts = (TODAY.tm_year, TODAY.tm_mon, TODAY.tm_mday - back, hour, minute, 0, 0, 0, -1)
    return int(time.mktime(parts) * 1000)


days = {}


def day_of(start):
    return days.setdefault(day_key(start), {"beans": [], "voids": []})


def keep(start, type_id, flow=0, done=False, notes=(), pings=(), clue="", zone=ZONE, length=None):
    length = length or LEN.get(type_id, 25)
    bean = {"id": f"r{start}", "t": start + (length + flow) * MIN, "start": start, "typeId": type_id,
            "len": length, "clue": clue, "notes": list(notes), "pings": list(pings), "flow": flow}
    if zone:
        bean["tz"] = zone
    if done:
        bean["done"] = True
        bean["doneAt"] = start + (length - 6) * MIN
    day_of(start)["beans"].append(bean)


def void(start, type_id, minute, reason="", text="", notes=(), pings=()):
    day_of(start)["voids"].append({
        "id": f"r{start}", "t": start + minute * MIN, "start": start, "tz": ZONE, "typeId": type_id,
        "len": LEN[type_id], "minute": minute, "reason": reason, "text": text,
        "notes": list(notes), "pings": list(pings),
    })


def today_beans(specs):
    """今天的幾顆：從現在往回排，排到午夜以前的就不放（半夜產生時今天會比較少）。"""
    midnight = at(0, 0)
    for back_minutes, type_id, more in specs:
        start = now - back_minutes * MIN
        if start >= midnight:
            keep(start, type_id, **more)


def plain_day(back, kept, first="t1"):
    """平常的一天：九點起每 70 分鐘一顆，第一顆是 first，後面輪流。"""
    cycle = ["t2", "t3", "t4", "t3", "t2", "t5", "t3"]
    for index in range(kept):
        keep(at(back, 9, 0) + index * 70 * MIN, first if index == 0 else cycle[index % len(cycle)])


def build_day5():
    keep(at(4, 9), "t1")
    keep(at(4, 10), "t1")
    keep(at(3, 9, 30), "t1")
    keep(at(3, 14), "t3")
    keep(at(3, 15), "t2")
    keep(at(2, 9), "t2", flow=15)
    void(at(2, 11), "t3", 8, reason="念頭")
    keep(at(1, 10), "t3")
    keep(at(1, 13), "t2")
    keep(at(1, 16), "t1", notes=["查匯率"], pings=[""], clue="把報價單寄出去")
    today_beans([(150, "t3", {}), (100, "t2", {})])


def build_week3():
    # 20 天前到昨天，一天收幾顆；0 是沒開的日子。有開的 16 天裡 12 天第一顆是「專注」，其他 4 天是「工作」
    kept = [4, 5, 0, 6, 4, 5, 3, 0, 0, 5, 6, 4, 4, 5, 0, 6, 5, 4, 7, 5]
    work_first = {4, 10, 16, 18}
    for index, count in enumerate(kept):
        if count:
            plain_day(20 - index, count, first="t2" if index in work_first else "t1")
    # 「專注」25 分最近 28 天：12 顆收下，其中延長 2、提早做完 1，剩下 9 顆響了就收；下面再作廢 2 顆
    marked = [bean for key in sorted(days) for bean in days[key]["beans"] if bean["typeId"] == "t1"]
    marked[2]["flow"] = 15
    marked[7]["flow"] = 30
    marked[9]["done"] = True
    marked[9]["doneAt"] = marked[9]["start"] + 19 * MIN
    # 作廢六顆（都在最近兩週）：有人找 3（一顆是以前存的「訊息」）、念頭 1、卡住 1、沒選 1
    void(at(11, 16), "t1", 12, reason="訊息", text="去看留言")
    void(at(9, 16), "t1", 18, reason="有人找", pings=[""])
    void(at(8, 17), "t3", 9, reason="有人找")
    void(at(6, 16), "t2", 22, reason="念頭", notes=["想到要訂車票"])
    void(at(4, 17), "t4", 15, reason="卡住")
    void(at(2, 17), "t3", 7)
    # 記一筆（最近兩週合計念頭 6、有人找 3，含上面作廢帶的那兩筆）
    keep(at(10, 19), "t3", notes=["回信給編輯", ""], pings=["客戶問報價"])
    keep(at(7, 19), "t3", notes=["", "查引用格式"])
    keep(at(3, 19), "t3", notes=["晚上要買菜"], pings=[""])
    # 邊界情況：跨午夜、半夜十二點半、在東京開的一顆、沒有時區的舊番茄、刪掉的標籤、升級前就刪掉的標籤
    keep(at(6, 23, 50), "t3")
    keep(at(4, 0, 30), "t5")
    keep(at(5, 20), "t3", zone="Asia/Tokyo")
    keep(at(13, 20), "t1", zone=None)
    keep(at(2, 20), "t9", length=50)
    keep(at(1, 20), "t9", length=50)
    keep(at(12, 20), "gone-before-v2", length=25)
    today_beans([(200, "t2", {}), (130, "t3", {}), (60, "t3", {})])


def build_back():
    for back in range(41, 23, -1):
        plain_day(back, [4, 5, 4, 6, 5, 4, 5][back % 7])
    today_beans([(60, "t2", {})])


{"day5": build_day5, "week3": build_week3, "back": build_back}[who]()

current = None
if bell:
    start = now - 26 * MIN
    current = {"phase": "focus", "id": f"r{start}", "tz": ZONE, "typeId": "t1", "len": 25,
               "startedAt": start, "endAt": now - 1 * MIN, "notes": [], "pings": [""],
               "flowed": False, "flowMin": 0, "done": False, "draft": ""}

settings = {
    "types": [{"id": i, "name": n, "len": length, "color": c} for i, n, length, c in TYPES],
    "typeId": "t1", "restMode": "auto", "sound": False, "demo": False, "tilt": False,
    "restShort": "auto", "restLongEvery": 4, "restLongMinutes": 15, "shield": False,
    "ambience": "off", "ambienceVolume": "mid", "autoNext": False,
    "removedTypes": [dict(REMOVED, removedAt=at(1, 22))] if who == "week3" else [],
}
state = {"v": 2, "settings": settings, "current": current, "days": days, "lastLine": 0}
(out / "douzhang.v1.json").write_text(json.dumps(state, ensure_ascii=False), encoding="utf-8")


# ---- 標準答案：照 .analytics/05-指標字典.md 與 07 的字串表，用這裡自己的寫法再算一次 ----

def date_of(key):
    return datetime.date.fromisoformat(key)


def duration(minutes):
    whole = int(math.floor(minutes + 0.5))
    if whole < 60:
        return f"{whole} 分"
    return f"{whole // 60} 小時" + (f" {whole % 60} 分" if whole % 60 else "")


def listed(parts):
    return "、".join(f"{name} {count}" for name, count in parts if count > 0)


today_key = day_key(now)
today = date_of(today_key)
used = sorted(key for key, record in days.items() if record["beans"] or record["voids"])


def usual():
    counts = sorted(
        len(days[key]["beans"]) for key in used if 1 <= (today - date_of(key)).days <= 21
    )
    if len(counts) < 10:
        return None

    def quantile(share):
        spot = share * (len(counts) - 1)
        index = int(spot)
        upper = counts[min(index + 1, len(counts) - 1)]
        return int(math.floor(counts[index] + (upper - counts[index]) * (spot - index) + 0.5))

    low, high = quantile(0.25), max(quantile(0.25), quantile(0.75))
    return f"你平常 {low} 顆" if low == high else f"你平常 {low} 到 {high} 顆"


def came_back():
    before = [date_of(key) for key in used if key < today_key]
    if not before or (today - before[0]).days < 14:
        return False
    gap = (today - before[-1]).days
    recent = [day for day in before if (before[-1] - day).days < 28]
    longest = max([(b - a).days for a, b in zip(recent, recent[1:])] or [1])
    return gap > longest * 2 and gap >= 4


def length_line(type_id):
    since = now - 28 * DAY
    on_bell = flowed = early = 0
    minutes = []
    for record in days.values():
        for bean in record["beans"]:
            same = bean["typeId"] == type_id and bean["len"] == LEN[type_id] and "tz" in bean
            if same and bean["start"] >= since:
                if bean["flow"] > 0:
                    flowed += 1
                elif bean.get("done"):
                    early += 1
                else:
                    on_bell += 1
        for entry in record["voids"]:
            if entry["typeId"] == type_id and entry["len"] == LEN[type_id] and entry["start"] >= since:
                minutes.append(entry["minute"])
    minutes.sort()
    total = on_bell + flowed + early + len(minutes)
    if total < 5:
        return f"這個長度再 {5 - total} 顆，這裡會列出它們怎麼結束的"
    head = f"{LEN[type_id]} 分鐘，最近 {total} 顆"
    if on_bell == total:
        return head + "都是響了就收"
    tail = ""
    if minutes and len(minutes) <= 3:
        tail = "。作廢的停在第 " + "、".join(str(m) for m in minutes) + " 分鐘"
    elif minutes:
        tail = f"。作廢的停在第 {minutes[0]} 到 {minutes[-1]} 分鐘"
    parts = [("響了就收", on_bell), ("延長", flowed), ("提早做完", early), ("作廢", len(minutes))]
    return head + "：" + listed(parts) + tail


def jot_lines():
    since = now - 14 * DAY
    notes = pings = unfilled = 0
    reasons = {}
    for record in days.values():
        for item in record["beans"] + record["voids"]:
            if item["start"] < since:
                continue
            notes += len(item["notes"])
            pings += len(item["pings"])
            if "minute" in item:
                reason = "有人找" if item["reason"] == "訊息" else item["reason"]
                if reason:
                    reasons[reason] = reasons.get(reason, 0) + 1
                else:
                    unfilled += 1
    lines = []
    jots, reasoned = notes + pings, sum(reasons.values())
    if jots:
        split = "：" + listed([("念頭", notes), ("有人找", pings)]) if jots >= 5 else ""
        lines.append(f"這兩週記了 {jots} 筆{split}。")
    if reasoned + unfilled:
        order = sorted(["念頭", "有人找", "卡住", "其他"], key=lambda name: -reasons.get(name, 0))
        parts = [(name, reasons.get(name, 0)) for name in order] + [("沒選", unfilled)]
        split = "：" + listed(parts) if reasoned >= 5 else ""
        lines.append(f"作廢 {reasoned + unfilled} 顆{split}。")
    return lines or ["這兩週沒有記一筆，也沒有作廢。"]


def week_rows():
    monday = today - datetime.timedelta(days=today.weekday())
    names = {type_id: name for type_id, name, _, _ in TYPES}
    names[REMOVED["id"]] = REMOVED["name"] + "（已刪除）"
    totals = {}
    for key, record in days.items():
        if 0 <= (date_of(key) - monday).days < 7:
            for bean in record["beans"]:
                name = names.get(bean["typeId"], "已刪除的標籤")
                minutes, count = totals.get(name, (0, 0))
                totals[name] = (minutes + bean["len"] + bean["flow"], count + 1)
    rows = sorted(totals.items(), key=lambda row: -row[1][0])
    all_minutes = sum(minutes for _, (minutes, _) in rows)
    all_beans = sum(count for _, (_, count) in rows)
    lines = [f"{name}　{duration(minutes)}・{count} 顆" for name, (minutes, count) in rows]
    fact = f"這週專注 {duration(all_minutes)}，收了 {all_beans} 顆" if rows else "這段時間還沒有番茄。"
    return lines + [fact]


kept_today = len(days.get(today_key, {"beans": []})["beans"])
back = came_back()
expected = {
    "誰": arg,
    "產生時刻": time.strftime("%Y-%m-%d %H:%M", local(now)),
    "今天已經收下": kept_today,
    "鈴響頁今天那列": f"{kept_today + 1} 顆小番茄（讀屏念「今天收了 {kept_today + 1} 顆」）" if bell else "（不是鈴響頁）",
    "鈴響頁第二行": "（不出現：斷了一陣子回來的第一天）" if back else (usual() or "（不出現：日子不夠）"),
    "斷了一陣子": back,
    "標籤編輯「專注」那一行": length_line("t1"),
    "分析第一張": week_rows(),
    "分析第二張": jot_lines(),
}
(out / "expected.json").write_text(json.dumps(expected, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps(expected, ensure_ascii=False, indent=2))
