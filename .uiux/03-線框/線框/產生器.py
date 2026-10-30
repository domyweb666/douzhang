# 豆帳線框產生器：灰階、真實尺寸（pt=px）、真實文字、虛線＝點擊範圍
import sys, pathlib, random

OUT = pathlib.Path(sys.argv[1])
OUT.mkdir(parents=True, exist_ok=True)

SENT = "打開讀書筆記，把三個重點各寫一句"
SENT_LONG = ("先把《原子習慣》第三章的筆記打開，找出昨天標了星號的三段，各寫一句話說明它跟我自己的早晨流程有什麼關係，"
             "寫完貼到課程大綱第二節的開頭，再順手把第二節的標題改成問句，最後檢查字數有沒有超過一百二十個字")
TYPE = "一般・25 分"
TYPE_LONG = "整理線上課程銷售頁文案・50 分"
NOTES = [("念頭", "回信給出版社問書的交期"), ("有人找", "阿偉問下午會議改幾點")]
NOTES_MANY = [("念頭", "回信給出版社問書的交期"), ("念頭", "第二節的例子換成咖啡店那個"), ("念頭", "查一下 Zeigarnik 那篇統合分析的年份"),
              ("念頭", "明天錄影前先充麥克風"), ("念頭", "把這段寫成 Threads"), ("有人找", "阿偉問下午會議改幾點"),
              ("有人找", "媽媽打來，沒接"), ("有人找", "快遞說五點前到")]

CSS = """
*{box-sizing:border-box;margin:0;padding:0}
html,body{background:#ddd;font-family:-apple-system,"PingFang TC","Noto Sans TC",sans-serif;-webkit-text-size-adjust:100%}
body{scroll-snap-type:y mandatory;overflow-y:scroll;height:100dvh}
.screen{position:relative;width:100vw;height:100dvh;max-width:440px;margin:0 auto;background:#fff;overflow:hidden;
  scroll-snap-align:start;font-size:17px;color:#111;border-bottom:4px solid #999}
.ax{font-size:34px}
@media print{body{height:auto;scroll-snap-type:none}.screen{width:440px;height:956px;page-break-after:always;border:1px solid #000}}
.abs{position:absolute}
.status{left:0;right:0;top:0;height:54px;background:repeating-linear-gradient(45deg,#f3f3f3 0 6px,#e9e9e9 6px 12px);
  font-size:10px;color:#777;padding:4px 8px;line-height:1.2}
.island{left:50%;top:11px;width:125px;height:37px;margin-left:-62px;background:#222;border-radius:20px}
.home{left:0;right:0;bottom:0;height:34px;background:repeating-linear-gradient(45deg,#f3f3f3 0 6px,#e9e9e9 6px 12px);
  font-size:10px;color:#777;text-align:center;line-height:34px}
.tag{left:50%;transform:translateX(-50%);top:70px;font-size:10px;color:#444;background:#eee;padding:2px 6px;border-radius:4px;z-index:5;white-space:nowrap}
.cal{width:44px;height:44px;border:1px solid #000;font-size:8px;line-height:1.1;padding:2px;color:#000;background:#fff;z-index:5}
.tap{outline:1.5px dashed #444;outline-offset:0}
.nav{top:62px;height:44px;min-width:60px;padding:0 10px;line-height:44px;font-size:1em;color:#333;text-align:center}
.lbl{font-size:.76em;color:#777;letter-spacing:.02em}
.sent{font-size:1.53em;font-weight:700;line-height:1.3;color:#111}
.card{background:#f4f4f4;border-radius:16px;padding:16px}
.chip{height:44px;line-height:44px;padding:0 16px;border-radius:22px;background:#e6e6e6;font-size:.94em;color:#222;text-align:center;white-space:nowrap}
.time{font-weight:800;letter-spacing:-.02em;text-align:center;color:#111}
.btn{height:60px;line-height:60px;border-radius:14px;background:#333;color:#fff;text-align:center;font-size:1.06em;font-weight:700}
.txtbtn{height:44px;line-height:44px;color:#888;font-size:.94em;padding:0 8px}
.jar{border:1px dashed #aaa;border-radius:12px;background:#fafafa}
.jar .lbl{position:absolute;left:10px;top:6px}
.pea{position:absolute;width:30px;height:30px;border-radius:50%;background:#bbb}
.pea.x2{width:62px;border-radius:15px}
.input{background:#f4f4f4;border-radius:14px;padding:14px;font-size:1.12em;line-height:1.4;color:#111;border:1px solid #ccc}
.input .ph{color:#999}
.kbd{left:0;right:0;bottom:0;height:336px;background:#cfcfcf;border-top:1px solid #999;font-size:12px;color:#444;text-align:center;padding-top:10px}
.kbd .ret{position:absolute;right:6px;bottom:52px;width:90px;height:42px;line-height:42px;background:#888;color:#fff;border-radius:6px;font-size:14px}
.list{font-size:.94em;color:#333;line-height:1.5}
.list div{padding:5px 0;border-bottom:1px solid #eee}
.list b{color:#888;font-weight:500;margin-right:8px}
.hint{font-size:.76em;color:#888}
.circle{border-radius:50%;background:#e9e9e9;text-align:center;display:flex;flex-direction:column;justify-content:center;align-items:center}
.note{left:8px;bottom:40px;font-size:9px;color:#555;background:#fff8;padding:2px 4px;max-width:200px;line-height:1.2}
"""

def pos(top=None, left=None, right=None, bottom=None, w=None, h=None, extra=""):
    s = []
    for k, v in (("top", top), ("left", left), ("right", right), ("bottom", bottom), ("width", w), ("height", h)):
        if v is not None:
            s.append(f"{k}:{v}px")
    return ";".join(s) + (";" + extra if extra else "")

def el(cls, style, inner=""):
    return f'<div class="abs {cls}" style="{style}">{inner}</div>'

def chrome(label, note=""):
    h = el("status", "", "狀態列／動態島：底下不放可按的東西") + el("island", "")
    h += el("tag", "", label)
    h += el("cal", pos(right=8, top=110), "44pt<br>≈6.5mm")
    h += el("home", "", "系統手勢區（上滑回主畫面）")
    if note:
        h += el("note", "", note)
    return h

def nav():
    return el("nav tap", pos(left=8), "豆棚") + el("nav tap", pos(right=8), "設定")

def peas(top, bottom, n, two_every=4, seed=1):
    rnd = random.Random(seed)
    h = ""
    H = 956 - bottom - top
    for i in range(n):
        two = (i % two_every == 3)
        w = 62 if two else 30
        x = rnd.randint(8, 440 - 16 - w - 8)
        y = rnd.randint(max(8, H - 120), H - 38)
        h += f'<div class="pea{" x2" if two else ""}" style="left:{x}px;top:{y}px"></div>'
    return h

def jar(top, bottom, n=5, label="今天的豆子（傾斜手機會滾，點一下會彈）"):
    return el("jar tap", pos(top=top, left=16, right=16, bottom=bottom), f'<span class="lbl">{label}</span>' + peas(top, bottom, n))

def keyboard():
    return el("kbd", "", "鍵盤（高度約 336pt，待真機）<div class='ret'>完成</div>")

def notes_list(top, items, bottom=None):
    inner = "".join(f"<div><b>{k}</b>{v}</div>" for k, v in items)
    return el("list", pos(top=top, left=20, right=20, bottom=bottom), inner)

def screen(label, body, ax=False, note=""):
    return f'<section class="screen{" ax" if ax else ""}">{chrome(label, note)}{body}</section>'

# ---------- 方向 A：卡片＋滿版按鈕 ----------
def A_idle(sent=SENT, typ=TYPE, n=5, first=False, kbd=False, label="主畫面・待機｜A"):
    h = nav()
    if first:
        h += el("card", pos(top=150, left=20, right=20, h=190),
                f'<div class="lbl">寫下接下來要做的第一件事，寫到具體的動作</div>'
                f'<div class="input tap" style="margin-top:10px;min-height:110px"><span class="ph">例：打開讀書筆記，把三個重點各寫一句</span></div>')
    else:
        h += el("card", pos(top=150, left=20, right=20, h=190),
                f'<div class="lbl">昨天的你留了一句</div><div class="sent" style="margin-top:8px">{sent}</div>')
    h += el("chip tap", pos(top=360, left=0, right=0, extra="width:max-content;margin:0 auto"), typ + " ›")
    h += el("time", pos(top=420, left=0, right=0, extra="font-size:2.35em"), typ.split("・")[1].replace(" 分", "") + ":00")
    if not kbd:
        h += jar(500, 130, n)
        h += el("btn tap", pos(bottom=50, left=20, right=20), "開始")
    else:
        h += keyboard()
        h += el("btn tap", pos(bottom=336, left=20, right=20), "記下來")
    return screen(label, h)

def A_focus():
    h = nav()
    h += el("time", pos(top=170, left=0, right=0, extra="font-size:4.5em"), "18:42")
    h += el("", pos(top=300, left=20, right=20), f'<div class="lbl">正在做</div><div style="font-size:1.06em;margin-top:4px">{SENT}</div>')
    h += el("chip tap", pos(top=420, left=20, w=190), "冒出念頭")
    h += el("chip tap", pos(top=420, right=20, w=190), "有人找")
    h += jar(500, 130, 3)
    h += el("txtbtn tap", pos(bottom=50, left=0, right=0, extra="width:120px;margin:0 auto;text-align:center"), "結束")
    return screen("主畫面・計時中｜A", h, note="「結束」只開半頁（提早做完／作廢），不直接作廢")

def A_rest():
    h = nav()
    h += el("time", pos(top=170, left=0, right=0, extra="font-size:4.5em"), "4:10")
    h += el("", pos(top=300, left=20, right=20), '<div class="lbl">休息</div><div style="font-size:1.06em;margin-top:4px">離開螢幕。喝水、看遠處、伸展、閉眼都好。</div>')
    h += jar(500, 130, 4, label="今天的豆子（剛掉進來一顆）")
    h += el("btn tap", pos(bottom=50, left=20, right=20), "回來了，開始下一顆")
    return screen("主畫面・休息｜A", h)

def A_bell(draft=True, kbd=False, worst=False, label="鈴響・寫一句｜A"):
    text = (SENT_LONG if worst else SENT) if draft else '<span class="ph">寫一行給下一顆的自己</span>'
    h = el("txtbtn tap", pos(top=62, right=8), "再做 15 分・30 分")
    h += el("", pos(top=130, left=20, right=20), '<div style="font-size:1.9em;font-weight:800">響了。</div><div class="lbl" style="margin-top:6px">寫一行給下一顆的自己。</div>')
    h += el("input tap", pos(top=240, left=20, right=20, extra="min-height:110px"), text)
    if not draft:
        h += el("txtbtn tap", pos(top=360, left=12), "這顆不留話")
    h += notes_list(430 if not worst else 470, NOTES_MANY if worst else NOTES, bottom=130)
    if kbd:
        h += keyboard()
        h += el("btn tap", pos(bottom=336, left=20, right=20), "收下這顆")
    else:
        h += el("btn tap", pos(bottom=50, left=20, right=20), "收下這顆")
    return screen(label, h, note="「這顆不留話」只在輸入框空白時出現" if not draft else "")

# ---------- 方向 B：那句就是按鈕 ----------
def B_card(inner, tap=True, hint=""):
    return el("card" + (" tap" if tap else ""), pos(top=343, left=20, right=20, h=270, extra="display:flex;flex-direction:column"),
              inner + (f'<div class="hint" style="margin-top:auto;text-align:right">{hint}</div>' if hint else ""))

def B_idle(sent=SENT, typ=TYPE, n=5, first=False, kbd=False, label="主畫面・待機｜B"):
    h = nav()
    h += el("chip tap", pos(top=122, left=0, right=0, extra="width:max-content;margin:0 auto"), typ + " ›")
    if first:
        h += el("card", pos(top=343, left=20, right=20, h=270),
                '<div class="lbl">寫下接下來要做的第一件事，寫到具體的動作</div>'
                '<div class="input tap" style="margin-top:10px;min-height:130px"><span class="ph">例：打開讀書筆記，把三個重點各寫一句</span></div>')
        if kbd:
            h += keyboard()
            h += el("btn tap", pos(bottom=336, left=20, right=20), "記下來")
        else:
            h += el("btn tap", pos(top=630, left=20, right=20), "記下來")
    else:
        h += B_card(f'<div class="lbl">昨天的你留了一句</div><div class="sent" style="margin-top:8px">{sent}</div>',
                    hint="點一下開始・" + typ.split("・")[1])
        h += jar(640, 50, n)
    return screen(label, h)

def B_focus():
    h = nav()
    h += el("chip", pos(top=122, left=0, right=0, extra="width:max-content;margin:0 auto;background:#f4f4f4;color:#999"), TYPE)
    h += B_card('<div class="time" style="font-size:3.2em;text-align:left">18:42</div>'
                f'<div class="lbl" style="margin-top:10px">正在做</div><div style="font-size:1.06em">{SENT}</div>', hint="點一下：結束這顆（開半頁）")
    h += el("chip tap", pos(top=629, left=20, w=190), "冒出念頭")
    h += el("chip tap", pos(top=629, right=20, w=190), "有人找")
    h += jar(690, 50, 3)
    return screen("主畫面・計時中｜B", h)

def B_rest():
    h = nav()
    h += B_card('<div class="time" style="font-size:3.2em;text-align:left">4:10</div>'
                '<div class="lbl" style="margin-top:10px">休息</div><div style="font-size:1.06em">離開螢幕。喝水、看遠處、伸展、閉眼都好。</div>',
                hint="點一下開始下一顆")
    h += jar(640, 50, 4, label="今天的豆子（剛掉進來一顆）")
    return screen("主畫面・休息｜B", h)

def B_bell(draft=True, kbd=False, worst=False, label="鈴響・寫一句｜B"):
    text = (SENT_LONG if worst else SENT) if draft else '<span class="ph">寫一行給下一顆的自己</span>'
    h = el("txtbtn tap", pos(top=62, right=8), "再做 15 分・30 分")
    h += el("", pos(top=130, left=20, right=20), '<div style="font-size:1.9em;font-weight:800">響了。</div><div class="lbl" style="margin-top:6px">寫一行給下一顆的自己。</div>')
    h += el("input tap", pos(top=300, left=20, right=20, extra="min-height:110px"), text)
    h += el("btn tap", pos(top=426, left=20, right=20), "收下這顆")
    if not draft:
        h += el("txtbtn tap", pos(top=250, left=12), "這顆不留話")
    h += notes_list(520 if not worst else 560, NOTES_MANY if worst else NOTES, bottom=50)
    if kbd:
        h += keyboard()
    return screen(label, h, note="按鈕跟著輸入框，鍵盤升起時兩者一起被推到可見區（SwiftUI 鍵盤避讓，待真機）" if kbd else "")

# ---------- 方向 C：時間圓鈕 ----------
def C_title(sent, label_text="昨天的你留了一句"):
    return el("", pos(top=130, left=20, right=20, h=180), f'<div class="lbl">{label_text}</div><div class="sent" style="margin-top:8px">{sent}</div>')

def C_circle(top, d, lines, tap=True):
    return el("circle" + (" tap" if tap else ""), pos(top=top, left=0, right=0, w=d, h=d, extra="margin:0 auto"), lines)

def C_idle(sent=SENT, typ=TYPE, n=5, first=False, kbd=False, label="主畫面・待機｜C"):
    h = nav()
    if first:
        h += el("", pos(top=130, left=20, right=20), '<div class="lbl">寫下接下來要做的第一件事，寫到具體的動作</div>'
                '<div class="input tap" style="margin-top:10px;min-height:110px"><span class="ph">例：打開讀書筆記，把三個重點各寫一句</span></div>')
        if kbd:
            h += keyboard()
            h += el("btn tap", pos(bottom=336, left=20, right=20), "記下來")
        else:
            h += C_circle(400, 220, '<div class="time" style="font-size:2.1em">記下來</div>')
    else:
        h += C_title(sent)
        h += el("chip tap", pos(top=330, left=0, right=0, extra="width:max-content;margin:0 auto"), typ + " ›")
        h += C_circle(400, 220, f'<div class="time" style="font-size:2.35em">{typ.split("・")[1].replace(" 分","")}:00</div><div style="font-size:1em;font-weight:700;margin-top:4px">開始</div>')
        h += jar(650, 50, n)
    return screen(label, h)

def C_focus():
    h = nav()
    h += C_title(SENT, "正在做")
    h += C_circle(400, 220, '<div class="time" style="font-size:2.9em">18:42</div><div class="hint" style="margin-top:4px">點一下：結束這顆</div>')
    h += el("chip tap", pos(top=650, left=20, w=190), "冒出念頭")
    h += el("chip tap", pos(top=650, right=20, w=190), "有人找")
    h += jar(710, 50, 3)
    return screen("主畫面・計時中｜C", h, note="點圓開「結束」半頁，不直接作廢")

def C_rest():
    h = nav()
    h += el("", pos(top=130, left=20, right=20), '<div class="lbl">休息</div><div class="sent" style="margin-top:8px">離開螢幕。喝水、看遠處、伸展、閉眼都好。</div>')
    h += C_circle(400, 220, '<div class="time" style="font-size:2.9em">4:10</div><div style="font-size:.94em;font-weight:700;margin-top:4px">回來了，開始下一顆</div>')
    h += jar(650, 50, 4, label="今天的豆子（剛掉進來一顆）")
    return screen("主畫面・休息｜C", h)

def C_bell(draft=True, kbd=False, worst=False, label="鈴響・寫一句｜C"):
    text = (SENT_LONG if worst else SENT) if draft else '<span class="ph">寫一行給下一顆的自己</span>'
    h = el("txtbtn tap", pos(top=62, right=8), "再做 15 分・30 分")
    h += el("", pos(top=120, left=20, right=20), '<div style="font-size:1.9em;font-weight:800">響了。</div><div class="lbl" style="margin-top:6px">寫一行給下一顆的自己。</div>')
    h += el("input tap", pos(top=230, left=20, right=20, extra="min-height:110px"), text)
    h += C_circle(360, 120, '<div style="font-size:1em;font-weight:700">收下<br>這顆</div>')
    if not draft:
        h += el("txtbtn tap", pos(top=496, left=0, right=0, extra="text-align:center"), "這顆不留話")
    h += notes_list(550 if not worst else 590, NOTES_MANY if worst else NOTES, bottom=50)
    if kbd:
        h += keyboard()
    return screen(label, h, note="鍵盤的「完成」鍵也送出" if kbd else "")

def page(title, screens):
    return f'<!doctype html><html lang="zh-Hant"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"><title>{title}</title><style>{CSS}</style></head><body>{"".join(screens)}</body></html>'

files = {
    "主畫面-A.html": ("豆帳線框 方向 A", [
        A_idle(), A_idle(first=True, kbd=True, label="主畫面・待機・第一次＋鍵盤｜A"),
        A_idle(sent=SENT_LONG, typ=TYPE_LONG, n=40, label="主畫面・待機・最壞內容｜A"),
        A_focus(), A_rest(),
        A_bell(draft=False), A_bell(kbd=True, label="鈴響＋鍵盤｜A"), A_bell(worst=True, label="鈴響・最壞內容｜A")]),
    "主畫面-B.html": ("豆帳線框 方向 B", [
        B_idle(), B_idle(first=True, kbd=True, label="主畫面・待機・第一次＋鍵盤｜B"),
        B_idle(sent=SENT_LONG, typ=TYPE_LONG, n=40, label="主畫面・待機・最壞內容｜B"),
        B_focus(), B_rest(),
        B_bell(draft=False), B_bell(kbd=True, label="鈴響＋鍵盤｜B"), B_bell(worst=True, label="鈴響・最壞內容｜B")]),
    "主畫面-C.html": ("豆帳線框 方向 C", [
        C_idle(), C_idle(first=True, kbd=True, label="主畫面・待機・第一次＋鍵盤｜C"),
        C_idle(sent=SENT_LONG, typ=TYPE_LONG, n=40, label="主畫面・待機・最壞內容｜C"),
        C_focus(), C_rest(),
        C_bell(draft=False), C_bell(kbd=True, label="鈴響＋鍵盤｜C"), C_bell(worst=True, label="鈴響・最壞內容｜C")]),
    "最大字級預警.html": ("豆帳線框 最大字級 ×2 預警", [
        screen("待機・字級×2｜A", A_idle().split('">', 1)[1].rsplit("</section>", 1)[0], ax=True),
        screen("待機・字級×2｜B", B_idle().split('">', 1)[1].rsplit("</section>", 1)[0], ax=True),
        screen("待機・字級×2｜C", C_idle().split('">', 1)[1].rsplit("</section>", 1)[0], ax=True),
        screen("鈴響・字級×2｜A", A_bell(draft=False).split('">', 1)[1].rsplit("</section>", 1)[0], ax=True),
    ]),
}
for name, (title, scr) in files.items():
    (OUT / name).write_text(page(title, scr), encoding="utf-8")

index = "".join(f'<li><a href="{n}">{n}</a></li>' for n in files)
(OUT / "index.html").write_text(
    '<!doctype html><html lang="zh-Hant"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
    '<title>豆帳線框</title><style>body{font-family:-apple-system,"PingFang TC",sans-serif;padding:24px;font-size:17px;line-height:1.6}li{margin:8px 0}</style></head>'
    '<body><h2>豆帳線框（灰階・真實尺寸）</h2><p>用手機 Safari 打開，往上滑換畫面。每張右上有 44pt 校正方塊，量起來約 6.5 公釐。虛線框＝實際點擊範圍。</p>'
    f'<ul>{index}</ul><p style="color:#777;font-size:14px">不要在電腦上看：距離和大小會失真。</p></body></html>', encoding="utf-8")
print("ok", [f.name for f in OUT.iterdir()])
