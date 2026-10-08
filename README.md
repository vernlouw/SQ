# Space Quest — The Mop Job

A playable, original 2D point-and-click adventure chapter inspired by the comic science-fiction storytelling of Space Quest. The presentation uses detailed illustrated room backgrounds and a modern widescreen interface. Classic adventure verbs, inventory puzzles, dialogue, and room navigation drive the story.

This build covers **three connected rooms**: the Orbital Diner (Astro-Burger), Service Dock 7, and the Arcada Memorial Museum. It is an opening chapter with its own puzzle sequence and departure ending. The larger sixteen-room adventure in the original concept is still future work. No artwork, audio, or files from Sierra's games are included.

![Current in-game screenshot](preview.png)

![Portrait dialogue screenshot](preview-dialogue.png)

## Play on Windows

1. [Download this repository as a ZIP](https://github.com/vernlouw/SQ/archive/refs/heads/main.zip) and extract it.
2. Open **Godot 4.4.1**, choose **Import** in the Project Manager, and select the extracted folder's `project.godot`.
3. Open the imported project and press **F5** to play.

Import this project directly. Avoid copying its contents into an existing Godot project. This download is source code; a standalone Windows executable is not included. Playing requires no external services, credentials, or additional assets.

## Controls

- Click the verb buttons or press **1–4** to choose **Walk, Look, Use, Talk**.
- **Walk**: click the floor to move, or a room exit to leave. Other interactions walk the character into position first.
- **Look**: inspect people and objects for clues. **Talk**: speak to characters.
- **Use**: interact with an object. Select an inventory item, then click its target to use it there. Select one inventory item, then click another to combine them.
- **Tab**: show hotspot hints. **I**: inventory hint.
- **F5**: save progress. **F9**: load progress. Use the on-screen controls to save, load, or start a new game too.

There is one local save slot, stored in Godot's per-user application data directory rather than in the project folder. Starting a new game resets the current chapter; loading restores the saved progress.

## Walkthrough (spoilers)

1. At Astro-Burger, look at the news screen and talk to the cook. Get a service chit and permission to take the grease.
2. Use the grease jar. Select the grease in your inventory and use it on the maintenance panel to repair the hatch. Walk through the exit to the dock.
3. Give the service chit to the dock guard to receive a keycard and maintenance pass.
4. Use the keycard on the locker to collect a mop and cleaner. Use the keycard on the terminal to authorize museum access, then enter the museum.
5. Talk to the guardian for a clue. Use your maintenance pass on the guardian to enable cleaning mode.
6. Combine the cleaner and mop in your inventory. Use the charged mop on the spill to clear the floor, then use the plinth to collect the star map.
7. Return to the dock. Use the star map on the terminal to set the coordinates, then use the shuttle to finish the chapter.

## Development and verification

Validated in Godot 4.4.1: clean project import, **51 passing integration checks**, and visually inspected graphical captures of all three rooms and portrait dialogue.

The project targets Godot **4.4.1** with its Compatibility renderer. Validation on Linux passed a clean Godot import, **51 integration checks**, and a graphical screenshot run. Run these from the project folder, substituting the path to your Godot executable:

```sh
/path/to/Godot --headless --editor --path . --quit
/path/to/Godot --headless --path . --script tests/smoke.gd
```

Use a separate `XDG_DATA_HOME` directory when running the smoke test on Linux; it exercises the game's save slot. The test checks blocked actions, item combinations and consumption, all three rooms, the ending, real mouse events through buttons and world hotspots, and saving/loading/resetting progress.

`tests/capture.gd` is an optional screenshot helper and requires a graphical display:

```sh
/path/to/Godot --path . --script tests/capture.gd -- --room=diner --output=/tmp/diner.png
```

Capture room IDs are `diner`, `dock`, and `museum`. Omit `--output` to write `capture_<room>.png` to the local user-data directory.

## Current scope

Included: three illustrated rooms, character movement, Walk/Look/Use/Talk, contextual dialogue, inventory selection and combination, a connected puzzle chain, blocked progression with hints, a chapter ending, and local save/load/new game.

Still to build: the remaining story locations, a full adventure finale, richer character animation, music and sound, voiced dialogue, death sequences, the burger minigame, and a tested standalone Windows export. The artwork is original and AI-assisted; character animation remains simpler than the backgrounds. This chapter provides a working basis for expanding and polishing the adventure.
