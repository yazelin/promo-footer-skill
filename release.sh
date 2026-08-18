#!/bin/bash
# release.sh — 捲一版 promo-footer 並鋪到所有站。一個指令做完 sweep 的全部工作。
#
# 用法:
#   ./release.sh --dry          只印要做什麼,不動任何檔案
#   ./release.sh                真的跑:套用 → bump SW → commit → push/PR → 驗同步
#   ./release.sh --verify-only  只檢查線上有沒有跟上(不改東西)
#
# 為什麼有這支:2026-08-18 手動跑一次 sweep,踩了五個坑——
#   1. 改了樣板卻忘了捲 VERSION,96 個站全部被 skip,跑了等於沒跑
#   2. ai-brain-site 的標記被手改成沒有版號,掃描的 grep "yz-promo-footer v" 永遠看不到它
#   3. 7 個離線 PWA 的 service worker 快取沒 bump,舊快取會蓋住新頁面
#   4. 兩個 main 有保護的 repo 要走 branch + PR
#   5. 用 grep ahead 驗同步,這台機器 git 講中文「領先 1」,永遠比對不到 → 假的全綠
# 每一條都寫進這支了。工具太陽春才是真正該修的東西。
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
APPLY="$HERE/apply.py"; SKIP="$HERE/skip.txt"; LOCK="$HERE/.version-lock"
ROOT="${ROOT:-$HOME}"
DRY=0; VERIFY_ONLY=0
for a in "$@"; do
  case "$a" in
    --dry) DRY=1 ;;
    --verify-only) VERIFY_ONLY=1 ;;
    *) ROOT="$a" ;;
  esac
done
say() { printf '%s\n' "$*"; }
VERSION=$(grep -oE '^VERSION = [0-9]+' "$APPLY" | grep -oE '[0-9]+')

# ── 0. 版號鎖:樣板改了卻沒捲版號,直接擋下來(坑 1) ──
tplhash=$(sha256sum "$HERE/snippet.template.html" | cut -c1-16)
if [ -f "$LOCK" ]; then
  read -r lv lh < "$LOCK"
  if [ "$lv" = "$VERSION" ] && [ "$lh" != "$tplhash" ]; then
    say "樣板改過了，但 apply.py 的 VERSION 還停在 $VERSION。"
    say "捲版號才會生效——不捲的話 apply.py 會判定「已是同版」，全部站被 skip。"
    say "  改 $APPLY 的 VERSION = $((VERSION + 1))，然後重跑。"
    exit 1
  fi
fi

# ── 1. 掃描:抓 yz-promo-footer,不要求後面有版號(坑 2) ──
mapfile -t all < <(grep -rl --include='*.html' "yz-promo-footer" "$ROOT" \
  --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist --exclude-dir=build 2>/dev/null \
  | grep -v "/promo-footer-skill/" | sort)
targets=(); variants=(); skipped=()
for f in "${all[@]}"; do
  why=$(awk -F'\t' -v p="$f" '!/^#/ && NF>=2 && index(p,$1){print $2; exit}' "$SKIP" 2>/dev/null)
  if [ -n "$why" ]; then skipped+=("$f	$why"); continue; fi
  if grep -q "yz-promo-footer v[0-9]" "$f"; then targets+=("$f"); else variants+=("$f"); fi
done
say "掃到 ${#all[@]} 個檔案：可自動升級 ${#targets[@]}、跳過清單 ${#skipped[@]}、沒有版號的變體 ${#variants[@]}"
for v in "${variants[@]}"; do say "  變體（掃描抓不到版號，要人工同步）: $v"; done

# 驗收要分三層:推出去了 ≠ 合進 main ≠ 本地跟上。
# 2026-08-18 踩到:mori-meeting-recorder 的 PR 早就合了,但本地 main 沒拉,
# 而且本地還卡著一個推不上去的舊 commit(遠端已有 squash 版),git pull 會直接失敗。
# 只驗「有沒有推出去」的話,這三種都看不出來。
verify() {
  local bad=0 seen=""
  for f in "${targets[@]}"; do
    local r; r=$(git -C "$(dirname "$f")" rev-parse --show-toplevel 2>/dev/null) || continue
    case " $seen " in *" $r "*) continue ;; esac
    seen="$seen $r"
    local name; name=$(basename "$r")
    git -C "$r" fetch -q origin 2>/dev/null
    local ahead behind
    ahead=$(git -C "$r" rev-list '@{u}..HEAD' --count 2>/dev/null || echo 0)   # 用數字,不看語系(坑 5)
    behind=$(git -C "$r" rev-list 'HEAD..@{u}' --count 2>/dev/null || echo 0)
    local ver; ver=$(grep -o 'yz-promo-footer v[0-9]*' "$f" | head -1 | grep -oE '[0-9]+')
    local msg=""
    # 只管「捲版相關」的未推 commit。repo 裡有別的未推工作是人家的事,
    # 這支工具去報那個只會製造雜訊(2026-08-18:小說 repo 的 9 個創作 commit 被誤報成問題)。
    if [ "$ahead" -gt 0 ] && git -C "$r" log '@{u}..HEAD' --format=%H -- "${f#$r/}" | grep -q .; then
      msg="$msg  捲版的 commit 沒推出去（$ahead 個未推）"
    fi
    [ "$behind" -gt 0 ] && [ "${ver:-0}" -lt "$VERSION" ] && msg="$msg  本地落後 $behind 個（要 git pull）"
    [ "${ver:-0}" -lt "$VERSION" ] && msg="$msg  檔案還是 v$ver"
    # 有開著的捲版 PR 就把狀態講出來(推出去 ≠ 合進 main)
    local pr; pr=$(gh pr view "promo-footer-v$VERSION" --repo "yazelin/$name" \
      --json state,mergeStateStatus --jq '"\(.state)/\(.mergeStateStatus)"' 2>/dev/null)
    case "$pr" in
      OPEN/*) msg="$msg  PR 還沒合（$pr）" ;;
      MERGED/*) [ "${ver:-0}" -lt "$VERSION" ] && msg="$msg  PR 已合，本地沒同步" ;;
    esac
    [ -n "$msg" ] && { say "  $name:$msg"; bad=1; }
  done
  [ "$bad" = "0" ] && say "  ${#targets[@]} 個檔案、全部 repo 都同步到 v$VERSION 了。"
  return $bad
}

if [ "$VERIFY_ONLY" = "1" ]; then
  say ""; say "驗收（推出去了 ≠ 合進 main ≠ 本地跟上）："
  verify; exit $?
fi

# ── 2. 套用 ──
changed=()
for f in "${targets[@]}"; do
  line=$(grep -o 'var REPO="[^"]*",INJECT=[a-z]*' "$f" | head -1)
  [ -z "$line" ] && { say "  PARSE-FAIL（讀不到參數）: $f"; continue; }
  repo=$(echo "$line" | sed 's/var REPO="\([^"]*\)".*/\1/')
  inj=""; echo "$line" | grep -q 'INJECT=true' && inj="--inject"
  blog=""; grep -q 'ADDBLOG=false' "$f" && blog="--no-blog"
  if [ "$DRY" = "1" ]; then
    cur=$(grep -o 'yz-promo-footer v[0-9]*' "$f" | head -1 | grep -oE '[0-9]+')
    [ "$cur" -lt "$VERSION" ] && { say "  會升級 v$cur→v$VERSION: $f"; changed+=("$f"); }
  else
    out=$(python3 "$APPLY" "$f" "$repo" $inj $blog)
    echo "$out" | grep -q '^upgraded' && changed+=("$f")
  fi
done
say "要更新 ${#changed[@]} 個檔案"
[ "${#changed[@]}" = "0" ] && { say "沒有東西要做。"; exit 0; }

# ── 3. 逐 repo:bump SW、只 stage 動到的檔、commit、push 或 PR ──
mapfile -t repos < <(for f in "${changed[@]}"; do git -C "$(dirname "$f")" rev-parse --show-toplevel 2>/dev/null; done | sort -u)
for r in "${repos[@]}"; do
  name=$(basename "$r")
  files=(); for f in "${changed[@]}"; do [[ "$f" == "$r/"* ]] && files+=("${f#$r/}"); done
  # 離線 PWA:SW 快取沒 bump,舊快取會蓋住新頁面(坑 3)
  sw=""; bump=""
  for c in sw.js service-worker.js; do
    [ -f "$r/$c" ] && grep -qE "index.html|PRECACHE|urlsToCache|ASSETS" "$r/$c" && { sw="$c"; break; }
  done
  if [ -n "$sw" ]; then
    old=$(grep -oE "CACHE[A-Z_]*[[:space:]]*=[[:space:]]*['\"][^'\"]*v[0-9]+" "$r/$sw" | head -1 | grep -oE 'v[0-9]+$')
    if [ -n "$old" ]; then
      new="v$(( ${old#v} + 1 ))"; bump="$sw $old→$new"
      [ "$DRY" = "0" ] && sed -i "0,/$old/s//$new/" "$r/$sw"
    fi
  fi
  # main 有保護的走 branch + PR(坑 4)。用 gh 問,不寫死清單
  prot=0
  if [ "$DRY" = "0" ]; then
    gh api "repos/yazelin/$name/branches/$(git -C "$r" symbolic-ref --short HEAD)/protection" >/dev/null 2>&1 && prot=1
  fi
  say "$name: ${#files[@]} 檔${bump:+  bump $bump}$([ "$prot" = "1" ] && echo '  [main 有保護→PR]')"
  [ "$DRY" = "1" ] && continue
  msg="chore: promo-footer 升到 v$VERSION

由 promo-footer-skill/release.sh 自動鋪版。${bump:+
service worker 快取版號一併 bump（$bump），不然舊快取會蓋住新頁面。}

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
  ( cd "$r" || exit
    git add -- "${files[@]}" ${sw:+"$sw"} 2>/dev/null
    git diff --cached --quiet && { echo "  （沒有變更）"; exit 0; }
    if [ "$prot" = "1" ]; then
      br="promo-footer-v$VERSION"
      # 分支要從「最新的 origin/main」開,不是從本地 main。
      # 2026-08-18 踩到:本地 main 落後一個 commit,開出來的分支跟遠端衝突,
      # PR 直接變 DIRTY、auto-merge 不會動,要人工 rebase 才發現。
      base=$(git symbolic-ref --short HEAD)
      git stash -q -u 2>/dev/null
      git fetch -q origin "$base" 2>/dev/null
      git checkout -q -B "$br" "origin/$base" 2>/dev/null || git checkout -q -b "$br" 2>/dev/null || git checkout -q "$br"
      git stash pop -q 2>/dev/null
      git -c user.name=yazelin commit -q -m "$msg" \
        && git push -q -u origin "$br" 2>/dev/null \
        && gh pr create --fill --head "$br" >/dev/null 2>&1 \
        && gh pr merge --auto --squash >/dev/null 2>&1 && echo "  → PR 已開，auto-merge"
      git checkout -q - 2>/dev/null
    else
      git -c user.name=yazelin commit -q -m "$msg" \
        && { git push -q 2>/dev/null || { git pull --rebase -q && git push -q; }; } \
        && echo "  → 已推" || echo "  → 推失敗，要手動處理"
    fi )
done

# ── 4. 收尾:記版號鎖、驗每個 repo 都推上去了(坑 5) ──
if [ "$DRY" = "0" ]; then
  printf '%s\t%s\n' "$VERSION" "$tplhash" > "$LOCK"
  say ""; say "驗收（推出去了 ≠ 合進 main ≠ 本地跟上）："
  verify || true
fi
