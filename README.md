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
