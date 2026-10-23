# Additional Performance Optimizations

This pass adds CPU and allocation optimizations beyond the existing LOD, frustum/occlusion culling, chunked terrain meshes, and visual limits.

## Implemented techniques

1. **Spatial hashing for local queries.** Citizens, resources, and rubble are bucketed into 16-world-unit X/Z cells. Resource collection, fire/tornado area damage, missile impacts, wildfire tree spread, and nearby rubble selection query intersecting cells first, then keep the original exact radius checks. Indexes are invalidated when indexed positions, the relevant arrays, or the world change.
2. **Deferred citizen-array compaction.** Area damage and missile impacts mark victims dead and queue their visuals for deletion instead of repeatedly shifting the people array. Dead entries are compacted in one pass after the effect/plague phase, so multiple effects can safely share the same spatial index.
3. **Reusable transient effects.** God-power pulse/lightning visuals reuse mesh/material/light nodes, and building-collapse smoke puffs reuse their mesh/material nodes. Pools are bounded to prevent unlimited growth.
4. **Terrain-edit broad phase.** Terrain relocation calculates one padded union bounding rectangle for a batch of sculpt/crater edits. Entities outside it skip per-edit circle checks; entities inside still pass the original exact test and height update.
5. **Squared-distance comparisons.** Hot citizen movement/activity checks, nearest-car selection, stuck recovery, city assignment, wildfire spread and local damage checks use squared distances where they only need thresholds. This avoids unnecessary square roots without changing those thresholds.
6. **Adaptive frame-time workload governor.** A smoothed frame-time estimate raises performance pressure when frames are slow. It gradually increases citizen update batching and spreads UI, crowd-proxy and visual-detail refreshes over longer intervals, then recovers gradually as frame times improve.

## Stability fixes found while stress-testing

- Check validity before casting scene objects, and discard dead traffic-light and construction-site references instead of repeatedly throwing errors.
- Add smoke nodes to the scene tree before accessing their global transforms.
- Tint conquered city buildings through duplicated mesh materials instead of assigning the unsupported `modulate` property to a `Node3D`.

## Validation notes

The repository's Runtime stress-test workflow launches the rendered Godot 4.3 game and exercises 19 scenarios, including crowded cities, disasters, mass collapses, terrain edits, settlement growth, save/load and combined-load testing. The latest available recorded run completed the suite but exposed stale-object errors; fixes have since been committed, and a new run is needed to confirm the fixes are clean. Existing FPS samples came from different virtual CPUs/rendering environments, so they are not an apples-to-apples speed comparison. Do not infer a percentage FPS gain until a comparable baseline and optimized run are available.
