# General instructions

- We will do atomic changes to the CSS. One item at a time, and then commit the change. Commits require human validation of the pre/after screenshots.
- All changes to this theme require a previous screenshot.
- When fixing a bug, we need to identify it first using `gtk3-demo` and/or `gtk4-demo` and emit one screenshot. Bug screenshots will only use `classic-standard` color scheme only. Before fixing an issue, we need to FIRST commit the bugged image to keep a visual history of fixes bound to each css change, the CSS MUST be committed along with the fixed screenshot.
- The screenshot of a demo is `demos/<demoname>.png`. It holds the window of `gtk3-demo --run=<demoname>` or of `gtk4-demo --run=<demoname>`. The fix overwrites the same file, thus each file shows the demo of today and Git holds the history of the fixes.
- This repository forks Redmond 97, it is in the attribution. No need to mention it and its divergences in code comments anywhere else.
- Keep CSS code comments MINIMAL, these are almost never useful.

# Writing style

Always write documentation, code and comments using ASD-STE100 simlplified technical english. Do NOT write bluff.

# Readme contents

Keep it short, a couple screenshots of widgets, how to change colors, default presets and nix code examples to integrate with nixos and home-manager only.