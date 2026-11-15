# Voxel World

A standalone editable voxel sandbox built with **Godot 4** and GDScript.

## Current prototype

- Procedural terrain generated from FastNoiseLite.
- 16×16 voxel chunks with hidden-face meshing.
- Greedy-free face culling: only exposed block faces are emitted.
- Chunk mesh collision for walking and block interaction.
- First-person controller with mouse look, WASD movement and jumping.
- Remove blocks with the left mouse button.
- Place blocks with the right mouse button.
- Select grass, dirt, stone, sand and wood with keys 1–5.
- Rebuild only the edited chunk and adjacent chunks when an edit crosses a border.

## Run

1. Install Godot 4.3 or newer.
2. Clone this repository.
3. Open the folder containing `project.godot` in Godot.
4. Press F6 or F5 to run the game.

## Controls

| Input | Action |
|---|---|
| WASD | Move |
| Mouse | Look around |
| Space | Jump |
| Left mouse | Remove targeted block |
| Right mouse | Place selected block |
| 1–5 | Select block type |
| Esc | Release / capture mouse |

## Architecture

- `scripts/world.gd` — terrain generation, chunk data, mesh building and editing API.
- `scripts/player.gd` — first-person controller, HUD and block interaction.
- `scenes/main.tscn` — game entry scene.

## Planned next steps

- Persistent world save/load.
- Infinite chunk streaming around the player.
- Caves, ores, trees, water and biome variety.
- Inventory and hotbar.
- Android touch controls.
- Greedy meshing and background chunk generation for better performance.
