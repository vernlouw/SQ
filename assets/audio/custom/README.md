# Optional local audio

The bundled music and effects are original sounds created for this project,
inspired by the retro synthesizer feel of science-fiction adventure games.
They are **not actual Space Quest V recordings**.

To replace a sound in your own copy, place a `.wav` or `.ogg` file here using
one of the names below. Restart the game after adding or replacing files.
If both formats exist for a name, OGG takes priority. Missing overrides use
the bundled original sound. Use ordinary PCM WAV or Ogg Vorbis audio.

| Category | Filenames without extension |
| --- | --- |
| Room music | `music_diner`, `music_dock`, `music_museum` |
| Room ambience | `ambience_diner`, `ambience_dock`, `ambience_museum` |
| Interface | `ui_click`, `dialogue`, `save`, `load` |
| Interaction | `pickup`, `door`, `terminal`, `combine`, `success`, `blocked` |
| Movement and ending | `step_a`, `step_b`, `complete` |

For example, `pickup.wav` replaces only the inventory pickup sound.
Room music and ambience repeat from start to end, so seamless loops work best.
Effects play once. The `dialogue` sound is a short, quiet text-advance cue;
it is not a voice-over track.

Game archives such as `RESOURCE.MAP` and `RESOURCE.000`, and emulator DLLs,
are not audio files that this folder can play. This mechanism accepts audio
that has already been converted or recorded as WAV or OGG; it does not extract
Sierra game resources.
