# Space Quest VII: Mopocalypse Now — style prototype

An original, small point-and-click scene inspired by the low-resolution presentation of Space Quest III and V. This is a **one-room prototype**, not the complete game described in the handoff. No original Sierra artwork, sounds, or game files are included.

## Play

Use Godot **4.4.1**. Unzip the project, open Godot's Project Manager, choose **Import**, select this folder's `project.godot`, and press **F6/F5** to run. Import this project directly rather than copying it inside another Godot project.

The viewport is 320×200 and displayed at 960×600. All artwork is drawn in GDScript; no external assets, plugins, credentials, or downloads are needed to play.

- **Walk**: click the floor to move. Click the shuttle door to try leaving.
- **Look**: inspect the news monitor, cook, grease jar, door, and repair panel.
- **Talk**: speak to the cook.
- **Use**: interact with a hotspot. Click the bag to select your inventory item.

### Walkthrough

1. Look at the news monitor to learn about R0-GER.
2. Talk to the cook to get permission to take the grease.
3. Use the grease jar on the counter.
4. Click **Bag: grease**, then click the small orange panel beside the door.
5. Select **Walk**, then click the shuttle door.

The ending is a shuttle departure card; Arcada Museum is not implemented yet. Restart the running project to replay.

## Verified

Godot 4.4.1 imports the scene and scripts. The existing smoke test exercises the blocked exit, cook permission, pickup, inventory selection, grease consumption, repaired door, and departure. The scene has also been rendered using a software OpenGL display and visually checked.

```sh
/path/to/Godot --headless --editor --path . --quit
/path/to/Godot --headless --path . --script tests/smoke.gd
```

`tests/capture.gd` captures the first scene to `/workspace/SQ/preview.png` in the cloud environment and requires a graphical display. It is an optional developer helper, not a game dependency.

## Scope and next steps

Implemented: original simple pixel-style diner, janitor walk animation, Walk/Look/Use/Talk, five hotspots, dialogue, one inventory item, one puzzle, departure screen.

Not implemented: full story/rooms, save/load, audio, death sequences, burger minigame, richer art/animation, or Windows EXE packaging. Windows source-project play is supported through Godot; export templates and executable export have not been tested.
