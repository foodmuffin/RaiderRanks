# AGENTS.md

## Product Contract
- RaiderRanks is a retail Midnight addon for WoW `12.0.x`.
- V1 ranks guild members and friends by current-season RaiderIO Mythic+ score only.
- Raid progress, role, spec, and item level are support signals for display and filtering.
- Player-facing options belong in the native WoW Settings AddOns menu.

## Architecture
- `RaiderRanks.lua` owns the namespace, events, shared helpers, secret-value-safe name resolution, and callback bus.
- `Modules/Config.lua` owns defaults and SavedVariables access.
- `Modules/Comm.lua` owns the guild-only addon channel, payload/version handling, debounced sends, shared snapshot persistence, transient live-run state, session reporter tracking, and newer-RaiderIO manifest detection.
- `Modules/Data.lua` owns roster normalization, RaiderIO reads, shared snapshot overlay, unified reported-key resolution, sorting, and current-key qualification.
- `Modules/Inspect.lua` owns best-effort self/inspect enrichment for spec and item level.
- `UI/Panel.lua` owns the integrated Group Finder / Mythic+ tab shell, the final live layout for both the left list and right detail pane, slash commands, addon compartment, and inline overlays.
- `UI/DetailPanel.lua` owns the right-hand detail pane creation, interior layout, background styling, hero row, and record rendering.
- `UI/Settings.lua` owns the native Settings category and setting widgets.
- `Localization/` owns all addon-authored strings.

## Tainting Rules
- WoW `12.0.x` secret values can taint roster and unit strings on insecure execution paths.
- Do not boolean-test, compare, sort, trim, or use raw roster strings as table keys when they come from APIs such as `GetGuildRosterInfo`, `UnitFullName`, `C_FriendList.GetFriendInfoByIndex`, or Battle.net game-account fields.
- Prefer GUID-first normalization for player identity. Use `ns:GetNameRealmFromGUID`, `ns:GetUnitNameRealm`, and `ns:IsSecretValue` rather than hand-rolling name parsing in roster code.
- `GetPlayerInfoByGUID(guid)` returns `localizedClass, englishClass, localizedRace, englishRace, sex, name, realmName`.
- If Blizzard only provides a secret fallback string, skip indexing that record rather than risking taint errors or cross-realm misidentification.
- Safe normalized full names may still be used for record keys, caches, selection state, and comm lookups after they have been resolved through the shared helpers.

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
- Source precedence for spec and item level is `self > inspect > shared guild-sync snapshot > unknown`.
- Role may use live group context first, then newer inspect/shared data, then RaiderIO-derived fallback, then `unknown`.
- `record.reportedKey` is a unified field composed from native guild-sync key data plus AstralKeys. Prefer the newer native key, fall back to AstralKeys, and merge AstralKeys extras when both sources agree on map and level.
- Current-key qualification and the dungeon matrix stay local-only even when shared data is available.

## Network Rules
- The addon comm channel is guild-only and runs through `Modules/Comm.lua`.
- The master gate is `enableGuildSyncChannel`; when it is off, there must be no network sends, no inbound processing, and no rendering based on network-derived data.
- `showNewerRaiderIOWarning` and `showLiveKeyActivity` are subordinate UI toggles and should only matter when the master gate is enabled.
- Shared profile snapshots may persist in SavedVariables under `commCache.sharedSnapshots`, but they must be ignored while the master gate is off.
- Live run activity is transient session state with TTL, not durable profile data.
- Snapshot payloads currently carry score summary fields, spec, role, item level, RaiderIO manifest timestamps, and optional native owned-key data.
- Snapshot refreshes are intentionally triggered on world/login readiness, group join/leave transitions, instance leave, challenge-mode state changes, and owned-key changes such as `BAG_UPDATE_DELAYED`.
- The session reporter count is runtime-only, excludes the local player, and is driven by unique remote snapshot senders seen this login session.

## UI Rules
- Keep the addon visually close to Blizzard UI conventions and favor real integration points over standalone windows.
- Prefer Blizzard templates, atlas icons, font objects, and global strings.
- Reuse RaiderIO tooltips instead of recreating their profile tooltip content.
- If changing a panel control or filter, update both panel refresh logic and the saved-variable default if it is persisted.
- Keep `UI/Panel.lua` and `UI/DetailPanel.lua` loosely coupled through module calls so they can be edited independently without merge-heavy conflicts.
- Preserve Blizzard-native tab sizing and behavior in the integrated PVE frame; do not add custom tab sizing unless there is a strong regression fix that cannot be achieved natively.
- `UI/Panel.lua:ApplyLayout()` is the source of truth for final list/detail frame anchors. Create-time anchors in `UI/DetailPanel.lua` are only defaults and may be overwritten during layout refresh.
- The left roster pane and right detail pane should keep matching outer insets where possible so the two inset frames read as a single integrated shell.
- The newer-RaiderIO indicator is header-only, not a per-row warning.
- Live key activity should surface as a row marker plus a detail-panel section, but should still read as Blizzard UI rather than a custom dashboard.
- The detail hero row uses two side-by-side cards at the same height. The outer hero wrapper should stay visually quiet so the inner cards do the work.

## Localization Rules
- Every addon-authored user-visible string goes through `ns.L`.
- `Localization/enUS.lua` is the source of truth.
- Prefer Blizzard globals like `GUILD`, `FRIENDS`, `NAME`, `ROLE`, and `SPECIALIZATION` when they fit cleanly.
- Do not concatenate sentence fragments when a full format string is more stable.

## Maintenance Checklist
- New player-facing behavior needs a native Settings entry if users may reasonably want to toggle it.
- New enrichment paths must define source precedence and an unknown-state UI.
- If you add strings, update localization in the same change.
- If you change guild-sync behavior, sanity-check the master gate, dependent settings, session reporter count, live activity markers, and newer-RaiderIO warning state together.
- If you change key handling, verify both native guild-sync keys and AstralKeys still compose into the single `record.reportedKey` surface.
- If you touch guild, friends, inspect, or group-roster identity code, verify the path stays secret-value-safe and still resolves name/realm through GUIDs before indexing or comparing.
- If you change integrated frame sizing or insets, verify the runtime layout in `UI/Panel.lua`, not just the create-time anchors, and confirm both left and right panes still align.
- Sanity-check guild roster, friends roster, the integrated PVE tab, settings, slash commands, and the current-key helper before calling the addon change complete.
