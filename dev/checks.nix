# The checks of `nix flake check`.
#
# The build of the theme looks for a lost image and for a token. This file
# adds the parser of GTK: it reads the style sheets of a built theme and stops
# on an error.
{
  runCommand,
  runCommandCC,
  pkg-config,
  gtk3,
  gtk4,
  theme,
  themeName,
}:
let
  checker =
    suffix: gtk: package:
    runCommandCC "win-classic-check-css-${suffix}"
      {
        nativeBuildInputs = [ pkg-config ];
        buildInputs = [ gtk ];
      }
      ''
        mkdir -p "$out/bin"
        $CC -O2 -Wall -o "$out/bin/check-css" ${./check-css.c} \
          $(pkg-config --cflags --libs ${package})
      '';

  gtk3Checker = checker "gtk3" gtk3 "gtk+-3.0";
  gtk4Checker = checker "gtk4" gtk4 "gtk4";
in
runCommand "win-classic-check-css"
  {
    nativeBuildInputs = [
      gtk3Checker
      gtk4Checker
    ];
  }
  ''
    dir=${theme}/share/themes/${themeName}
    ${gtk3Checker}/bin/check-css "$dir/gtk-3.0/gtk.css"
    # GTK4 reads the style sheet of GTK3, which holds the style properties of
    # GTK3.
    ${gtk4Checker}/bin/check-css --ignore-unknown-property "$dir/gtk-4.0/gtk.css"
    touch "$out"
  ''
