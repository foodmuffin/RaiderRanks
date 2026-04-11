# AGENTS.md

## Product Contract
- RaiderRanks is a retail Midnight addon for WoW `12.0.x`.
- V1 ranks guild members and friends by current-season RaiderIO Mythic+ score only.
- Raid progress, role, spec, and item level are support signals for display and filtering.
- Player-facing options belong in the native WoW Settings AddOns menu.

## Architecture
- `RaiderRanks.lua` owns the namespace, events, shared helpers, and callback bus.
- `Modules/Config.lua` owns defaults and SavedVariables access.
- `Modules/Data.lua` owns roster normalization, RaiderIO reads, sorting, and current-key qualification.
- `Modules/Inspect.lua` owns best-effort self/inspect enrichment for spec and item level.
- `UI/Panel.lua` owns the integrated Group Finder / Mythic+ tab, helper card, detail view, slash commands, addon compartment, and inline overlays.
- `UI/Settings.lua` owns the native Settings category and setting widgets.
- `Localization/` owns all addon-authored strings.

## Ranking Rules
- Mythic+ score is the primary ranking metric.
- Tiebreakers are max key level, timed `20+`, timed `15+`, then name.
- Item level, role, spec, and raid progress must not replace Mythic+ as the main ranking basis.

## Enrichment Rules
- Use only RaiderIO public APIs: `GetProfile`, `ShowProfile`, and `GetScoreColor`.
- Treat item level and exact spec as best-effort enrichment.
- Never inspect-spam an entire roster.
- Queue inspect only for visible rows, selected records, or other immediately relevant inspectable units.
- `Unknown` is a valid display state for spec and item level.

## UI Rules
- Keep the addon visually close to Blizzard UI conventions and favor real integration points over standalone windows.
- Prefer Blizzard templates, atlas icons, font objects, and global strings.
- Reuse RaiderIO tooltips instead of recreating their profile tooltip content.
- If changing a panel control or filter, update both panel refresh logic and the saved-variable default if it is persisted.

## Localization Rules
- Every addon-authored user-visible string goes through `ns.L`.
- `Localization/enUS.lua` is the source of truth.
- Prefer Blizzard globals like `GUILD`, `FRIENDS`, `NAME`, `ROLE`, and `SPECIALIZATION` when they fit cleanly.
- Do not concatenate sentence fragments when a full format string is more stable.

## Maintenance Checklist
- New player-facing behavior needs a native Settings entry if users may reasonably want to toggle it.
- New enrichment paths must define source precedence and an unknown-state UI.
- If you add strings, update localization in the same change.
- Sanity-check guild roster, friends roster, the integrated PVE tab, settings, slash commands, and the current-key helper before calling the addon change complete.
