# digitalitem · Agent Skills

A curated, Chinese-annotated collection of agent skills for **ordinary users** — people who write documents, make slides, plan projects and run small businesses, not just engineers.

**77 packages** · all with an explicit license (MIT / Apache-2.0 / CC0) · each is a `SKILL.md` plus its references.

→ Site (113 entries, search, downloads): https://digitalitem.online/skills/
→ 中文说明: [README.zh.md](README.zh.md)

## What's inside

| Category | Packages | Examples |
|---|---|---|
| Small business & career | 52 | [ideal-customer-profile](skills/phuryn-pm-skills-pm-go-to-market-ideal-customer-profile/), [job-stories](skills/phuryn-pm-skills-pm-execution-job-stories/), [user-stories](skills/phuryn-pm-skills-pm-execution-user-stories/), [test-scenarios](skills/phuryn-pm-skills-pm-execution-test-scenarios/), [lean-canvas](skills/phuryn-pm-skills-pm-product-strategy-lean-canvas/), [business-model](skills/phuryn-pm-skills-pm-product-strategy-business-model/) … |
| Design | 9 | [frontend-slides](skills/frontend-slides/), [slides](skills/nextlevelbuilder-ui-ux-pro-max-skill-slides/), [banner-design](skills/nextlevelbuilder-ui-ux-pro-max-skill-banner-design/), [brand](skills/nextlevelbuilder-ui-ux-pro-max-skill-brand/), [design-system](skills/nextlevelbuilder-ui-ux-pro-max-skill-design-system/), [ui-ux-pro-max](skills/nextlevelbuilder-ui-ux-pro-max-skill-ui-ux-pro-max/) … |
| Office | 2 | [disk-space-audit](skills/disk-space-audit/), [summarize-meeting](skills/phuryn-pm-skills-pm-execution-summarize-meeting/) |
| Planning | 3 | [planning-with-files](skills/planning-with-files/), [criteria-audit](skills/criteria-audit/), [strategy-red-team](skills/phuryn-pm-skills-pm-execution-strategy-red-team/) |
| Research | 9 | [gpt-researcher](skills/gpt-researcher/), [competitor-analysis](skills/phuryn-pm-skills-pm-market-research-competitor-analysis/), [market-sizing](skills/phuryn-pm-skills-pm-market-research-market-sizing/), [user-personas](skills/phuryn-pm-skills-pm-market-research-user-personas/), [customer-journey-map](skills/phuryn-pm-skills-pm-market-research-customer-journey-map/), [cohort-analysis](skills/phuryn-pm-skills-pm-data-analytics-cohort-analysis/) … |
| Writing | 2 | [stop-slop](skills/stop-slop/), [grammar-check](skills/phuryn-pm-skills-pm-toolkit-grammar-check/) |

## Install

```bash
# Claude Code / any agent that scans ~/.claude/skills
git clone https://github.com/<you>/agent-skills.git
cp -r agent-skills/skills/* ~/.claude/skills/
```

Each folder contains `SKILL.md` (the instructions), `README.md`, and `LICENSE`.

## Licensing

- **This repository's own files** (README, README.zh.md, catalog.json, NOTICE.md): **MIT**.
- **Each skill keeps its upstream license** — see [NOTICE.md](NOTICE.md) for the source repo and license of every package.
- This is a mirror for discoverability; upstream is always the source of truth.

## Updates

The site is the source of truth. This repository is regenerated from the same manifest, so a package here matches the zip on the site byte-for-byte.
