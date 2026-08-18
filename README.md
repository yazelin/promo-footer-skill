# promo-footer-skill

公開專案「作者推廣三件套」(GitHub / Facebook / Buy Me a Coffee)的標準做法,加上 BMC 按鈕的注意力效果:不定時原地彈跳 + 可愛小對話泡(求抖內),低調吸睛、不影響使用。

## 內容

| 檔案 | 用途 |
|---|---|
| `SKILL.md` | skill 本體:三件套規則 + 效果標準 + 套用/驗證流程 |
| `snippet.template.html` | 自包含 inline snippet(效果 + 可選右下角三連結注入) |
| `apply.py` | 冪等套用腳本:`python3 apply.py <html> <repo> [--inject]` |
| `upgrade-all.sh` | 模板改版後的全站升級:掃描所有 repo 的 snippet 標記、照各檔既有參數重套(清單不靠人列) |
| `push-all.sh` | 升級後的 commit+push:只 stage 相關檔;protected branch 自動開 PR(auto-merge)、archived 自動解封存→推→封回(agent 跑會被權限層擋,人跑全自動) |

## 安裝(換機兩行)

```bash
git clone https://github.com/yazelin/promo-footer-skill ~/promo-footer-skill
ln -s ~/promo-footer-skill ~/.claude/skills/promo-footer
```

其他 agent(Codex/Gemini)直接讀 `SKILL.md` 照用法執行即可,不綁 Claude。

## License

MIT © 林亞澤

---

作者:[GitHub](https://github.com/yazelin)|[Facebook](https://www.facebook.com/yaze.lin.gm)|[Buy Me a Coffee](https://buymeacoffee.com/yazelin)

## 全站捲版

```bash
./release.sh --dry           # 先看要做什麼
./release.sh                 # 真的跑
./release.sh --verify-only   # 只檢查有沒有推出去
```

改完 `snippet.template.html` 要捲 `apply.py` 的 `VERSION`。忘了捲的話 apply.py 會判定「已是同版」，全部站被 skip、跑了等於沒跑——release.sh 用 `.version-lock` 比對樣板雜湊，忘了捲直接擋下來。

一個指令做完：掃描 → 套用 → 離線 PWA 自動 bump service worker 快取版號 → 只 stage 動到的檔 → commit → push（main 有保護的走 branch + PR auto-merge）→ 驗每個 repo 都推出去了。

### 這五個坑寫進工具了

2026-08-18 手動跑一次 96 檔、52 repo 的 sweep，踩到：

1. 改了樣板忘了捲 VERSION，全部被 skip
2. `ai-brain-site`、`glitch-music` 的標記被手改成沒有版號，掃描的 `grep "yz-promo-footer v"` 永遠看不到它們
3. 7 個離線 PWA 的 service worker 快取沒 bump，舊快取蓋住新頁面
4. 兩個 main 有保護的 repo 要走 branch + PR
5. 用 `grep ahead` 驗同步，這台機器 git 講中文「領先 1」，永遠比對不到，回報了假的全綠
6. 開 PR 的分支從**本地** main 起頭，但本地落後遠端一個 commit，PR 直接變 `DIRTY`、auto-merge 不會動，要人工 rebase 才發現。現在改成先 fetch、從 `origin/<base>` 開分支

自包含（每個站各自完整、零外部相依、離線能用）是這個設計真正的優點，不該為了省事丟掉。該修的是工具太陽春。
