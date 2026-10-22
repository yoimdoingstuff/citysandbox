# Civiterra: God Sandbox

Civiterra is an early native 3D god-game prototype built with **Godot 4**. It combines the terrain and god-tool sandbox of *WorldBox* and *Deisim*, autonomous town growth inspired by *Cities: Skylines*, and city-state warfare.

This is a prototype, not a finished commercial-scale game. It uses procedural geometry and built-in materials; it has no paid assets, browser runtime, Electron, or WebView dependency.

## Download a build

**Direct Windows download:** [Civiterra.exe](https://github.com/yoimdoingstuff/citysandbox/releases/download/civiterra-latest/Civiterra.exe)

**Direct Linux download:** [Civiterra.x86_64](https://github.com/yoimdoingstuff/citysandbox/releases/download/civiterra-latest/Civiterra.x86_64)

**Checksums:** [SHA256SUMS.txt](https://github.com/yoimdoingstuff/citysandbox/releases/download/civiterra-latest/SHA256SUMS.txt) · [All release assets](https://github.com/yoimdoingstuff/citysandbox/releases/tag/civiterra-latest)

GitHub Actions updates these direct-download assets after validation, save/load tests, and successful Windows/Linux exports. The usual Actions artifact is still available for diagnostics, but downloading that artifact causes GitHub to wrap the files in a ZIP.

The Windows build is currently unsigned. Direct downloads avoid the Actions ZIP wrapper, but they cannot force Google Chrome Safe Browsing or Windows SmartScreen to trust a new executable. Those reputation warnings may persist until the app has established reputation or is signed with a trusted code-signing certificate. Compare the downloaded file's SHA-256 hash against `SHA256SUMS.txt` if you need to verify its integrity.

## Roadmap

- **[Simple roadmap](ROADMAP_SIMPLE.md):** the big-picture vision for larger continents, cities that evolve over time, zoom-dependent detail, and a modern UI.
- **[Detailed roadmap](ROADMAP.md):** the longer implementation checklist, prototype status, and development milestones.

## Run from source

1. Install Godot 4.3 or newer.
2. Import `project.godot` in the Godot Project Manager.
3. Press **F6** to run the main scene or **F5** to run the project.

## Current features

- Seeded procedural 3D world generation with several continent-scale landmasses, smaller islands, irregular coastlines, hills, and a surrounding ocean.
- Four terrain mesh detail levels, with lower-triangle terrain generated when zoomed out and rebuilt lazily after terrain edits.
- Zoom-dependent visibility for city structures, neighbourhoods, resources, and citizens, with lightweight city markers at world scale.
- Height-aware terrain sculpting; raise and lower tools follow the actual 3D surface and can be painted by dragging.
- Spawn humans, plant trees, place stone and food resources, and erase nearby items.
- WorldBox-style powers: lightning, spreading wildfires, falling meteors with craters, moving tornadoes, spreading plague, healing/blessing, forest creation, and earthquakes.
- Brush-radius preview follows the real terrain surface; terrain/resource tools can be painted by dragging.
- Humans wander, join nearby settlements, and can spontaneously found towns when enough gather.
- Cities progress through visible village, town, city, metropolis, and megacity stages as population grows; larger stages add more homes and expand the central landmark.
- City neighbourhoods mix homes, apartments, workshops, civic/commercial buildings, era-specific facades, multi-sided windows, and streetscape details. When eras advance, old buildings are gradually scaffolded and refurbished instead of the whole city instantly changing architectural style.
- Modern city plans evolve from historic grids into a North American/Australian-style mix of grid streets, city-specific diagonal avenues, wider arterial roads, occasional roundabouts, and terrain-following connectors. Some cities keep a straighter grid; others get offset diagonal routes.
- Larger multi-lot sites become more common through the industrial, modern, and contemporary eras. These can turn into larger commercial buildings, office blocks, apartment buildings, and more prominent towers, while the older building stock remains visible between redevelopments.
- Cities have a larger 256-unit world with multiple broad landmasses, leaving more room for grids, neighbourhoods, and city expansion.
- Grid roads now have separate sidewalk meshes; pedestrians route along sidewalk strips, enter houses and disappear indoors for a while, and sometimes board moving cars. Only nearby citizens render as detailed characters.
- Farms provide food, workshops convert a little wood into wealth, apartments and commercial buildings contribute to prosperity, and commercial buildings gradually improve city security.
- City construction spends treasury funds and timber/stone; later industrial and high-rise buildings also need metal supplies, so low funds or scarce stockpiles delay expansion instead of allowing unlimited free buildings.
- World deposits include iron ore, copper ore, coal, and gold alongside food, trees, and stone. Industrial mine/metalworks buildings supply iron and coal.
- City-states buy and sell surplus food, timber, stone, iron, copper, coal, and gold. Trade improves relations, while hostile relations and active wars embargo trade immediately.
- Cities introduce coal-fired electricity infrastructure after 1880 and telecommunications/internet exchanges after 2000. Power depends on coal and upkeep; internet requires electrical service, copper, and operating funds.
- Selected-city status now shows treasury, resource inventories, electricity/internet service levels, diplomatic relations, and active trade/war status.
- New buildings search for open land and avoid obvious overlaps, so coastal towns expand along the available terrain instead of placing houses in the sea.
- Initial condition-driven city events include protests, strikes, rebellions, bank robberies, rare extremist incidents, and positive festivals, influenced by stability, security, food, and wealth.
- City incidents display temporary floating alerts above the affected settlement as well as entries in the world chronicle.
- City roads use a grid with era-dependent diagonal connectors, wide boulevards, traffic lights, and terrain-following surfaces. Roads and sidewalks rebuild when the city enters a new era or the terrain detail changes.
- Each city has a coloured territory zone that expands as it builds more houses, with shared boundaries calculated when city influence zones meet.
- Selecting a city smoothly focuses the camera and automatically zooms out when its territory expands; manual camera input overrides auto-zoom.
- Abandoned cities stop growing new buildings, lose structures gradually to collapse, and eventually become permanent ruins. Ruin states, city buildings, and building/vehicle debris survive save/load.
- Falling buildings use a directional footprint check to identify nearby structures in their fall path. Confirmed impacts send debris into the target building and can trigger bounded collapse chains.
- Construction is paced so one development update cannot instantiate an entire neighbourhood in one frame. Construction workers are referenced directly rather than by mutable citizen-array indexes, and slow operation/frame-hitch samples are written to `user://civiterra-performance.log`.
- Collapsing skyscrapers can knock nearby buildings down in a bounded chain reaction. Falling structures can kill exposed citizens, destroy nearby cars, scatter lasting rubble, and create wrecks.
- Living citizens can walk to rubble and spend time cleaning it up, removing debris from the world instead of leaving every disaster site permanently cluttered.
- Missile strikes can target any point on the playable ground after 1945; hostile armies trigger city defence units that intercept attackers near home.
- A debug-era selector can jump directly to test years from 1200 through 2026.
- Select any city and take control of it.
- Order missile strikes and invasions against rival cities.
- Combined-arms warfare evolves with the era: visible infantry squads, tanks (from 1916), aircraft (from 1945), attack helicopters (from 1970), and modern APCs (from 2000). Each unit type has its own model, speed, attack range, damage, and durability. Armies march toward enemy cities, fight, capture cities, and trigger AI wars.
- Pause and simulation speed controls.
- Native 3D desktop UI with refreshed dark panels, rounded controls, hover states, and clearer world-simulation branding.
- Automatic Windows/Linux validation, main-scene smoke tests, save/load regression tests, and desktop exports through GitHub Actions.
- The [Runtime stress tests workflow](.github/workflows/runtime-diagnostics.yml) launches the rendered Godot game on Windows and runs 15 repeatable scenarios covering 1×/4×/8×/16× simulation speeds, expanded cities and up to 800 citizens, construction/era refurbishment, mass civilian and resource spawning, maximum traffic, camera/LOD transitions, debris fields, fire/plague/tornadoes, meteors/lightning, earthquake terrain edits, mass building collapse, save/load rebuilds, and a combined 16× stress run. It records engine-reported FPS plus wall-clock FPS computed from real time between frame samples, average/p95/p99/maximum frame intervals, maximum processing/action duration, world entity counts, and separate process CPU/memory samples. Each run uploads a 30-day Actions artifact and publishes the latest CSV/performance/summary logs into [`logs/`](logs/).
- Local Save World / Load World controls persist terrain edits, city data, citizens, resources, camera framing, and simulation time; temporary combat and god-power effects are not persisted yet.

## Controls

- **WASD / arrows:** move the camera
- **Right mouse drag:** orbit the camera
- **Middle mouse drag:** pan by grabbing the world
- **Mouse wheel:** zoom
- Select a world tool, then click or drag over the island.
- Choose **Lightning**, **Fire**, **Meteor**, **Tornado**, **Plague**, **Heal / Bless**, **Create Forest**, or **Earthquake**, then click the world to cast it. Blessing cures plague; tornadoes and wildfires move/spread and damage nearby populations.
- Click a city and choose **TAKE CONTROL**. **Order Invasion** targets another city. **Launch Missile** becomes available in 1945 and lets you click any ground point, including a point outside city centres.
- Use **DEBUG ERA** in the top bar to jump to historical years for testing. Citizens sometimes go indoors, board cars, and clean debris; car wrecks can be cleared the same way as building rubble.

## Project status

This is an active prototype with simple procedural art and lightweight simulation rules. The next steps are deeper citizen jobs, roads and zoning, save/load, more detailed combat, and continued visual/gameplay polish. Automated exports confirm that Godot can validate and export the project, but in-game behaviour still needs normal playtesting.
