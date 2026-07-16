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

VERSION = 4
tpl = (pathlib.Path(__file__).parent / "snippet.template.html").read_text()
p = pathlib.Path(sys.argv[1])
repo = sys.argv[2]
inject = "--inject" in sys.argv
addblog = "--no-blog" not in sys.argv
s = p.read_text()
snip = (tpl.replace("__REPO__", repo)
           .replace("__INJECT__", "true" if inject else "false")
           .replace("__ADDBLOG__", "true" if addblog else "false"))

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
