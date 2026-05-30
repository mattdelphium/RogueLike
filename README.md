# RogueLike Prototype

This Godot 4 project contains the first playable arena prototype.

## Current loop

- Move the blue square with WASD.
- Red squares spawn around the arena and chase the player.
- Touching an enemy ends the run.
- Press R to restart.

## Project layout

- `scenes/main.tscn` contains the arena, enemy spawning, HUD, and restart loop.
- `scenes/player.tscn` contains the player body, collision, and placeholder art.
- `scenes/enemy.tscn` contains the chasing enemy.
- `scripts/` contains one script per gameplay responsibility.

## Running it

1. Open the repository root in Godot 4.
2. Run the project. The main scene is configured in `project.godot`.
3. Tweak speeds and spawn values in the inspector to iterate quickly.