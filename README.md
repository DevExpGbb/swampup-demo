# swampup-demo — APM live demo (consumer)

The **consumer** half of the APM keynote demo for **JFrog SwampUp NYC**.
One manifest ([`apm.yml`](apm.yml)) pins agent skills with semver, deploys them
into **both GitHub Copilot and Claude**, locks them for reproducibility, and
gates every change through an **org-governed `apm audit`** in CI.

Producer catalog: **[DevExpGbb/swampup-skills](https://github.com/DevExpGbb/swampup-skills)**
· Org policy: **[DevExpGbb/.github](https://github.com/DevExpGbb/.github)** (`apm-policy.yml`)

> The story is one continuous arc — **portability → security → governance** —
> that should feel like a single motion: *software ate the world through package
> managers; agents will too; so here is the Agent Package Manager.*

---

## Prerequisites

```bash
apm --version          # 0.28.0+
gh auth status         # authenticated to github.com
```

Two throwaway scratch directories are used so the audience always sees a clean
slate. Create them, and stage the SkillSpector fixture used in Beat 7b, up front:

```bash
export DEMO=~/Repos/swampup-demo      # this repo (the governed consumer)
mkdir -p /tmp/scratch                 # ad-hoc installs (beats 1, 6, 7)

# Beat 7b — NVIDIA SkillSpector (opt-in, external, offline):
uv tool install "skillspector @ git+https://github.com/NVIDIA/SkillSpector.git"
apm experimental enable external-scanners
git clone https://github.com/DevExpGbb/poisoned-tracing-skill ~/Repos/poisoned-tracing-skill
export POISON=~/Repos/poisoned-tracing-skill/.apm/skills/tracing-helper/SKILL.md
```

---

## The demo beats

### Portability

**Beat 1 — install one skill, pinned to an exact version.**

```bash
cd /tmp/scratch && rm -rf beat1 && mkdir beat1 && cd beat1
apm install DevExpGbb/swampup-skills/plugins/otel-tracing#v1.0.0
```

One package, one exact tag. Open the skill — the `v1.0.0` copy has **no
`## Sampling` section**; that section only exists in `v1.1.0`. That difference
is what makes the next beat visible.

**Beat 2 — install from a manifest with semver ranges, into two harnesses.**

```bash
cd "$DEMO"
apm install
```

[`apm.yml`](apm.yml) declares `targets: [copilot, claude]` and pins
`otel-tracing#^1.0.0`. The range resolves to the **highest compatible tag
(`v1.1.0`)** — the one *with* the Sampling section — and deploys it into both
harnesses from a single line.

**Beat 3 — the same skill is now live in Copilot *and* Claude.**

```bash
ls .github/agents .github/instructions .agents/skills     # Copilot
ls .claude/agents .claude/rules       .claude/skills      # Claude
```

Identical primitives, two runtimes, zero copy-paste. That is portability.

**Beat 4 — the lockfile.**

```bash
sed -n '1,24p' apm.lock.yaml
```

`lockfile_version: 2` records the exact `resolved_commit`, `resolved_ref`
(`v1.1.0`) and per-file hashes for every dependency.

**Beat 5 — reproducible anywhere.**

```bash
cd /tmp/scratch && rm -rf repro && git clone "$DEMO" repro && cd repro
apm install --frozen
```

`--frozen` installs strictly from `apm.lock.yaml` and refuses to re-resolve —
byte-identical primitives on every machine and in CI.

**Beat 6 — transitive dependencies.**

```bash
cd /tmp/scratch && rm -rf beat6 && mkdir beat6 && cd beat6
apm install devexpgbb/swampup-skills/plugins/release-notes#^1.0.0
apm deps tree
```

`release-notes` composes `changelog-writer`, so installing one pulls both:

```
beat6 (local)
└── devexpgbb/swampup-skills/plugins/release-notes@1.1.0
    ├── 1 skills
    └── devexpgbb/swampup-skills/plugins/changelog-writer@1.1.0
```

> Run this in its **own** directory — the clean nested tree needs `release-notes`
> to be the only direct dependency from the catalog. (The lowercase owner keeps
> the resolved provenance matching APM's normalized `repo_url`, so the child
> nests instead of showing up detached.)

### Security

**Beat 7a — a poisoned package is blocked, fail-closed (zero config).**

```bash
cd /tmp/scratch && rm -rf beat7 && mkdir beat7 && cd beat7
apm install DevExpGbb/poisoned-tracing-skill#main
```

The skill hides invisible Unicode (a right-to-left override, a zero-width space)
around a **credential-exfiltration instruction** — a prompt-injection vector.
APM's built-in scanner **refuses to deploy it** before it can ever reach an
agent:

```
[x]   Blocked: devexpgbb/poisoned-tracing-skill contains critical hidden character(s)
  |-- Use --force to deploy anyway
  [!] 1 critical security finding(s) -- hidden characters detected
```

No external scanner required; the check is always on and defaults to *deny*
(exit 1).

**Beat 7b — go deeper with NVIDIA SkillSpector (open platform).**

Hidden characters are only the surface. APM is an *open* gate: point it at any
SARIF-native scanner and it folds the findings into the same report. Here is
[NVIDIA SkillSpector](https://github.com/NVIDIA/SkillSpector) reading the
package **before** it is ever installed:

```bash
apm experimental enable external-scanners        # one-time opt-in
apm audit --file "$POISON" --external skillspector
```

APM runs SkillSpector offline (`--no-llm`: deterministic, no network, no API
keys), then merges its SARIF with APM's own scan — every row attributed by
**source**:

```
                 [>] Audit Findings  (apm: 3, skillspector: 6)
 Severity   Source        File       Location  Category   Description
 CRITICAL   apm           SKILL.md   49:6      bidi-ovr   Right-to-left override
 CRITICAL   skillspector  SKILL.md    3:1      P2         Hidden Instructions
 CRITICAL   skillspector  SKILL.md    3:1      YR4        YARA: MCP/tool metadata poisoning
 CRITICAL   skillspector  SKILL.md   49:1      P2         Hidden Instructions
 WARNING    skillspector  SKILL.md    1:1      AE4        Suspicious Unicode / mixed-script
[x] 7 critical finding(s) in 2 file(s) — exit 1
```

Both engines contribute (`apm: 3, skillspector: 6`). APM's always-on check caught
the *hidden characters*; SkillSpector names the *intent* — the injected instruction
to leak `*_TOKEN` / `*_KEY` / `*_SECRET`. Defense in depth, one gate. SkillSpector
is opt-in and external; **APM only consumes its SARIF and publishes nothing back.**

### Governance

**Beat 8 — an unapproved source is blocked by org policy.**

```bash
cd "$DEMO"
apm install danielmeppiel/unapproved-skill#main
```

Nothing is wrong with the code — the source is simply **not on the DevExpGbb
allow-list**. The org policy stops it at install time, in ~3 seconds:

```
[x] Policy violation: dependency-allowlist -- 1 dependency(ies) not in allow list:
    danielmeppiel/unapproved-skill: not in allowed sources
[x] Install blocked by org policy
```

**Beat 9 — the same policy enforced on a pull request.**

Every dependency here is allowed *and* the org **requires** the
`secure-baseline` package. Drop that pin and CI goes red:

```bash
cd "$DEMO"
git checkout -b demo/drop-baseline
# remove the secure-baseline line from apm.yml, regenerate the lockfile:
apm install --no-policy
git commit -am "demo: drop the security baseline"
gh pr create --fill
```

The [`apm-audit` CI gate](.github/workflows/ci.yml) — a reusable workflow
published by `zava-agent-config` — fails on `required-packages`. The `main`
branch stays green; the violating PR cannot merge. Governance is not a
document, it is a **check**.

### Hand-off to JFrog

**Beat 10 — pack it all into one portable, verifiable artifact.**

```bash
cd "$DEMO"
apm pack --archive
```

Everything the manifest resolved — agents, instructions, skills — collapses into a
single **`swampup-demo-0.1.0.zip`** with the **lockfile embedded** for install-time
integrity verification. APM even prints `Share with: apm install <zip>`, because the
bundle installs anywhere APM runs:

```bash
apm install build/swampup-demo-0.1.0.zip    # deploys the whole bundle into a fresh project
```

That single artifact is the hand-off: **Yonatan takes this same bundle into JFrog
Artifactory**, and `apm install` resolves it straight from the registry — same
manifest, same lockfile, your registry.

---

## What the audience sees

| # | Beat | Command | Result |
|---|------|---------|--------|
| 1 | Exact install | `apm install …/otel-tracing#v1.0.0` | one skill, pinned |
| 2 | Semver → 2 harnesses | `apm install` | `^1.0.0` → `v1.1.0`, Copilot + Claude |
| 3 | Portability | `ls .github/… .claude/… .agents/…` | same skill, both runtimes |
| 4 | Lockfile | `cat apm.lock.yaml` | commit + hashes pinned |
| 5 | Reproducible | `apm install --frozen` | byte-identical from lock |
| 6 | Transitive | `apm install …/release-notes#^1.0.0` → `apm deps tree` | `release-notes → changelog-writer` |
| 7a | Poison blocked | `apm install …/poisoned-tracing-skill` | fail-closed, hidden Unicode |
| 7b | Deep scan (SkillSpector) | `apm audit --file "$POISON" --external skillspector` | NVIDIA SkillSpector merged, injection intent named |
| 8 | Unapproved source | `apm install danielmeppiel/unapproved-skill` | allow-list violation |
| 9 | Policy on a PR | drop baseline → open PR | CI red on `required-packages` |
| 10 | Pack → JFrog hand-off | `apm pack --archive` | one portable `.zip`, lockfile embedded, installs anywhere |

## The moving parts

| Repo | Role |
|------|------|
| **swampup-demo** (this) | governed consumer — `apm.yml`, `apm.lock.yaml`, repo `apm-policy.yml`, CI |
| **swampup-skills** | producer catalog — `otel-tracing`, `changelog-writer`, `release-notes` |
| **zava-agent-config** | org security baseline + the reusable `apm-audit` CI workflow |
| **poisoned-tracing-skill** | beat 7 fixture — hidden-Unicode + prompt-injection payload (native + SkillSpector both flag it) |
| **danielmeppiel/unapproved-skill** | beat 8 fixture — a source outside the allow-list |
| **DevExpGbb/.github** | org `apm-policy.yml` — allow-list, deny-list, required baseline |

---

Hand-off line to Yonatan (JFrog): *`apm pack` gave us one portable, lockfile-verified
artifact — Yonatan now takes this same bundle into Artifactory, where it resolves
straight from the registry: same manifest, same lockfile, your registry.*
