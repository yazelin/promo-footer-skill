#!/usr/bin/env python3
"""套用 yz-promo-footer snippet 到目標 html。

用法: apply.py <html檔> <repo名(可空字串)> [--inject]
  --inject: 頁面沒有既有三件套 footer 時,自動注入右下角固定三連結小圓鈕。
冪等:檔內已有 yz-promo-footer 標記就跳過。
"""
import re
import sys
import pathlib

tpl = (pathlib.Path(__file__).parent / "snippet.template.html").read_text()
p = pathlib.Path(sys.argv[1])
repo = sys.argv[2]
inject = "--inject" in sys.argv
s = p.read_text()
if "yz-promo-footer" in s:
    print("skip(已存在):", p)
    sys.exit(0)
snip = tpl.replace("__REPO__", repo).replace("__INJECT__", "true" if inject else "false")
m = list(re.finditer(r"</body>", s, re.I))
if m:
    i = m[-1].start()
    s = s[:i] + snip + "\n" + s[i:]
else:
    s = s.rstrip("\n") + "\n" + snip
p.write_text(s)
print("ok:", p, "(inject)" if inject else "")
