#!/usr/bin/env bash
# BabyLog 팀 대시보드 — tmux 세션 'babylog'으로 진행 상황을 실시간 관찰
# 사용:  bash team/dashboard.sh        (세션 생성/재생성 후 attach 안내)
#        tmux attach -t babylog        (관찰 시작 / 분리: Ctrl-b d)
set -e
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
SESSION="babylog"

tmux kill-session -t "$SESSION" 2>/dev/null || true

# pane 0: Tasklist 보드 (상단 핵심부 실시간)
tmux new-session -d -s "$SESSION" -n board -c "$ROOT" \
  "while true; do clear; printf '\033[1m📋 Tasklist.md  (%s)\033[0m\n' \"\$(date '+%H:%M:%S')\"; echo '────────────────────────────────'; sed -n '1,80p' Tasklist.md; sleep 2; done"

# pane 1: process.md (최근 로그)
tmux split-window -h -t "$SESSION:board" -c "$ROOT" \
  "while true; do clear; printf '\033[1m📝 process.md (tail)\033[0m\n'; echo '────────────────────────────────'; tail -n 45 process.md; sleep 3; done"

# pane 2: git 상태 + 산출물 디렉토리
tmux split-window -v -t "$SESSION:board.1" -c "$ROOT" \
  "while true; do clear; printf '\033[1m🌿 git\033[0m\n'; echo '────────────────────────────────'; git log --oneline -10 2>/dev/null; echo; echo '── team/confirmations ──'; ls -1 team/confirmations 2>/dev/null; sleep 3; done"

tmux select-layout -t "$SESSION:board" main-vertical
echo "✅ tmux 세션 '$SESSION' 생성됨."
echo "   관찰:  tmux attach -t $SESSION   (분리: Ctrl-b 누른 뒤 d)"
