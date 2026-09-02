# APM Keynote — copy‑paste command sheet (SwampUp NYC)

Paste‑and‑go. Run **§0 once** at the start; then paste each beat's block in order.
Every block is self‑contained (starts with its own `cd`) — you never have to edit a
path, swap a placeholder, or remember which directory you're in.

- Deck (run locally from the `apm-exec` deck app): **http://127.0.0.1:4321/index-keynote.html**
- Narration / "what the audience sees": [`README.md`](README.md) in this repo (the teleprompter).

---

## 0 · Pre‑flight — run once (idempotent; safe to re‑run in a fresh terminal)

```bash
export PATH="/opt/homebrew/bin:$PATH:$HOME/.local/bin"
export DEMO="$HOME/Repos/swampup-demo"
export POISON="$HOME/Repos/poisoned-tracing-skill/.apm/skills/tracing-helper/SKILL.md"
export APM_LOG_LEVEL=ERROR                    # quiet benign stdlib log noise (e.g. the .github-private policy probe); all security verdicts & blocks are styled output and still show
mkdir -p /tmp/scratch

apm --version && gh auth status              # apm 0.28.0+ (0.28 fixes range-install auth)
uv tool install "skillspector @ git+https://github.com/NVIDIA/SkillSpector.git"
apm experimental enable external-scanners
[ -d "$HOME/Repos/poisoned-tracing-skill" ] || git clone https://github.com/DevExpGbb/poisoned-tracing-skill "$HOME/Repos/poisoned-tracing-skill"
[ -f "$POISON" ] && echo "PRE-FLIGHT OK" || echo "POISON MISSING — check clone"
```

---

## PORTABILITY

### Beat 1 — install one skill, pinned to an exact version
```bash
cd /tmp/scratch && rm -rf beat1 && mkdir beat1 && cd beat1
apm install DevExpGbb/swampup-skills/plugins/otel-tracing#v1.0.0
```

### Beat 2 — install from a manifest with semver ranges, into two harnesses
```bash
cd "$DEMO"
apm install
```

### Beat 3 — the same skill is now live in Copilot *and* Claude
```bash
cd "$DEMO"
ls .github/agents .github/instructions .agents/skills     # Copilot
ls .claude/agents .claude/rules       .claude/skills      # Claude
```

### Beat 4 — the lockfile
```bash
cd "$DEMO"
sed -n '1,24p' apm.lock.yaml
```

### Beat 5 — reproducible anywhere
```bash
cd /tmp/scratch && rm -rf repro && git clone "$DEMO" repro && cd repro
apm install --frozen
```

### Beat 6 — transitive dependencies
```bash
cd /tmp/scratch && rm -rf beat6 && mkdir beat6 && cd beat6
apm install devexpgbb/swampup-skills/plugins/release-notes#^1.0.0
apm deps tree
```

---

## SECURITY

### Beat 7a — a poisoned package is blocked, fail‑closed (zero config)
```bash
cd /tmp/scratch && rm -rf beat7 && mkdir beat7 && cd beat7
apm install DevExpGbb/poisoned-tracing-skill#main
```

### Beat 7b — go deeper with NVIDIA SkillSpector (open platform)
```bash
apm audit --file "$POISON" --external skillspector
```

---

## GOVERNANCE

### Beat 8 — an unapproved source is blocked by org policy
```bash
cd "$DEMO"
apm install danielmeppiel/unapproved-skill#main
```

### Beat 9 — the same policy enforced on a pull request (pre‑staged, already red)
**No commands.** Open the standing PR — CI is red on `required-packages`, `main` stays green:

> https://github.com/DevExpGbb/swampup-demo/pull/1

Optional (only if you want to show the red build live from the terminal):
```bash
cd "$DEMO"
gh pr checks 1
```

---

## HAND-OFF TO JFROG

### Beat 10 — pack the whole thing into one portable, verifiable artifact
```bash
cd "$DEMO"
apm pack --archive                                   # → $DEMO/build/swampup-demo-0.1.0.zip (lockfile embedded)
# Prove portability: install into a brand-new, empty project — no manifest, no network
mkdir -p /tmp/scratch/beat10 && cd /tmp/scratch/beat10
apm install "$DEMO/build/swampup-demo-0.1.0.zip" --target copilot,claude
```
> One `.zip` (agents + instructions + skills + **embedded `apm.lock.yaml`**) drops into a
> clean project and rehydrates both harnesses — 14 files, no manifest, no network. This is
> the hand-off: Yonatan takes *this same bundle* into Artifactory. Line: *"same manifest,
> same lockfile, your registry."*

---

## Reset — two levels

**A · Between rehearsals** (fast; keeps §0's clone + tool + flag so you can re-run beats immediately).
Undoes everything the *beats* touched — the consumer repo (Beats 2/8/10) and every scratch project:
```bash
cd "$DEMO" && git checkout -- . && git clean -fd >/dev/null 2>&1   # restore all tracked + deployed files
rm -rf "$DEMO"/build "$DEMO"/.github/plugin "$DEMO"/.claude-plugin  # apm pack artifacts (gitignored)
apm install --frozen                                               # repopulate apm_modules/ to the locked state
rm -rf /tmp/scratch/*                                              # every beat's throwaway project (beat1/6/7/10, repro)
```

**B · Full teardown** (leave no trace; also undoes §0's pre-flight — run when you're completely done).
Self-contained — resets the repo, then removes what §0 installed on the machine:
```bash
cd "$DEMO" && git checkout -- . && git clean -fd >/dev/null 2>&1   # restore all tracked + deployed files
rm -rf "$DEMO"/build "$DEMO"/.github/plugin "$DEMO"/.claude-plugin  # apm pack artifacts
apm install --frozen                                               # repopulate apm_modules/
rm -rf /tmp/scratch                                               # the scratch root itself
rm -rf "$HOME/Repos/poisoned-tracing-skill"                       # §0: the poisoned-skill clone
uv tool uninstall skillspector                                    # §0: the external scanner
apm experimental disable external-scanners                        # §0: the install-time scan flag
```

---

### One‑glance beat → command map
| # | Beat | Command |
|---|------|---------|
| 1 | Exact install | `apm install …/otel-tracing#v1.0.0` |
| 2 | Semver → 2 harnesses | `apm install` |
| 3 | Portability | `ls .github/… .claude/… .agents/…` |
| 4 | Lockfile | `sed -n '1,24p' apm.lock.yaml` |
| 5 | Reproducible | `apm install --frozen` |
| 6 | Transitive | `apm install …/release-notes#^1.0.0` → `apm deps tree` |
| 7a | Poison blocked | `apm install …/poisoned-tracing-skill#main` |
| 7b | Deep scan | `apm audit --file "$POISON" --external skillspector` |
| 8 | Unapproved source | `apm install danielmeppiel/unapproved-skill#main` |
| 9 | Policy on a PR | open PR #1 (pre‑staged red) |
| 10 | Pack → JFrog hand-off | `apm pack --archive` → install `.zip` in a fresh project |
