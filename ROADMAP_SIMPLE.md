# Civiterra: Simple Roadmap

## The vision

Civiterra should feel like a living, evolving world. Leave the simulation running and watch villages become towns, towns become cities, and cities grow into sprawling metropolises. Pull back to see whole continents, zoom in to discover detailed streets and buildings, unleash wars and disasters, or take direct control of a person living in the world. The whole experience should have a polished, modern interface.

This is the **big-picture roadmap**. For the longer implementation checklist, see [ROADMAP.md](ROADMAP.md).

## 1. Bigger, more interesting worlds

- [ ] Generate much larger maps with multiple continents, islands, seas, and coastlines.
- [ ] Add mountains, plains, forests, deserts, rivers, and varied biomes.
- [ ] Place settlements in sensible locations based on terrain, water, and resources.
- [ ] Make every new world feel different while keeping terrain editing and god powers usable.
- [ ] Keep large worlds smooth to explore and simulate.

**Goal:** Pull back and see a whole world with space for many civilizations, not just one small island.

## 2. Cities that develop as the world ages

- [ ] Make settlements progress visibly from villages to towns, cities, and eventually metropolises.
- [ ] Let population, resources, safety, location, and history influence growth.
- [ ] Add roads, neighbourhoods, farms, workplaces, landmarks, and varied buildings.
- [ ] Expand city territory as new buildings push out towards the edge of the settlement.
- [ ] Show each city's territory with a distinct coloured zone; when neighbouring zones meet, create a shared border.
- [ ] Let the camera smoothly zoom out to show the selected city's larger footprint as it expands, while allowing manual camera control to override it.
- [ ] Make cities look and behave differently based on their environment and development.
- [ ] Let trade, migration, wars, disasters, and city events change a city's future.

**Goal:** Leave the world running and come back to cities that have visibly changed, not just gained a few numbers.

## 3. More detail when you zoom in

- [ ] At world scale, show continents, biomes, borders, and city locations.
- [ ] At regional scale, reveal roads, districts, farms, suburbs, and city layouts.
- [ ] Up close, show more individual buildings, citizens, vehicles, and everyday activity.
- [ ] Make zoom transitions smooth and adjust detail to keep performance reasonable.

**Goal:** The closer you look, the more there is to discover.

## 4. Bigger wars and advanced destruction

- [ ] Expand wars beyond basic armies with tanks, aircraft, and attack helicopters.
- [ ] Give vehicles different strengths, roles, movement, weapons, and counters.
- [ ] Let battles damage roads and buildings, start fires, and visibly reshape cities.
- [ ] Add structural damage so weakened buildings can collapse and knock into nearby structures.
- [ ] Make destruction readable and satisfying without bringing the whole simulation to a crawl.

**Goal:** Wars should feel like large events that can change the map and leave lasting scars on a city.

## 5. Cities with unexpected events

- [ ] Add a stream of contextual city events based on what is happening in the simulation.
- [ ] Include protests, strikes, unrest, rebellions, crime, bank robberies, and fictional terrorist or insurgent attacks.
- [ ] Make events depend on conditions such as poverty, public satisfaction, security, shortages, and war.
- [ ] Let citizens and city leaders respond, and show outcomes through the world and event feed.
- [ ] Give the player ways to intervene, help the city recover, or make a bad situation worse.

**Goal:** Cities should have their own stories and occasional surprises instead of behaving like identical population counters.

## 6. Play as any person in the world

- [ ] Let the player select and directly control any ordinary citizen.
- [ ] Add a close-up third-person view with movement and basic interactions.
- [ ] Allow the player to explore the city, visit places, work, meet people, and take part in everyday life.
- [ ] Let players cause harmless mischief or serious in-game chaos, with consequences inside the simulation.
- [ ] Make switching between person mode and god mode smooth, without stopping the world's simulation.

**Goal:** Move from watching a civilization from above to actually living inside it, while keeping the god-game powers.

## 7. Redesign the UI to feel like a finished game

- [ ] Create a consistent modern style with better typography, spacing, colours, icons, and subtle animation.
- [ ] Replace the prototype-like layout with a clear toolbar for terrain tools, god powers, and world controls.
- [ ] Give selected cities and people attractive information panels with useful details.
- [ ] Use contextual controls and helpful tooltips to keep the screen uncluttered.
- [ ] Make menus, settings, event feeds, and alerts match the same design.
- [ ] Keep the interface readable at different resolutions.

**Goal:** Make the game look intentional and cohesive, while keeping the living world as the main attraction.

## 8. Save, optimise, and bring it all together

- [ ] Save and load worlds, including terrain edits, cities, people, vehicles, and ongoing events.
- [ ] Make city growth, disasters, warfare, destruction, and person mode work together.
- [ ] Keep large populations, sprawling cities, vehicle battles, and destruction performant.
- [ ] Test actual desktop gameplay as well as automated builds, and fix visible bugs.
- [ ] Create reliable playable milestones and document known limitations.

**Goal:** A stable, replayable sandbox where worlds keep evolving and player actions have lasting consequences.

## 9. Bring Civiterra to mobile

- [ ] Adapt the interface for touchscreens, including camera movement, selection, world tools, and readable panels.
- [ ] Add mobile-friendly graphics and simulation settings for a wider range of devices.
- [ ] Build and test an Android version after the desktop gameplay loop is stable.
- [ ] Evaluate an iOS port after the controls, performance, and platform requirements are understood.
- [ ] Keep saves and core game systems compatible across supported platforms where practical.

**Goal:** Take the same living-world sandbox on the go without turning the screen into a pile of tiny buttons.

## 10. Add multiplayer

- [ ] Let multiple players join the same world and interact with it together.
- [ ] Synchronise world edits, simulation time, cities, people, events, and wars.
- [ ] Decide how players share powers and control, with clear permissions and options for cooperative or competitive play.
- [ ] Handle joining, leaving, reconnecting, saving, and recovering from connection problems.
- [ ] Test network performance and prevent players from seeing different versions of the same world.
- [ ] Plan for cross-platform play only after desktop and mobile builds are reliable.

**Goal:** Share a persistent world with other players without desynchronisation turning civilization into parallel universes.

## Recommended order

1. Build the foundation: larger procedural worlds and reliable terrain and camera controls.
2. Make cities visibly develop over time and add more detail as the camera zooms in.
3. Expand warfare and destruction once the city and building systems can support them.
4. Add city events and responses so civilizations feel unpredictable and alive.
5. Redesign the UI around the expanded simulation.
6. Add direct citizen control as a deeper game mode, then finish save/load and optimisation.
7. Add mobile controls and a tested Android port, then assess iOS.
8. Build multiplayer only after the underlying simulation and cross-platform builds are stable.

The roadmap will change as the game improves. Keep these checkboxes unchecked until each result is actually implemented and tested in-game.
