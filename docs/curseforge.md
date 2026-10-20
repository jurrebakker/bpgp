# CurseForge

Since 2026-10-20 every `v*` tag is also uploaded to CurseForge (decision in [release-plan-v1.md §10](release-plan-v1.md#10-releasing)). This page has the one-time setup and the texts for the project page.

## How it works

- `.github/workflows/release.yml` runs on a `v*` tag. Job `package` builds `BPGP-<tag>.zip` and creates the GitHub Release (BPGP Updater installs from there). Job `curseforge` runs after it and uploads the same build to CurseForge.
- The project ID (1754670) is in `BPGP/BPGP.toc` as `## X-Curse-Project-ID`. The upload token is the repository secret `CF_API_TOKEN`; while it's missing, the `curseforge` job skips the upload with a notice. Either way the GitHub Release is already done.
- Release type comes from the tag: `v1.0.7-alpha1` → Alpha, `v1.0.7-beta1` → Beta, `v1.0.7` → Release.
- Game version comes from `## Interface:` in `BPGP/BPGP.toc` (now 12.1.0 and 12.1.5). If CurseForge doesn't know a version yet, the packager picks the closest one.
- The changelog shown on CurseForge is `CHANGELOG.md` (`manual-changelog` in `.pkgmeta`).
- Every file is moderated by CurseForge before it's public: from a few minutes to a few working days. The first upload also triggers the review of the project itself.
- Re-running an old release run doesn't help: it uses the workflow of that tag, which had no CurseForge job. The first upload happens on the first tag after this change was merged.

## One-time setup (done by Jurre)

1. Sign in at <https://authors.curseforge.com/> (Google, Discord, GitHub or Twitch) and accept the author terms.
2. **Create Project** → World of Warcraft → Addons, with the texts below and logo `assets/Icons/bpgp-400.png`.
3. Copy the numeric **Project ID** from the "About Project" box into `BPGP/BPGP.toc` (`## X-Curse-Project-ID: 1754670`, done).
4. Create an upload token at <https://authors.curseforge.com/#/settings/api-tokens> (not the "Core API" key from console.curseforge.com).
5. In GitHub, `jurrebakker/bpgp` → **Settings → Secrets and variables → Actions** → tab **Secrets** → *New repository secret*: name `CF_API_TOKEN`, value the token. Never put the token in the repository.
6. Push the next tag. Check the run under **Actions** (both jobs green) and the file under the project's **Files** tab.

## Project page

| Field | Value |
|---|---|
| Name | BPGP (fallback if taken: "BPGP - Boomer Points EPGP") |
| Summary | Lightweight EPGP loot system for our guild, with officer sync and open tier bidding. |
| Main category | Guild |
| Extra category | Auction & Economy |
| License | Apache License version 2.0 |
| Source | <https://github.com/jurrebakker/bpgp> |
| Issues | <https://github.com/jurrebakker/bpgp/issues> |
| Logo | `assets/Icons/bpgp-400.png` (400×400 PNG, redrawn from the in-game icon) |

### Description

CurseForge doesn't allow donation links or external download links in the description, and a fork has to credit the original with its own text. Paste this:

```markdown
**BPGP** is the EPGP loot system of our guild, for World of Warcraft retail (Midnight). The points are called Boomer Points (BP) and gear points (GP); your priority is PR = BP / GP, and the highest PR wins.

## Features
- **One roster** of guild members with BP, GP and PR standings.
- **Raids** with an on-time BP bonus for everyone in the raid.
- **Open auctions** with named tier buttons (each tier its own GP), plus OS, Transmog (free, highest roll wins), Pass and Cancel. The winner is selected by tier, then PR, then roll.
- **Decay** of BP and GP.
- **Automatic sync** of all data between guild members. Only officers (guild ranks with "Is Officer") can change anything, and that is checked on every client.
- **Pass on loot**: in your guild's own raids you automatically pass on boss loot, so the officer running the auctions can loot everything.
- **Test mode** (`/bpgp test`) with a separate ledger, a simulated raid group and simulated bidders.
- Native Blizzard-style windows. Can be installed next to Core Loot Manager; they don't share data or channels.

## Getting started
- Open the main window with the minimap icon or `/bpgp gui`.
- Officers: click **Set up BPGP** in the Standings tab once, then add guild members in the Roster tab or paste standings with **Import standings**.
- Raiders: bid with the bidding window that opens when an auction starts (or `/bpgp bid`).

## Credits
BPGP is a fork of [Core Loot Manager](https://github.com/CoreLootManager/CoreLootManager) v5.7.8 by Lantis and the Core Loot Manager contributors, licensed under the Apache License 2.0. It is stripped down to EPGP only and heavily modified for our guild.
```
