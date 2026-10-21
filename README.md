# Civiterra: God Sandbox

Civiterra is an early native 3D god-game prototype built with **Godot 4**. It combines the terrain and god-tool sandbox of *WorldBox* and *Deisim*, autonomous town growth inspired by *Cities: Skylines*, and city-state warfare.

This is a prototype, not a finished commercial-scale game. It uses procedural geometry and built-in materials; it has no paid assets, browser runtime, Electron, or WebView dependency.

## Download a build

Open the repository's **Actions** tab and download the latest `Civiterra-desktop-builds` artifact from a successful **Build desktop game** run. The artifact includes a Windows x86-64 executable and a Linux x86-64 build. GitHub Actions produces these from the source whenever code is pushed to `main` and can also be run manually.

## Run from source

1. Install Godot 4.3 or newer.
2. Import `project.godot` in the Godot Project Manager.
3. Press **F6** to run the main scene or **F5** to run the project.

The project uses Godot's Compatibility renderer to support a broad range of desktop hardware.

## Current features

- Procedurally generated 3D island, water, hills, and terrain height map.
- Raise/lower terrain brush with adjustable radius.
- Spawn humans, trees/wood, stone deposits, and food patches.
- Humans wander, join nearby settlements, and can spontaneously found towns when enough gather.
- Cities collect nearby resources, grow their populations, and build additional houses.
- Select any city and take control of it.
- Order missile strikes and invasions against rival cities.
- Visible missile projectiles and blast effects, casualties, and building damage.
- Armies travel across the island; cities defend themselves, lose citizens, and can be captured.
- AI city-states can start wars on their own.
- Pause and simulation speed controls.
- Native 3D view with desktop UI.

## Controls

- **WASD / arrow keys:** move the camera
- **Right mouse drag:** rotate the camera
- **Middle mouse drag:** pan
- **Mouse wheel:** zoom
- Choose a world tool, then click the island.
- Click a city, choose **Control Selected City**, then choose **Launch Missile** or **Order Invasion** and click a target city.

## Project status

This is an active prototype with simple procedural art and lightweight simulation rules. The main next steps are deeper citizen jobs, roads and zoning, save/load, more detailed combat, and continued balancing and bug fixing. Automated exports are not a guarantee that all gameplay behaviour is bug-free; check the Actions logs for validation and build results.
