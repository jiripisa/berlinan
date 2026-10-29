# midi.guide data

`midiguide.json` is derived from the midi.guide MIDI CC & NRPN database
(https://midi.guide, https://github.com/pencilresearch/midi), © its
contributors, licensed under Creative Commons Attribution-ShareAlike 4.0
International (https://creativecommons.org/licenses/by-sa/4.0/).

Changes: only parameters with a CC number 0–119 and a value range are kept
(NRPN-only rows, channel-mode messages, fixed-value commands and trigger
files are left out), converted from CSV to JSON. This derived file
is distributed under the same licence, CC BY-SA 4.0.

Source commit: 776c9ef3475bb3d3b2da0a1505809a0c53bf25ee · retrieved 2026-10-29 ·
132 manufacturers, 445 models, 25006 CC parameters.
