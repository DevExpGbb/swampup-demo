#!/usr/bin/env bash
###############################################################################
# keynote-demo.sh — scripted, ENTER-to-advance runner for the APM keynote.
#
# Why: on a single mirrored screen you can't keep notes off the projector.
# This runner holds every command so you never type or memorise one — the
# room sees only a clean prompt and real output.
#
# Rhythm per beat:   ENTER → the command types itself → (you talk) → ENTER → it runs.
#   • Flags:  -d  no typing (debug)   ·   -w<sec>  auto-advance after <sec> (rehearse)
#   • Beats intentionally exit non-zero (7a/8 are *blocks*) — the script keeps going.
#
# Prereqs — run DEMO-COMMANDS.md "§0 · Pre-flight" first (idempotent):
#   apm 0.29+, gh auth, skillspector, `external-scanners` flag, the poisoned clone.
#   Plus the typewriter dependency:   brew install pv
#
# Uses demo-magic.sh — MIT © 2015-2022 Paxton Hare — vendored alongside this file
# (see demo-magic.license.txt). Upstream: https://github.com/paxtonhare/demo-magic
###############################################################################

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── environment (mirrors §0; assumes §0 setup is already done) ────────────────
export PATH="/opt/homebrew/bin:$PATH:$HOME/.local/bin"
export DEMO="${DEMO:-$HOME/Repos/swampup-demo}"
export POISON="${POISON:-$HOME/Repos/poisoned-tracing-skill/.apm/skills/tracing-helper/SKILL.md}"
export APM_LOG_LEVEL="${APM_LOG_LEVEL:-ERROR}"
PR_URL="https://github.com/DevExpGbb/swampup-demo/pull/1"
OPEN_CMD="${OPEN_CMD:-open}"          # set OPEN_CMD=echo for a browserless dry run
mkdir -p /tmp/scratch

# ── pre-flight guard: fail fast (and quietly) if §0 wasn't run ────────────────
command -v apm >/dev/null || { echo "✗ apm not found — run §0 pre-flight";        exit 1; }
command -v pv  >/dev/null || { echo "✗ pv not installed — 'brew install pv' (or run with -d)"; exit 1; }
[ -f "$POISON" ]          || { echo "✗ poison fixture missing — run §0 clone: $POISON"; exit 1; }

# shellcheck source=demo-magic.sh disable=SC1091
. "$HERE/demo-magic.sh"

clear
# ═══════════════════════════  PORTABILITY  ═══════════════════════════
# Beat 1 — install one skill, pinned to an exact version
cd /tmp/scratch && rm -rf beat1 && mkdir beat1 && cd beat1
pe "apm install DevExpGbb/swampup-skills/plugins/otel-tracing#v1.0.0"
wait; clear

# Beat 2 — install from a manifest with semver ranges, into two harnesses
cd "$DEMO"
pe "apm install"
# Beat 3 — the same skill is now live in Copilot *and* Claude
pe "ls .github/agents .github/instructions .agents/skills"
pe "ls .claude/agents .claude/rules       .claude/skills"
wait; clear

# Beat 4 — the lockfile
pe "sed -n '1,24p' apm.lock.yaml"
wait; clear

# Beat 5 — reproducible anywhere
cd /tmp/scratch && rm -rf repro && git clone -q "$DEMO" repro && cd repro
pe "apm install --frozen"
wait; clear

# Beat 6 — transitive dependencies (throwaway flex: run it, one line, move on)
cd /tmp/scratch && rm -rf beat6 && mkdir beat6 && cd beat6
pe "apm install devexpgbb/swampup-skills/plugins/release-notes#^1.0.0"
pe "apm deps tree"
wait; clear

# ═══════════════════════════  SECURITY  ═══════════════════════════
# Beat 7a — a poisoned package is blocked, fail-closed (zero config)
cd /tmp/scratch && rm -rf beat7 && mkdir beat7 && cd beat7
pe "apm install DevExpGbb/poisoned-tracing-skill#main"
wait; clear

# Beat 7b — go deeper with NVIDIA SkillSpector (open platform)
pe 'apm audit --file "$POISON" --external skillspector'
wait; clear

# ═══════════════════════════  GOVERNANCE  ═══════════════════════════
# Beat 8 — an unapproved source is blocked by org policy
cd "$DEMO"
pe "apm install danielmeppiel/unapproved-skill#main"
wait; clear

# Beat 9 — the same policy enforced on a pull request (open the standing red PR)
pe "$OPEN_CMD $PR_URL"
wait; clear

# ═══════════════════════  HAND-OFF TO JFROG  ═══════════════════════
# Beat 10 — pack the whole thing into one portable, verifiable artifact
cd "$DEMO"
pe "apm pack --archive"
mkdir -p /tmp/scratch/beat10 && cd /tmp/scratch/beat10
pe 'apm install "$DEMO/build/swampup-demo-0.1.0.zip" --target copilot,claude'
wait

echo ""
echo "— end of demo — hand off to Yonatan: same manifest, same lockfile, your registry."
