#!/bin/bash
# upgrade-all.sh 的下半場:把改完的檔案逐 repo commit+push。
# push 被拒時分流:protected branch → 自動開 branch+PR(auto-merge);archived(403)→ 標記人工。
# 用法: push-all.sh "<commit 訊息>" [掃描根目錄,預設 $HOME]
# 只 stage「帶 yz-promo-footer 標記的 html」+「有 CACHE -vN 版號的 sw.js」,不掃到別的髒檔。
set -u
MSG="${1:?用法: push-all.sh \"<commit 訊息>\" [root]}"
ROOT="${2:-$HOME}"
VER=$(grep -o 'yz-promo-footer v[0-9]*' "$(dirname "$0")/snippet.template.html" | grep -o '[0-9]*$')
TRAILER="Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"

grep -rl --include='*.html' "yz-promo-footer v" "$ROOT" \
  --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist --exclude-dir=build 2>/dev/null \
  | grep -v "promo-footer" \
  | while read -r f; do git -C "$(dirname "$f")" rev-parse --show-toplevel 2>/dev/null; done \
  | sort -u | while read -r repo; do
  cd "$repo" || continue
  # 只挑本 skill 會動的檔:標記 html + 版號 sw.js
  files=""
  while read -r st path; do
    case "$path" in
      *.html) grep -q "yz-promo-footer" "$path" 2>/dev/null && files="$files $path";;
      sw.js|*/sw.js) grep -qE 'CACHE.*-v[0-9]+' "$path" 2>/dev/null && files="$files $path";;
    esac
  done < <(git status --porcelain | grep '^ M ')
  ahead=$(git rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)
  [ -z "$files" ] && [ "$ahead" -eq 0 ] && continue
  br=$(git symbolic-ref --short HEAD 2>/dev/null)
  if [ "$br" != "main" ] && [ "$br" != "master" ]; then echo "FLAG(非預設分支 $br): $repo"; continue; fi
  # 本地落後遠端(常見:protected repo 的 PR 已在遠端合掉)→ 直接 commit 會 non-ff 卡死。
  # 處理法固定:reset --hard origin/<br> 後重跑 upgrade-all.sh 再跑本腳本。
  git fetch -q 2>/dev/null
  if [ "$(git rev-list --count "HEAD..origin/$br" 2>/dev/null || echo 0)" -gt 0 ]; then
    echo "FLAG(本地落後 origin/$br,先 reset --hard origin/$br 再重跑 upgrade-all + push-all): $repo"; continue
  fi
  if [ -n "$files" ]; then
    git add $files || continue
    git commit -qm "$MSG

$TRAILER" || continue
  fi
  err=$(git push 2>&1) && { echo "pushed: $(basename "$repo")"; continue; }
  if echo "$err" | grep -qi "protected"; then
    nb="feat/promo-footer-v$VER"
    git branch -f "$nb" && git reset -q --hard "origin/$br" && git push -qu origin "$nb" \
      && gh pr create --head "$nb" --fill-first >/dev/null 2>&1 \
      && gh pr merge "$nb" --auto --squash >/dev/null 2>&1 \
      && echo "PR(auto-merge): $(basename "$repo") [$nb]" \
      || echo "FLAG(PR 流程失敗,手查): $repo"
  elif echo "$err" | grep -q "403"; then
    # archived repo:解封存 → 推 → 封回。gh 做得到;但 Claude agent 跑到這步會被
    # 它自己的權限層擋住 → fallback 標記人工。yazelin 自己跑本腳本則全自動。
    slug=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)
    if [ -n "$slug" ] && gh repo unarchive "$slug" --yes 2>/dev/null; then
      # 封回前必等 Pages build 完成——archived repo 不跑 build,推完馬上封=白推
      if git push -q; then
        gh api "repos/$slug/pages/builds" -X POST >/dev/null 2>&1
        for i in $(seq 1 30); do
          st=$(gh api "repos/$slug/pages/builds/latest" -q .status 2>/dev/null)
          [ "$st" = "built" ] && break
          [ "$st" = "errored" ] && { echo "FLAG(Pages build 失敗): $repo"; break; }
          sleep 5
        done
        gh repo archive "$slug" --yes && echo "pushed(解封存→推→等build($st)→封回): $(basename "$repo")"
      else
        gh repo archive "$slug" --yes; echo "FLAG(解封存了但推失敗,已封回): $repo"
      fi
    else
      echo "FLAG(archived/403,commit 留在本地,跑一次本腳本或手動解封存): $repo"
    fi
  else
    echo "FLAG(push 失敗: $(echo "$err" | tail -1)): $repo"
  fi
done
