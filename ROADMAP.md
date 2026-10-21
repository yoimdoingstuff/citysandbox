# Civiterra Roadmap

Civiterra is a native 3D god-sandbox prototype built with Godot 4. The long-term goal is a living world: continents full of cities that grow over time, conflicts involving infantry and modern vehicles, destruction that changes the landscape, unpredictable city events, and the ability to leave god mode and play as any citizen.

This is the detailed implementation checklist. For the big-picture vision, see [ROADMAP_SIMPLE.md](ROADMAP_SIMPLE.md).

## Status key

- [x] Implemented in the current prototype.
- [ ] Planned or still needs implementation and in-game verification.

A successful GitHub Actions build confirms that Godot can validate and export the project. It does not, by itself, prove that features look or behave correctly in a real desktop session.

## Current prototype

- [x] Procedurally generated 3D island with hills, shoreline colours, and a water plane.
- [x] Terrain raise/lower tools with a draggable brush.
- [x] Terrain triangle winding adjustment for top-side visibility.
- [x] Spawn humans, trees, stone, and food; erase placed items.
- [x] People wander and can join or found settlements.
- [x] Cities gain population, collect nearby resources, and add houses as they grow.
- [x] Select a city and take control of it.
- [x] Existing god powers: lightning, wildfire, meteor, tornado, plague, heal/bless, forest creation, and earthquake.
- [x] Existing strategic actions: missile strikes, invasions, armies, city capture, and AI wars.
- [x] Camera orbit, pan, zoom, pause, and simulation-speed controls.
- [x] GitHub Actions validates the project and exports Windows and Linux builds.

## Phase 1: Make the world dependable

**Priority: first**

- [ ] Test the latest Windows build in a normal desktop session: terrain visibility, camera controls, sculpting, city selection, and each god power.
- [ ] Check terrain sculpting at coastlines, steep slopes, and map edges; fix gaps, spikes, or unexpected brush behaviour.
- [ ] Ensure camera movement, world selection, and drag-to-paint tools do not interfere with each other.
- [ ] Check terrain lighting and normals from high and low camera angles.
- [ ] Improve GitHub Actions error reporting without hiding real script, startup, or export errors.
- [ ] Keep a repeatable playtest checklist for future changes.

**Done when:** a fresh build starts reliably and the fundamental world controls work predictably.

## Phase 2: Build much larger worlds

- [ ] Replace the single-island focus with world generation that can create large landmasses, multiple continents, islands, seas, and coastlines.
- [ ] Add varied biomes such as mountains, plains, forests, deserts, and wetlands; consider rivers and lakes.
- [ ] Make world-generation settings or seeds available so players can create and revisit different worlds.
- [ ] Place resources and settlements based on terrain, climate, water access, and resource availability.
- [ ] Keep terrain sculpting and god powers compatible with larger generated maps.
- [ ] Add a useful world-scale view for understanding continents, cities, borders, and geography.
- [ ] Profile large maps early and avoid making every part of the world equally expensive to render or simulate.

**Done when:** generated worlds have meaningful geographical variety and enough room for many civilizations to grow.

## Phase 3: Make cities visibly develop over time

- [ ] Give settlements clear development stages: village, town, city, and metropolis.
- [ ] Make population, food, resources, safety, location, and elapsed simulation time influence development.
- [ ] Add distinct buildings and neighbourhoods rather than relying on a single repeated house type.
- [ ] Introduce roads or paths linking homes, farms, workplaces, resource sites, and city centres.
- [ ] Add basic building roles such as housing, food production, storage, trade, industry, and public services.
- [ ] Make trade, migration, shortages, disasters, war, and event outcomes change a city's future.
- [ ] Add a city overview showing population, development stage, resources, happiness or stability, buildings, and relationships.
- [ ] Make cities visually and economically distinct based on their environment and history.

**Done when:** running the simulation for a while produces visible, understandable changes to settlements, not only larger population numbers.

## Phase 4: Make zooming reveal more of the world

- [ ] At world scale, show continents, biomes, borders, and city locations clearly.
- [ ] At regional scale, reveal roads, districts, farms, suburbs, and city layouts.
- [ ] At close range, show more individual buildings, citizens, vehicles, and activity.
- [ ] Use smooth transitions between detail levels to avoid obvious popping.
- [ ] Add readable labels and markers at the appropriate zoom level.
- [ ] Adjust rendering and simulation detail based on distance while preserving important world events.
- [ ] Make selecting cities, vehicles, buildings, and people practical at different zoom levels.

**Done when:** zooming in makes the world meaningfully richer, while zooming out keeps large-scale information readable and performance reasonable.

## Phase 5: Expand warfare and add advanced destruction

- [ ] Separate military units into useful roles with health, movement, targeting, and combat behaviour.
- [ ] Add tanks as armoured ground units, with movement suited to roads and terrain.
- [ ] Add aircraft for faster movement and aerial attacks, with understandable targeting and limitations.
- [ ] Add attack helicopters with a distinct battlefield role and vulnerabilities.
- [ ] Make ground and air units interact, with sensible counters, attack ranges, and combat feedback.
- [ ] Add clear orders and UI for moving, defending, attacking, and targeting military forces.
- [ ] Give buildings damage states instead of treating them as simply intact or gone.
- [ ] Make damage affect appearance and function, and allow severe damage to cause fires or collapse.
- [ ] Add structural support so a collapsing building can damage or topple nearby buildings when appropriate.
- [ ] Add debris and impact effects, but use controlled or simplified physics where full rigid-body simulation would be too expensive.
- [ ] Let destruction leave lasting changes in the city and allow rebuilding after the conflict.
- [ ] Add warnings, damage information, and understandable summaries to the event feed.

**Done when:** battles use distinct land and air units, buildings can be damaged and collapse in readable ways, and the world remains playable during large fights.

## Phase 6: Add unpredictable city events

- [ ] Build an event system that can create incidents from the current state of each city and its population.
- [ ] Add protests, strikes, public unrest, rebellions, crime, and bank-robbery events.
- [ ] Include fictional terrorist or insurgent attacks as rare high-impact events, treated as abstract game simulation rather than a detailed real-world procedure.
- [ ] Let event likelihood depend on conditions such as shortages, inequality, public satisfaction, security, war, and recent disasters.
- [ ] Give citizens and city authorities possible responses, with outcomes that affect safety, resources, buildings, trust, and migration.
- [ ] Let the player intervene with god powers, city decisions, or direct citizen control.
- [ ] Add a readable event feed with severity, location, cause where known, and outcome.
- [ ] Avoid endlessly repeating the same incident; vary events and give cities time to recover.

**Done when:** events emerge from what is happening in the simulation, have understandable consequences, and give the player interesting ways to intervene.

## Phase 7: Let the player control any citizen

This is a major later feature. It should extend the god-game rather than replace it.

- [ ] Allow the player to select any living citizen and switch into a close-up third-person control mode.
- [ ] Add reliable character movement, camera control, collision, and interaction with streets, buildings, and other people.
- [ ] Keep the selected person's identity, job, needs, relationships, and location tied to the existing simulation.
- [ ] Add basic interactions such as walking around, visiting places, talking, working, and interacting with objects.
- [ ] Let the player switch back to god mode or choose another citizen without resetting the world.
- [ ] Allow player actions to create in-game consequences, including mischief and chaos, with citizens and authorities reacting through existing simulation systems.
- [ ] Make the rest of the world continue running at a suitable simulation rate while the player controls a person.
- [ ] Add clear controls, a small person-status display, and a way to return to the world overview.
- [ ] Test edge cases such as a controlled citizen being injured, arrested, displaced, or otherwise unable to continue normally.

**Done when:** the player can freely switch between overseeing civilization and personally exploring the world as an ordinary character, with persistent consequences in both modes.

## Phase 8: Add saving, loading, and settings

- [ ] Save and restore terrain edits, world-generation data, resources, people, cities, buildings, military units, and ongoing events.
- [ ] Save the active mode and controlled citizen safely, or return to god mode when a saved character is no longer valid.
- [ ] Add multiple save slots and clear feedback before overwriting a world.
- [ ] Add settings for simulation speed, camera sensitivity, graphics, effects, and audio when audio exists.
- [ ] Handle invalid or older saves gracefully with useful messages.

**Done when:** players can build a world, return later, and continue with their edits and simulation history intact.

## Phase 9: Redesign the UI and presentation

- [ ] Establish a cohesive modern visual design with typography, spacing, colours, icons, and subtle motion.
- [ ] Replace the prototype-style layout with a cleaner toolbar for terrain tools, god powers, and simulation controls.
- [ ] Design polished contextual panels for cities, people, buildings, and military units.
- [ ] Show relevant actions only when they make sense, instead of crowding the screen with every button.
- [ ] Improve menus, settings, tooltips, notifications, and the event feed.
- [ ] Make tool previews, vehicle orders, building damage, selection, and important alerts easy to read.
- [ ] Keep the interface legible across window sizes and common desktop resolutions.
- [ ] Add sound effects and ambience when the core interactions and visual direction are stable.

**Done when:** all parts of the interface feel like one finished game and help the player understand a complex, changing world.

## Phase 10: Performance, reliability, and release readiness

- [ ] Profile large populations, sprawling cities, multiple continents, vehicle battles, cascading collapses, and long-running simulations.
- [ ] Avoid doing expensive per-frame work when data has not changed.
- [ ] Use distance-based detail and simplified simulation for far-away areas where suitable.
- [ ] Add repeatable stress-test scenarios alongside Godot validation and export checks.
- [ ] Verify Windows and Linux builds from clean downloads and test real gameplay, not just successful exports.
- [ ] Document controls, known limitations, troubleshooting, and playable milestones.
- [ ] Create a versioned playable release when the core world, city, warfare, and citizen-control loops are stable.

**Done when:** the game remains responsive in a busy world, builds are reproducible, and known limitations are documented honestly.

## Suggested implementation order

1. Reliability and real desktop playtesting.
2. Larger procedural worlds.
3. City development that visibly changes over time.
4. Zoom-dependent detail and selection.
5. Warfare, vehicle combat, and destruction.
6. City events and reactive populations.
7. Direct citizen control.
8. Save/load, UI polish, optimisation, and release preparation.

These phases are a direction, not a promise that every feature will be cheap. In particular, large world simulation, chain-collapse physics, modern vehicle combat, and controllable citizens are substantial systems. Keep each task unchecked until it is implemented and tested in-game.

## Working rules

- Prefer complete, testable slices over adding several half-working systems at once.
- Run automated Godot validation and export workflows after meaningful changes.
- Treat a green CI run as a build check, not proof of visual correctness.
- Update this roadmap when task status or development priorities materially change.
