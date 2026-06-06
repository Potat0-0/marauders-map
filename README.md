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


Or use the full scanner:

```bash
git clone https://github.com/Potat0-0/marauders-map
cd marauders-map
chmod +x scripts/scan.sh
./scripts/scan.sh /path/to/your/project
```

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
