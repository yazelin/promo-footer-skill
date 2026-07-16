---
name: promo-footer
description: 公開專案的作者推廣三件套(GitHub/Facebook/BMC)標準與 BMC 注意力效果(不定時彈跳+可愛對話泡)。當要幫 yazelin 的公開網頁專案加推廣 footer、檢查三件套、或幫 BMC 按鈕加吸睛效果時使用。
---

# promo-footer:三件套 + BMC 注意力效果

任何**對外/公開**的網頁專案(遊戲、行銷頁、工具……)shipping 前,front-end 一定要有作者推廣三件套,這是固定 checklist 項,不是可選:

- GitHub:`https://github.com/yazelin/<repo>`(沒 repo 對應就用 `https://github.com/yazelin`)
- Facebook:`https://www.facebook.com/yaze.lin.gm`
- Buy Me a Coffee:`https://buymeacoffee.com/yazelin`

## 兩種放法

1. **頁面已有自己的 footer 風格**:照 roll-formosa `index.html` 的 `.title-footer`/`.footer-icons` 結構,inline SVG、`aria-label`/`title` 齊全、用該站的 CSS token。
2. **全螢幕 app / 不想動版面**:用本 skill 的 snippet 加 `--inject`,會在右下角注入固定三連結小圓鈕(半透明、不擋操作)。

## BMC 注意力效果(每個有三件套的站都要有)

`snippet.template.html` 是自包含 inline script,貼進 `</body>` 前即可:

- 找到頁上的 `a[href*="buymeacoffee.com/yazelin"]`(React 等晚渲染會重試 30 秒)。
- 不定時(首次 12–25 秒,之後 45–90 秒)讓 BMC icon 原地彈跳一下,同時彈出可愛小對話泡(求抖內語句,4 秒後淡出)。
- 低調原則:泡泡 `pointer-events:none` 不擋點擊、分頁在背景時不動、`prefers-reduced-motion` 時整組停用。
- 文案規則:正體中文、全形標點、不用 emoji。

## 套用

```bash
python3 apply.py <path/to/index.html> <repo名> [--inject]
```

冪等(重跑會 skip)。套用後檢查:該站若是離線 PWA(有 sw.js 全量 precache),要一併 bump service worker 的 cache 版本,不然舊快取蓋住新 index.html。

## 驗證

開頁面後在 console 跑 `window.__yzPromo()` 立刻觸發一次彈跳+對話泡,截圖確認位置與樣式。
