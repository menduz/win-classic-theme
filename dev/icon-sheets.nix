# The icon sheets. The sheets show all the icons of each icon theme of
# `win98se.nix`, at 16 pixels, on the light scheme and on the dark scheme. Each
# sheet holds 1024 icons at most, thus a theme has one or more sheets.
#
# Each band shows the icons that a session with that scheme gets: the icon
# theme of the scheme package first, then SE98 and the themes that it inherits.
# The SE98 sheets also hold the names of the icon theme of the scheme.
#
# `screenshots/icons-<theme>.txt` gives the order of the icons. The build keeps
# that order and adds the new names at the end. `update-icon-sheets` copies the
# sheets and the lists to `screenshots/`.
{
  lib,
  callPackage,
  runCommand,
  writeShellApplication,
  librsvg,
  python3,
  chicago95,
  adwaita-icon-theme,
  hicolor-icon-theme,

  # Each scheme gives `package`, `preset`, the name in presets.nix, and `name`,
  # the name of the theme and of its icon theme.
  light,
  dark,
}:
let
  se98 = callPackage ../win98se.nix { };
  presets = import ../presets.nix;

  # The order of the directories is the order of XDG_DATA_DIRS in a session.
  search = [
    "${light.package}/share/icons"
    "${dark.package}/share/icons"
    "${se98}/share/icons"
    "${chicago95}/share/icons"
    "${adwaita-icon-theme}/share/icons"
    "${hicolor-icon-theme}/share/icons"
  ];

  # The name of each sheet, and the icon themes that give its names.
  sheets = {
    SE98 = [
      light.name
      dark.name
      "SE98"
    ];
    SE98-Papirus-Symbolic = [ "SE98-Papirus-Symbolic" ];
  };
  themes = builtins.attrNames sheets;

  # GTK paints a symbolic icon with the text color and with the three colors
  # of a state. The style sheet gives the same state colors to all schemes.
  css = lib.splitString "\n" (builtins.readFile ../gtk-3.0/gtk.css);
  stateColor =
    name:
    lib.head (
      lib.findFirst (m: m != null) (throw "gtk.css has no ${name}_color") (
        map (builtins.match "@define-color ${name}_color (#[0-9A-Fa-f]+);") css
      )
    );
  colors =
    scheme:
    let
      preset = presets.${scheme.preset};
    in
    lib.concatStringsSep "," [
      scheme.name
      preset.bgcolor
      preset.fgcolor
      (stateColor "warning")
      (stateColor "error")
      (stateColor "success")
    ];

  order = theme: ../screenshots + "/icons-${theme}.txt";

  sheet = theme: ''
    python3 ${./icon-sheet.py} \
      ${lib.concatMapStringsSep " " (d: "--search ${d}") search} \
      ${lib.concatMapStringsSep " " (t: "--names ${t}") sheets.${theme}} \
      ${lib.optionalString (builtins.pathExists (order theme)) "--order ${order theme}"} \
      --light '${colors light}' \
      --dark '${colors dark}' \
      --out-prefix "$out/icons-${theme}" \
      --out-txt "$out/icons-${theme}.txt"
  '';
in
{
  sheets =
    runCommand "win-classic-icon-sheets"
      {
        nativeBuildInputs = [
          librsvg
          (python3.withPackages (ps: [ ps.pillow ]))
        ];
        meta.description = "All the icons of SE98 and of its symbolic fallback theme";
      }
      ''
        mkdir -p "$out"
        ${lib.concatMapStrings sheet themes}
      '';

  update = writeShellApplication {
    name = "update-icon-sheets";
    text = ''
      if [ ! -e ./win98se.nix ]; then
        echo "update-icon-sheets: run this in the directory of the theme" >&2
        exit 1
      fi
      if ! out=$(nix build --no-link --print-out-paths .#icon-sheets); then
        echo "update-icon-sheets: the build failed" >&2
        exit 1
      fi
      for list in ${lib.concatMapStringsSep " " (theme: "screenshots/icons-${theme}.txt") themes}; do
        if [ -e "$list" ] && ! git ls-files --error-unmatch "$list" >/dev/null 2>&1; then
          echo "update-icon-sheets: Nix does not read $list, because Git does" >&2
          echo "not track it. Run 'git add $list' and run this again." >&2
          exit 1
        fi
      done
      mkdir -p screenshots
      rm -f screenshots/icons-*.png
      install -m 644 "$out"/icons-* screenshots/
      echo "update-icon-sheets: wrote"
      ls -1 screenshots/icons-*
    '';
  };
}
