#!/usr/bin/env python3
"""套用/升級 yz-promo-footer snippet 到目標 html。

用法: apply.py <html檔> <repo名(可空字串)> [--inject] [--no-blog]
  --inject : 頁面沒有既有三件套 footer 時,注入右下角固定三連結小圓鈕。
  --no-blog: 不自動補「部落格」連結(blog 本站用)。
冪等:已是同版就 skip;偵測到舊版會就地換成新版。
"""
import re
import sys
import pathlib

VERSION = 10

# per-site 對話泡加碼句(重套不會丟;句子跟站的功能綁定,別放通用句)
EXTRA_LINES = {
    "line-chat-maker": ["免費 AI 是真的在刷亞澤的信用卡，喝杯咖啡幫他回血"],
}

tpl = (pathlib.Path(__file__).parent / "snippet.template.html").read_text().rstrip("\n")
p = pathlib.Path(sys.argv[1])
repo = sys.argv[2]
inject = "--inject" in sys.argv
addblog = "--no-blog" not in sys.argv
s = p.read_text()
snip = (tpl.replace("__REPO__", repo)
           .replace("__INJECT__", "true" if inject else "false")
           .replace("__ADDBLOG__", "true" if addblog else "false")
           .replace("__EXTRALINES__", "".join(',"%s"' % l for l in EXTRA_LINES.get(repo, [])))
           # 版號只有 VERSION 一個來源。以前模板的註解要人工同步,漏改過一次:
           # apply.py 說 v10、寫進檔案的註解還是 v9,於是每次捲版都重寫全部檔案卻永遠升不上去。
           .replace("__VERSION__", str(VERSION)))

m = re.search(r"[ \t]*<!-- yz-promo-footer v(\d+).*?</script>\n?", s, re.S)
if m:
    if int(m.group(1)) >= VERSION:
        print("skip(已是 v%d+): %s" % (VERSION, p))
        sys.exit(0)
    s = s.replace(m.group(0), snip + "\n")
    p.write_text(s)
    print("upgraded v%s→v%d: %s" % (m.group(1), VERSION, p))
    sys.exit(0)

mm = list(re.finditer(r"</body>", s, re.I))
if mm:
    i = mm[-1].start()
    s = s[:i] + snip + "\n" + s[i:]
else:
    s = s.rstrip("\n") + "\n" + snip
p.write_text(s)
print("ok:", p, "(inject)" if inject else "")
