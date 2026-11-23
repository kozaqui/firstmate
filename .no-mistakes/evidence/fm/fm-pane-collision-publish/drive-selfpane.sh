#!/usr/bin/env bash
# Drives the real firstmate CLIs against an isolated Herdr lab session.
# A lab FM_HOME holds task t1 whose record names lab pane w1:p2 (a restored worker tab).
# "self" runs set the caller identity to that pane, as when firstmate resumes inside it;
# "other" runs use pane w1:p1 as a control.
set -u
REPO=$1 S=$2 LAB=$3 W=$4
cd "$REPO"
lab() { bin/fm-herdr-lab.sh run "$S" "$@"; }
self() { env -u NO_MISTAKES_GATE -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE -u FM_CONFIG_OVERRIDE -u FM_PROJECTS_OVERRIDE -u HERDR_SOCKET_PATH FM_HOME="$LAB" HERDR_ENV=1 HERDR_SESSION="$S" HERDR_PANE_ID=w1:p2 "$@"; }
other() { env -u NO_MISTAKES_GATE -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE -u FM_CONFIG_OVERRIDE -u FM_PROJECTS_OVERRIDE -u HERDR_SOCKET_PATH FM_HOME="$LAB" HERDR_ENV=1 HERDR_SESSION="$S" HERDR_PANE_ID=w1:p1 "$@"; }
writemeta() { # <kind>
  printf '%s\n' "window=$S:w1:p2" "endpoint_task_id=t1" "worktree=$W" "project=$W" "kind=$1" \
    "harness=claude" "backend=herdr" "herdr_session=$S" "herdr_workspace_id=w1" \
    "herdr_tab_id=w1:t2" "herdr_pane_id=w1:p2" > "$LAB/state/t1.meta"
}
hdr() { printf '\n===== %s =====\n' "$1"; }
run() { printf '$ %s\n' "$*"; "$@"; printf '[exit %s]\n' "$?"; }
pane_text() { lab pane read w1:p2 --lines 40 2>/dev/null; }

writemeta ship
hdr "S1 peek: self pane refused, other pane reads the worker"
run self bin/fm-peek.sh t1 20
run other bin/fm-peek.sh t1 20 | grep -c WORKER-PANE-MARKER

hdr "S2 send: self pane refused, nothing typed into the pane"
run self bin/fm-send.sh t1 'SELF-SEND-PROBE'
sleep 1
printf 'pane w1:p2 contains SELF-SEND-PROBE: '; pane_text | grep -c SELF-SEND-PROBE

hdr "S3 crew-state: self pane reports t1 gone, other pane does not"
run self bin/fm-crew-state.sh 2>&1 | grep -E 't1|own pane' | head -5
run other bin/fm-crew-state.sh 2>&1 | grep -E 't1' | head -5

hdr "S4 session-start digest: self pane endpoint reads dead"
self bin/fm-session-start.sh 2>&1 | grep -E 'endpoint:' | head -5
other bin/fm-session-start.sh 2>&1 | grep -E 'endpoint:' | head -5

hdr "S5 control interrupt/exit: self pane gets no lifecycle input"
run self bin/fm-control.sh t1 interrupt
run self bin/fm-control.sh t1 exit
printf 'pane w1:p2 still listed: '; lab pane list | jq -r '[.result.panes[].pane_id]|join(",")'

hdr "S6 teardown --force: self pane refused before mutation"
writemeta ship
run self bin/fm-teardown.sh t1 --force
printf 't1.meta present: '; [ -f "$LAB/state/t1.meta" ] && echo yes || echo no
printf 'panes: '; lab pane list | jq -r '[.result.panes[].pane_id]|join(",")'
printf 'tabs: '; lab tab list --workspace w1 | jq -r '[.result.tabs[]|.tab_id+"="+.label]|join(",")'

hdr "S7 secondmate record: refusal names fm-spawn --secondmate"
writemeta secondmate
run self bin/fm-peek.sh t1 20
run self bin/fm-send.sh t1 'SELF-SEND-PROBE2'
writemeta ship
