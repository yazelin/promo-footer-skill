#!/bin/bash
# 掃描全部 repo 裡帶 yz-promo-footer 標記的 HTML,照各檔既有參數就地升級到最新版。
# 用法: upgrade-all.sh [掃描根目錄,預設 $HOME]
# 清單靠掃描產生,不靠人列——v1/v2 時代漏列過 repo(bye-bg 停在 v1 兩波沒升到)。
# 升級後仍要人工處理:各 repo commit/push、離線 PWA bump SW 快取版本。
ROOT="${1:-$HOME}"
APPLY="$(dirname "$0")/apply.py"
grep -rl --include='*.html' "yz-promo-footer v" "$ROOT" \
  --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist --exclude-dir=build 2>/dev/null \
  | grep -v "promo-footer" | sort | while read -r f; do
  line=$(grep -o 'var REPO="[^"]*",INJECT=[a-z]*' "$f" | head -1)
  if [ -z "$line" ]; then echo "PARSE-FAIL: $f"; continue; fi
  repo=$(echo "$line" | sed 's/var REPO="\([^"]*\)".*/\1/')
  inj=""; echo "$line" | grep -q 'INJECT=true' && inj="--inject"
  blog=""; grep -q 'ADDBLOG=false' "$f" && blog="--no-blog"
  python3 "$APPLY" "$f" "$repo" $inj $blog
done
