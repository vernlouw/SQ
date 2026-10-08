# Optional local audio

The bundled room music and effects are original sounds created for this project,
inspired by the retro synthesizer feel of science-fiction adventure games.
The separate title cues use user-supplied SQ5 and SQ6 recordings with a light
loudness and EQ remaster. The full recordings are preserved.

To replace a sound in your own copy, place a `.wav` or `.ogg` file here using
one of the names below. Restart the game after adding or replacing files.
If both formats exist for a name, OGG takes priority. Missing overrides use
the bundled original sound. Use ordinary PCM WAV or Ogg Vorbis audio.

| Category | Filenames without extension |
| --- | --- |
| Room music | `music_diner`, `music_dock`, `music_museum`, `music_monolith` |
| Room ambience | `ambience_diner`, `ambience_dock`, `ambience_museum`, `ambience_monolith` |
| Title recordings | `intro_fanfare`, `intro_theme` |
| Interface | `ui_click`, `dialogue`, `save`, `load` |
| Interaction | `pickup`, `door`, `terminal`, `combine`, `success`, `blocked` |
| Movement and ending | `step_a`, `step_b`, `complete` |

For example, `pickup.wav` replaces only the inventory pickup sound.
Room music and ambience repeat from start to end, so seamless loops work best.
Effects play once. The `dialogue` sound is a short, quiet text-advance cue;
it is not a voice-over track.

`intro_fanfare` plays the supplied SQ5 fanfare, then `intro_theme` plays the
full supplied SQ6 intro recording. Both are one-shot cues on the Music volume channel.
New Game, Continue, Enter, or Esc skips the remaining sequence and starts the
room score. Completing both recordings naturally leaves the title menu open.
Missing cues are skipped; a title with no recordings remains playable.
Matching local OGG/WAV files here override the bundled title cues.

Game archives such as `RESOURCE.MAP` and `RESOURCE.000`, and emulator DLLs,
are not audio files that this folder can play. This mechanism accepts audio
that has already been converted or recorded as WAV or OGG; it does not extract
Sierra game resources.
