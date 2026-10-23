# Additional Performance Optimizations

This pass adds CPU and allocation optimizations beyond the existing LOD, frustum/occlusion culling, chunked terrain meshes, and visual limits.

## Implemented techniques

1. **Spatial hashing for local queries.** Citizens, resources, and rubble are bucketed into 16-world-unit X/Z cells. Resource collection, fire/tornado damage, missile impacts, wildfire spread and nearby rubble selection query intersecting cells first, then keep exact radius checks. The indexes are invalidated when the underlying collections or positions change.
2. **Deferred citizen-array compaction.** Area damage and missile impacts mark victims dead and queue their visuals for deletion rather than repeatedly shifting the people array. Dead entries are compacted in one pass after the effect/plague phase.
3. **Reusable transient effects.** God-power pulse/lightning visuals reuse mesh/material/light nodes, and building-collapse smoke puffs reuse their mesh/material nodes. The pools are bounded.
4. **Terrain-edit broad phase.** Terrain relocation calculates one padded union bounding rectangle for a batch of sculpt/crater edits. Entities outside it skip detailed per-edit circle checks.
5. **Squared-distance comparisons.** Hot citizen movement, nearest-car selection, stuck recovery, city assignment and local damage checks avoid square roots when only comparing thresholds.
6. **Adaptive frame-time workload governor.** A smoothed frame-time estimate increases citizen batching and spreads UI, crowd-proxy and visual-detail refreshes across longer intervals when frames are slow.
7. **City-local traffic-light indexing.** Car signal checks search the current city's traffic signals rather than iterating through every signal in every city.
8. **Bounded round-robin infrastructure checks.** Airport/seaport eligibility is rechecked in small city batches, so growing cities can qualify later without scanning/rebuilding every city in one frame.
9. **O(1) construction and rubble lookups.** Construction workers no longer linearly scan every active work site for each AI update, and cleanup crews can resolve/reserve rubble by an ID index. Construction indices are updated as sites are removed; the rubble index is repaired only after a rubble deletion, not during every lookup.

## Transport and timeline fixes

- Airports have a larger, higher-contrast terminal/runway layout and a terrain-following access road that joins the nearest actual street-grid line.
- Airliners have a larger silhouette, blue livery/tail, engines and a higher flight arc; air-transport routes are preferred when at least two airports exist, and aircraft remain eligible when all candidate cities happen to be at war.
- **Maritime services unlock in 1885, exactly 60 years before the 1945 airport milestone.** Seaports, ships and oil rigs are gated to this date; airports and aircraft are gated to 1945. Era-skipping backward removes future facilities/vehicles, and world reloads reset unlock caches.
- The era selector includes 1885 and 1945 so those boundaries can be checked directly.

## Stability fixes found while stress-testing

- Validate scene references before type checks/casts and discard stale traffic-light/construction references.
- Add smoke nodes to the scene tree before reading their global transforms.
- Avoid assigning the unsupported `modulate` property to a `Node3D`; conquered buildings are tinted through mesh materials instead.

## Validation notes

The recorded Godot 4.3 runtime run for commit `8129b654` completed all 19 stress scenarios without any Godot script errors in its log. The later aircraft/timeline changes still need a fresh run against the newest source revision. FPS results have been recorded on different virtual CPUs/rendering environments, so they are not an apples-to-apples speed comparison; do not infer a percentage gain until comparable runs are available.
