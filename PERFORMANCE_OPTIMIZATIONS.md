# Additional Performance Optimizations

This pass adds CPU and allocation optimizations beyond the existing LOD, frustum/occlusion culling, chunked terrain meshes, and visual limits.

## Implemented techniques

1. **Spatial hashing for local queries.** Citizens, resources, and rubble are bucketed into 16-world-unit X/Z cells. Resource collection, fire/tornado damage, missile impacts, and nearby rubble selection query only intersecting cells, then retain exact radius checks. The indexes are invalidated when their underlying positions or arrays change.
2. **Deferred citizen-array compaction.** Area damage and missile impacts mark victims dead and queue their visuals for deletion instead of repeatedly calling `Array.remove_at` inside the same scan. The dead entries are compacted once after the effect/plague phase, keeping nearby-query indexes stable while multiple effects resolve.
3. **Reusable transient effects.** God-power pulse/lightning visuals reuse mesh/material/light nodes, and building-collapse smoke puffs reuse their mesh/material nodes. Pools are bounded, so an unusually large event cannot grow them without limit.
4. **Terrain-edit broad phase.** Terrain relocation calculates one padded union bounding rectangle for a batch of sculpt/crater edits. Entities outside the rectangle skip per-edit circle checks; entities inside still go through the original exact edit test and height update.
5. **Squared-distance comparisons.** Hot citizen movement/activity checks, nearest-car selection, stuck recovery, city assignment, and wildfire spread use squared distances where they only need thresholds. This avoids unnecessary square roots without changing the thresholds.
6. **Adaptive frame-time workload governor.** A smoothed frame-time estimate raises performance pressure when the game is overloaded. It gradually reduces decorative citizen update batches and spreads UI, crowd-proxy, and detail refreshes over a longer interval, then recovers smoothly when frame times improve.

## Validation

The repository's existing Runtime stress tests remain the validation path. Compare the run's frame-interval percentiles, maximum action/process times, and scenario results across dense-crowd, terrain-edit, disaster, mass-collapse, and combined-load scenarios. This document does not claim an FPS percentage before those measurements finish.
