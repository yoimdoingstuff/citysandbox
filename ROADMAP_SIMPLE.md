# Civiterra: Simple Roadmap

## The vision

Civiterra should feel like a living world, not a small test island. Leave the simulation running and watch little settlements become towns, towns become cities, and cities turn into sprawling, changing places. Pull back to see entire continents, then zoom in to discover more of what is happening on the ground. All of it should be wrapped in a clean, modern interface.

This is the **big-picture roadmap**. For the longer engineering checklist, see [ROADMAP.md](ROADMAP.md).

## 1. Bigger, more interesting worlds

- [ ] Generate much larger maps with multiple continents, islands, seas, and coastlines.
- [ ] Add more natural variety: mountains, plains, forests, deserts, rivers, and other biomes.
- [ ] Place settlements in sensible locations based on terrain, water, and resources.
- [ ] Make worlds feel different each time, while keeping terrain editing and god powers usable.
- [ ] Keep large worlds smooth to explore and simulate.

**Goal:** Pull the camera back and see a world with room for many distinct civilizations, not just a single island.

## 2. Cities that develop as the world ages

- [ ] Make settlements progress through visible stages, from small villages to towns, cities, and eventually metropolises.
- [ ] Let population, food, resources, safety, location, and time influence how each place grows.
- [ ] Add roads, neighbourhoods, farms, workplaces, landmarks, and more varied buildings as cities develop.
- [ ] Make cities look and behave differently depending on their wealth, environment, culture, and history.
- [ ] Let wars, disasters, shortages, trade, and migration change a city's future.

**Goal:** Every world tells a story, and leaving it running creates noticeable changes rather than just bigger population numbers.

## 3. More detail when you zoom in

- [ ] At world scale, show continents, biomes, borders, and city locations clearly.
- [ ] At regional scale, reveal roads, districts, farms, suburbs, and city layouts.
- [ ] Up close, show more individual buildings, citizens, and everyday activity.
- [ ] Make zoom transitions feel smooth, with detail appearing at the right distance.
- [ ] Adjust detail behind the scenes so large worlds remain performant.

**Goal:** The closer you look, the more there is to discover. Zooming out should still make the whole world easy to understand.

## 4. Redesign the UI to feel like a finished game

- [ ] Create a consistent modern visual style with better typography, spacing, colours, icons, and subtle animations.
- [ ] Replace the prototype-like tool layout with a clear toolbar for terrain tools and god powers.
- [ ] Give selected cities a polished information panel for population, growth, resources, buildings, and relationships.
- [ ] Add useful hover hints and contextual controls, so the screen is not crowded with buttons all the time.
- [ ] Make menus, settings, alerts, and the event log match the same design.
- [ ] Keep controls readable at different window sizes and resolutions.

**Goal:** The interface should feel cohesive and intentional, with the world remaining the main attraction.

## 5. Make it all work together

- [ ] Add save and load so worlds can keep developing between sessions.
- [ ] Improve performance with large populations, sprawling cities, and long-running simulations.
- [ ] Make the important systems work together: terrain, resources, city growth, disasters, diplomacy, and war.
- [ ] Test the real desktop game as well as automated builds, and fix visible bugs before adding more complexity.

**Goal:** A stable, replayable god game where players can create a world, watch it evolve, interfere with it, and return to it later.

## Recommended order

1. **Build the world foundation:** larger procedural maps and reliable camera/terrain controls.
2. **Make time matter:** visible stages of city development and more interesting city growth.
3. **Add zoom-based detail:** world view, regional view, then close-up city view.
4. **Redesign the UI:** give the expanded simulation a clean, modern interface.
5. **Save, optimise, and polish:** make long-running worlds reliable and enjoyable.

The roadmap will change as the game improves. Keep these checkboxes unchecked until each result is actually implemented and tested in-game.
