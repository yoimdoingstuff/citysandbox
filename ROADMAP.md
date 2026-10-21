# Civiterra Roadmap

Civiterra is a native 3D god-sandbox prototype built with Godot 4. The target is a mix of **WorldBox-style god powers**, **Deisim-like world interaction**, and **Cities: Skylines-inspired settlement growth**, with direct control over selected cities and wars between them.

This roadmap is the source of truth for upcoming work. Tasks are deliberately small enough to verify instead of declaring an entire feature "done" because it compiled once.

## Status key

- [x] Implemented and confirmed in the current prototype.
- [ ] Planned or still needs implementation/verification.

A successful GitHub Actions build means the project validates and exports. It does **not** by itself prove that a feature looks or behaves correctly in a real desktop session.

## Current prototype

- [x] Procedurally generated 3D island, hills, shoreline colours, and water plane.
- [x] Terrain sculpting with raise/lower tools and a draggable brush.
- [x] Terrain face-winding adjustment to make the top surface visible; the latest version has been reviewed in-game.
- [x] Spawn humans, trees, stone, and food; erase placed items.
- [x] People wander and can join or found settlements.
- [x] Cities gain population, collect nearby resources, and add houses as they grow.
- [x] Select a city and take control of it.
- [x] Existing god powers: lightning, wildfire, meteor, tornado, plague, heal/bless, forest creation, and earthquake.
- [x] Existing strategic actions: missile strikes, invasions, armies, city capture, and AI wars.
- [x] Camera orbit, pan, zoom, pause, and simulation-speed controls.
- [x] GitHub Actions checks the Godot project and exports Windows and Linux builds.

## Roadmap

### Phase 1: Make the world dependable

**Priority: next**

- [ ] Manually test the latest Windows build from a normal desktop session: terrain visibility, camera controls, sculpting, selecting cities, and each god power.
- [ ] Check terrain sculpting at coastlines, steep slopes, and the edge of the heightmap; fix gaps, spikes, or unexpected brush behaviour.
- [ ] Audit mouse interactions so camera movement, world selection, and drag-to-paint tools do not interfere with each other.
- [ ] Verify the terrain lighting and normals from high and low camera angles, and check that water and shoreline colours remain sensible after sculpting.
- [ ] Improve error reporting in GitHub Actions without hiding real script, startup, or export errors.
- [ ] Add a short repeatable playtest checklist so fixes can be checked after future changes.

**Done when:** a fresh desktop build starts reliably, the island is visible from above, core inputs behave predictably, and the basic tools can be used without obvious rendering or startup errors.

### Phase 2: Improve terrain and world-building tools

- [ ] Replace or supplement flat vertex-colour bands with a better terrain material: grass, dirt, rock, and sand that transition more naturally.
- [ ] Add a smoothing tool so players can soften sharp terrain edits.
- [ ] Make brush size and strength adjustable in the UI, with a clear preview of the affected area.
- [ ] Keep spawned objects aligned to the actual terrain surface, including after the ground is edited.
- [ ] Add a simple tree/rock placement preview and clearer feedback when a placement is invalid.
- [ ] Explore rivers, lakes, and improved coastlines once the existing terrain tools are solid.

**Done when:** shaping the island is predictable, its materials read clearly, and players can place or edit the world without objects visibly floating or sinking.

### Phase 3: Build a more convincing living population

- [ ] Give people readable states such as idle, travelling, gathering, building, fleeing, and fighting.
- [ ] Add basic needs and resource consumption, starting with food and population survival.
- [ ] Give citizens simple jobs and make those jobs affect resource collection and settlement growth.
- [ ] Improve movement around water, buildings, other people, and uneven terrain.
- [ ] Add clearer visual identities for people and feedback for selection or important events.
- [ ] Make population growth, migration, and settlement founding understandable through visible UI information.

**Done when:** people do more than wander, and the player can see why a settlement is growing, stagnating, or struggling.

### Phase 4: Turn settlements into cities

- [ ] Introduce roads or paths that link homes, resource areas, and town centres.
- [ ] Add simple building categories, such as homes, farms, storage, and production.
- [ ] Use available land, nearby resources, and access to paths when deciding where cities expand.
- [ ] Make resource production, storage, and consumption visible in city information.
- [ ] Add settlement boundaries or another clear way to show each city's area of influence.
- [ ] Improve city selection and management UI so population, resources, buildings, and status are easy to inspect.

**Done when:** cities have a visible layout and a basic economy, rather than just accumulating people and houses.

### Phase 5: Make city control, diplomacy, and war strategic

- [ ] Make city relationships visible: allied, neutral, hostile, and at war.
- [ ] Add basic diplomacy actions and a clear way to start or end a war.
- [ ] Improve army composition, movement, target selection, and combat feedback.
- [ ] Add meaningful city defences and make attacks depend on forces and city strength.
- [ ] Show attack warnings and the outcome of invasions or missile strikes in the event log.
- [ ] Make AI wars less arbitrary by considering city strength, distance, and existing conflicts.

**Done when:** conflicts have understandable causes and outcomes, and taking control of a city gives the player useful decisions beyond launching attacks.

### Phase 6: Add saving, loading, and settings

- [ ] Save and restore the terrain edits, resources, people, cities, armies, and ongoing simulation state.
- [ ] Add multiple save slots and a clear indication of which save is being loaded or overwritten.
- [ ] Add settings for simulation speed, camera sensitivity, visual effects, and audio when audio exists.
- [ ] Handle invalid or older save files safely, with an error message instead of a broken world.

**Done when:** a player can build a world, close the game, and continue that same world later.

### Phase 7: Polish the god powers and presentation

- [ ] Give every power a distinct icon, cursor/preview, effect, and concise explanation.
- [ ] Make power strength and area of effect visible before casting.
- [ ] Improve effect timing and feedback for lightning, fire, meteors, tornadoes, plague, healing, forests, and earthquakes.
- [ ] Add better water, sky, lighting, shadows, and environmental ambience without sacrificing performance.
- [ ] Improve menus, tooltips, onboarding hints, and accessibility of important controls.
- [ ] Add optional sound effects and ambient audio.

**Done when:** powers feel distinct and satisfying to use, and a new player can discover the controls without guessing.

### Phase 8: Performance, reliability, and release readiness

- [ ] Profile large populations, many cities, repeated god powers, and frequent terrain edits.
- [ ] Reduce unnecessary per-frame work and avoid rebuilding expensive world data when it has not changed.
- [ ] Add stress-test scenarios and keep them alongside the existing Godot validation and export workflow.
- [ ] Verify Windows and Linux builds from clean downloads on supported machines.
- [ ] Document known limitations, controls, build downloads, and troubleshooting in the README.
- [ ] Create a versioned playable milestone once the core sandbox loop is stable.

**Done when:** the game can handle a reasonably busy world, builds are reproducible, and limitations are documented honestly.

## Suggested implementation order

1. **Phase 1: reliability and real desktop playtesting.** Catch visible problems before layering more systems on top.
2. **Phase 2: terrain and building tools.** Make editing the world feel good.
3. **Phase 3: population simulation.** Give citizens readable behaviour and needs.
4. **Phase 4: city systems.** Connect people, resources, buildings, and roads.
5. **Phase 5: strategic conflict.** Build on cities that already have meaningful strengths and weaknesses.
6. **Phase 6: save/load.** Protect the worlds players create.
7. **Phases 7–8: presentation, optimisation, and release polish.** Iterate throughout, but reserve a dedicated pass for them.

## Working rules

- Keep tasks unchecked until their behaviour is implemented and verified.
- Prefer complete, testable slices over adding several half-working systems at once.
- Run the automated Godot validation and export workflow after meaningful changes.
- Treat a clean CI run as a build check, not as proof of visual correctness.
- Update this roadmap in the same commit when work materially changes a task's status or priority.
