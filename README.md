# Void Dokkaebi — Detector & IOC Repository

Detection tooling, indicators of compromise (IOCs), and analysis notes for the
**Void Dokkaebi** campaign (also tracked as *Contagious Interview* / *Famous Chollima*) —
a DPRK-attributed supply chain attack targeting JavaScript developers via fake job
interviews, with malicious code hidden in `tailwind.config.js`, 
`routes/user.js`, and similar files, using the **TRON blockchain (TronGrid API) as C2**.

> This repo is maintained by an independent researcher who was a confirmed victim
> of this campaign. It complements the
> [Trend Micro April 2026 report](https://www.trendmicro.com/en/research/26/d/void-dokkaebi-uses-fake-job-interview-lure-to-spread-malware-via-code-repositories.html)
> with first-hand IOCs and detection tooling.

---

## What's in this repo

| Path | Contents |
|---|---|
| `/iocs/` | Wallet addresses, file hashes, code strings, API endpoints |
| `/scripts/` | Bash + Python detection scripts for local and remote scanning |
| `/rules/yara/` | [todo] YARA rules for TronGrid C2 pattern detection |
| `/rules/semgrep/` | [todo] Semgrep rules for CI pipeline integration |
| `/notes/` | Analysis notes, timeline, infection methodology |

---

## Quick Start

Or use the full scanner:

```bash
git clone https://github.com/Potat0-0/marauders-map
cd marauders-map
chmod +x scripts/scan.sh
./scripts/scan.sh /path/to/your/project
```

---

## Scripts

This repository includes multiple detection scripts, each targeting different aspects of the Void Dokkaebi campaign. All scripts are located in the `/scripts/` directory.

### Prerequisites

All scripts require `git` and `bash` (version 3+). Most are compatible with macOS, Linux, and Windows (Git Bash).

For JavaScript-based scanning (`scanner.js`), Node.js 14+ is required.

### Available Scripts

#### 1. **`git_tz_forensics.sh`** — Git History Forensics
Analyzes your git repository for signs of history tampering and commit anomalies that indicate malicious activity.

**What it detects:**
- Author/committer timezone mismatches (sign of history rewriting in a foreign environment)
- Outlier committer timezones compared to repository baseline
- Reflog entries showing forced rewrites (amend, rebase, force-push, filter-branch, reset, cherry-pick)
- Twin commits (same message + author date, different hash = rewritten commits)
- Chronological violations (author date after committer date)

**Usage:**
```bash
./scripts/git_tz_forensics.sh [repo_path]
./scripts/git_tz_forensics.sh              # uses current directory
./scripts/git_tz_forensics.sh /home/dev/myproject
```

**Example output:**
```
Repository: /home/dev/myproject
Analysis : 2026-06-10 14:32:10 UTC

SECTION 1 · Baseline Timezone Detection
  Committer timezone distribution:
    150 commits  +00:00  ████████████████████████████
     42 commits  -05:00  ████████
     15 commits  +08:00  ███

  Baseline (dominant) committer timezone: +00:00

SECTION 2 · Author / Committer Timezone Mismatch
  ⚑  abc123def "Add malicious config"
       Author    date : 2026-06-01T10:00:00+00:00  (myname)
       Committer date : 2026-06-01T10:00:00-05:00  (myname)
       Timezone shift: author=+00:00  committer=-05:00

⚑  3 anomalies detected across all checks.
```

**Exit codes:**
- `0` — No anomalies found
- `1` — Anomalies detected (review immediately)
- `2` — Error (not a git repo or invalid path)

---

#### 2. **`polinrider-checker.sh`** — Node Modules Scanner
Scans your `node_modules/` directory for suspicious patterns commonly found in supply chain attacks.

**What it checks:**
- `eval()` + Base64 decoding patterns
- Suspicious `postinstall` scripts in package.json
- Obfuscated long strings (Base64-encoded payloads)
- External network calls (HTTP/HTTPS, fetch, axios)
- Files with suspicious Unicode/invisible characters
- Recently modified files (last 7 days)

**Usage:**
```bash
./scripts/polinrider-checker.sh
# Must be run in a directory containing node_modules/
# Example:
cd ~/myproject && ../../scripts/polinrider-checker.sh
```

**Example output:**
```
🔍 Scanning node_modules for suspicious patterns...
----------------------------------------
1. Searching for eval + base64 patterns...
node_modules/tailwind-plugin-evil/index.js:42:eval(Buffer.from('...',base64'))

2. Searching for suspicious postinstall scripts...
node_modules/tailwind/package.json:  "postinstall": "node scripts/compile.js"

3. Searching for obfuscated long strings...
node_modules/plugin-xyz/lib.js:123:const X='SGVsbG8gV29ybGQgSXMgQWxhcm0gVG8gRGFya25lc3M=';

...

✅ Scan complete. Review findings carefully.
```

---

#### 3. **`scanner.js`** — JavaScript Code Heuristic Scanner
Analyzes JavaScript/TypeScript files for obfuscation and code injection patterns using heuristic scoring.

**What it detects:**
- Character encoding tricks (`String.fromCharCode`, `charCodeAt`, etc.)
- Dynamic code execution (`eval()`, `Function()`, `.constructor()`)
- Base64-ish long strings (potential encoded payloads)
- Hex/Unicode escape sequences
- Very long suspicious lines (>300 chars)

**Scoring system:**
- Each suspicious pattern adds points; lines scoring ≥4 are reported
- Higher-weight patterns (eval, Function): +4 points
- Encoding patterns (charCodeAt, fromCharCode): +2–3 points
- Long lines: +2 points

**Usage:**
```bash
node ./scripts/scanner.js [root_path]
node ./scripts/scanner.js              # scans current directory
node ./scripts/scanner.js /home/dev/myproject
```

**Example output:**
```
src/index.js:15 [score=5] -> String.fromCharCode, long_line
src/config/evil.mjs:42 [score=6] -> eval, Function, charCodeAt
routes/user.js:89 [score=4] -> atob
```

**Directories skipped:** `node_modules`, `.git`, `dist`, `build`, `coverage`

---

#### 4. **`void-vscode-tasks-scanner.sh`** — VS Code Tasks Locator
Searches your machine for `.vscode/tasks.json` files, which can contain malicious task definitions executed by agentic coding tools.

**Why this matters:**
This campaign specifically targets agentic coding tools (VS Code Copilot, Cursor, Claude Code) that auto-execute VS Code tasks. Malicious tasks in `.vscode/tasks.json` can run arbitrary commands during AI-assisted coding sessions.

**Usage:**
```bash
./scripts/void-vscode-tasks-scanner.sh [directory1] [directory2] ...
./scripts/void-vscode-tasks-scanner.sh              # search current directory
./scripts/void-vscode-tasks-scanner.sh ~/projects   # search single directory
./scripts/void-vscode-tasks-scanner.sh ~/projects ~/work /srv  # search multiple roots
```

**Example output:**
```
Searching for .vscode/tasks.json …
════════════════════════════════════════════════
Root: /home/user/projects
  ✔  project-a/.vscode/tasks.json
       → /home/user/projects/project-a/.vscode/tasks.json
  ✔  project-b/.vscode/tasks.json
       → /home/user/projects/project-b/.vscode/tasks.json

════════════════════════════════════════════════
Found 2 file(s):
  /home/user/projects/project-a/.vscode/tasks.json
  /home/user/projects/project-b/.vscode/tasks.json
```

**After finding tasks.json files:**
- Inspect the content for suspicious `"command"` fields
- Look for network calls, credential exfiltration, or git history tampering
- Check the `"runOptions"` — if `"runWhen": "folderOpen"` or similar, the task auto-executes

---

## Recommended Scanning Workflow

1. **Start with git forensics:**
   ```bash
   ./scripts/git_tz_forensics.sh ~/myproject
   ```
   If anomalies are found → possible infection; proceed to step 2.

2. **Check for suspicious agent tasks:**
   ```bash
   ./scripts/void-vscode-tasks-scanner.sh ~/myproject
   # Inspect any .vscode/tasks.json files found
   ```

3. **Scan JavaScript for obfuscation:**
   ```bash
   cd ~/myproject
   node ../../marauders-map/scripts/scanner.js .
   ```

4. **If you have node_modules, check for malicious packages:**
   ```bash
   cd ~/myproject
   ../../marauders-map/scripts/polinrider-checker.sh
   ```

5. **Review IOCs:**
   - Check `/iocs/` in this repo for known wallet addresses, file hashes, and code signatures
   - Compare findings against known indicators

---

## IOC summary

Full list in `/iocs/`. Highlights:

- **C2 channel:** `api.trongrid.io` (TRON blockchain)
- **Fallback C2:** Aptos blockchain API
- **Infection markers:** `global['!']`, `global['_V']`
- **Targeted files:** `tailwind.config.js`, `routes/user.js`, `postcss.config.mjs`, `next.config.mjs`, `eslint.config.mjs`
- **Commit tampering tool:** `temp_auto_push.bat` (Windows); macOS equivalent under investigation
- **Versioned persistence markers:** `C250617A`, `C250618A`, `C250619A`, `C250620A`

---

## Who this is for

- **Developers** who want to check their own projects
- **Security teams** integrating detection into CI/CD pipelines
- **Threat intelligence researchers** tracking this campaign
- **Incident responders** investigating a suspected Void Dokkaebi infection

---

## Background

Full writeup: [[Medium post link]]

This repo grew out of a personal investigation after finding malicious code spread
across three of my own git repositories — all committed under my own identity,
all during VS Code Copilot agent sessions. The Copilot agent involvement is an
**undocumented angle** not present in the Trend Micro report and is still under
active investigation. Community input welcome.

---

## Contributing

If you've found this campaign in your own projects:
- Open an issue with your IOCs (sanitize before posting — no live credentials)
- Submit a PR to `/iocs/` with additional wallet addresses, hashes, or strings
- Share your infection timeline if you used agentic coding tools (Copilot, Cursor,
  Claude Code) — this is the active research question

---

## References

- [Trend Micro: Void Dokkaebi (April 2026)](https://www.trendmicro.com/en/research/26/d/void-dokkaebi-uses-fake-job-interview-lure-to-spread-malware-via-code-repositories.html)
- [Microsoft MSTIC: Contagious Interview](https://www.microsoft.com/en-us/security/blog/2026/03/11/contagious-interview-malware-delivered-through-fake-developer-job-interviews/)
- [OpenSourceMalware: Neutralinojs compromise](https://opensourcemalware.com/blog/neutralinojs-compromise)

---

## Disclaimer

All tooling and IOCs are published for **defensive purposes only**.
No exploit code, no payload decryption logic, no active C2 credentials.
If you are a maintainer of an affected repository, please reach out before
taking public action — [your contact].
