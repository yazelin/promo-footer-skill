---
name: promo-footer
description: 公開專案的作者推廣三件套(GitHub/Facebook/BMC)標準與 BMC 注意力效果(不定時彈跳+可愛對話泡)。觸發時機:幫 yazelin 的公開網頁專案加推廣 footer、檢查三件套、幫 BMC 按鈕加吸睛效果;或要「改對話泡台詞/BMC 文案/footer 模板」並「更新所有站/全站升級/捲版到全部公開 repo」時——改模板後一律走 upgrade-all.sh+push-all.sh 捲版,不要只改單站。
---

# promo-footer:三件套(+部落格=四件套)+ BMC 注意力效果

任何**對外/公開**的網頁專案(遊戲、行銷頁、工具……)shipping 前,front-end 一定要有作者推廣三件套,這是固定 checklist 項,不是可選:

- GitHub:`https://github.com/yazelin/<repo>`(沒 repo 對應就用 `https://github.com/yazelin`)
- Facebook:`https://www.facebook.com/yaze.lin.gm`
- Buy Me a Coffee:`https://buymeacoffee.com/yazelin`

## 兩種放法

1. **頁面已有自己的 footer 風格**:照 roll-formosa `index.html` 的 `.title-footer`/`.footer-icons` 結構,inline SVG、`aria-label`/`title` 齊全、用該站的 CSS token。
2. **全螢幕 app / 不想動版面**:用本 skill 的 snippet 加 `--inject`,會在右下角注入固定三連結小圓鈕(半透明、不擋操作)。

## BMC 注意力效果(每個有三件套的站都要有)

`snippet.template.html` 是自包含 inline script,貼進 `</body>` 前即可:

- 找到頁上的 BMC 連結:**可見者優先、footer/nav 內優先**,否則取最後一個(避免抓到內文段落裡的贊助連結);React 等晚渲染會重試 30 秒。
- BMC icon **常駐原地輕跳**(2.6 秒一輪的小彈跳,一直跳);不定時(首次 18–30 秒,之後 90–180 秒)大跳一下並彈出可愛小對話泡(求抖內語句,4 秒後淡出)。
- 每次頁面載入最多出現 3 次就安靜,寧可少不可煩。
- 低調原則:泡泡 `pointer-events:none` 不擋點擊、分頁在背景或錨點不在可視範圍時不講話、`prefers-reduced-motion` 時整組停用。
- 文案規則:正體中文、全形標點、不用 emoji。
- **v2 自動補部落格連結**:頁上沒有連回 `https://yazelin.github.io/` 根站的連結時,會 clone BMC 按鈕補一顆「亞澤的部落格」(icon 站補 globe icon、文字站補「部落格」二字、注入版多第四顆圓鈕;只在 footer/nav 情境加,不會插進內文句子),把作品站流量導回主站訂閱漏斗;blog 本站用 `--no-blog` 關掉。

## 套用

```bash
python3 apply.py <path/to/index.html> <repo名> [--inject] [--no-blog]
```

冪等(同版重跑會 skip,偵測到舊版會就地升級)。套用後檢查:該站若是離線 PWA(有 sw.js 全量 precache),要一併 bump service worker 的 cache 版本,不然舊快取蓋住新 index.html。

## 全站捲版:一個指令

```bash
./release.sh --dry     # 先看要做什麼
./release.sh           # 真的跑
./release.sh --verify-only   # 只檢查線上有沒有跟上
```

改完 `snippet.template.html` 之後**要把 apply.py 的 VERSION 捲一號**,不捲的話 apply.py 會判定「已是同版」把全部站 skip。release.sh 會用 `.version-lock` 比對樣板雜湊,忘了捲就直接擋下來。

release.sh 一次做完:掃描(抓 `yz-promo-footer`,不要求後面有版號)→ 套用 → 離線 PWA 自動 bump service worker 快取版號 → 只 stage 動到的檔 → commit → push(main 有保護的自動走 branch + PR auto-merge)→ 逐 repo 驗有沒有推出去。

**沒有版號的變體會被列出來但不自動改**(有人手改過、拿掉版號,例如 ai-brain-site、glitch-music)。那些要人工同步文案,並記進 `skip.txt`。

舊的 `upgrade-all.sh` 只做「套用」那一段,留著給只想跑那一步的情況。

## 驗證

開頁面後在 console 跑 `window.__yzPromo()` 立刻觸發一次彈跳+對話泡,截圖確認位置與樣式。
