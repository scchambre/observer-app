# Observer Sheet — Ultimate (USAU rules)

A single-file, offline-capable mobile web app for Ultimate observers. Replaces the
paper Ultimate Canada Observer Score Sheet and adds a live between-points clock.

## Run it

It's just `index.html` — no build, no server needed.

- **On your phone:** put `index.html` somewhere you can open it (email it to yourself,
  AirDrop, iCloud Drive, or host on GitHub Pages). Open it in Safari/Chrome →
  **Share → Add to Home Screen** for a full-screen app icon. Data is saved on the
  device (localStorage); it keeps working with no signal.
- **On a computer:** double-click the file, or `python3 -m http.server` in this folder.

## What it does

- **Score** with a +Goal button per team; the team that scores becomes the pulling team.
- **Between-points clock (Rule 9.K):** starts automatically on each goal —
  **80s** when *your* team scored (they pull) or **60s** when they conceded (they receive).
  Set which team you're timing with the "I am the observer timing" toggle.
  - Milestones shown: 50s line-up, 60s readiness, 80s pull, with 20s/10s audible chops.
  - **Late ready → 20s** resets to the 20s-after-late-readiness pull window (9.K.4.c).
  - **Re-pull** (20s ready / 40s pull) and time-violation reset are one tap.
  - When the deadline passes the clock turns red and **counts up** (time-violation territory).
- **Gender ratio (ABBA, B1.B):** computed automatically per point and shown live
  (pick the point-1 majority in Setup). Halftime does not reset the pattern.
- **Caps:** enter start time + half/soft/hard cap minutes → wall-clock countdown chips
  and an alarm (sound + vibrate + optional system notification) when each is reached.
- **Log tab:** full score progression, pull-violation + time-warning tallies, misconduct
  records (Tech / Blue TMF / Yellow PMF / Red ejection), timeouts used, and notes.
- **Sheet tab:** a printable summary; **Copy summary** / **Export JSON** for records.

Setup lets you customize timeouts per half, all time limits, venue-specific side labels,
team names/colours/captains/spirit captains, and which side/O-or-D each team started on.

Everything autosaves. Use **Setup → New game / reset** to start the next match.
