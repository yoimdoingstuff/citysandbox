# Civiterra: God Sandbox

Civiterra is an early native 3D god-game prototype built with **Godot 4**. It combines the terrain and god-tool sandbox of *WorldBox* and *Deisim*, autonomous town growth inspired by *Cities: Skylines*, and city-state warfare.

This is a prototype, not a finished commercial-scale game. It uses procedural geometry and built-in materials; it has no paid assets, browser runtime, Electron, or WebView dependency.

## Download a build

Open the repository's **Actions** tab and download the latest `Civiterra-desktop-builds` artifact from a successful **Build desktop game** run. The artifact includes a Windows x86-64 executable and a Linux x86-64 build. GitHub Actions produces these from the source whenever code is pushed to `main` and can also be run manually.

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
- Cities progress through visible village, town, city, and metropolis stages as population grows; central landmarks and neighbourhoods expand with development.
- Select any city and take control of it.
- Order missile strikes and invasions against rival cities.
- Armies march, fight, capture cities, and trigger AI wars.
- Pause and simulation speed controls.
- Native 3D desktop UI and automatic Windows/Linux builds through GitHub Actions.

## Controls

- **WASD / arrows:** move the camera
- **Right mouse drag:** orbit the camera
- **Middle mouse drag:** pan by grabbing the world
- **Mouse wheel:** zoom
- Select a world tool, then click or drag over the island.
- Choose **Lightning**, **Fire**, **Meteor**, **Tornado**, **Plague**, **Heal / Bless**, **Create Forest**, or **Earthquake**, then click the world to cast it. Blessing cures plague; tornadoes and wildfires move/spread and damage nearby populations.
- Click a city, choose **Control Selected City**, then choose **Launch Missile** or **Order Invasion** and click a target city.

## Project status

This is an active prototype with simple procedural art and lightweight simulation rules. The next steps are deeper citizen jobs, roads and zoning, save/load, more detailed combat, and continued visual/gameplay polish. Automated exports confirm that Godot can validate and export the project, but in-game behaviour still needs normal playtesting.
