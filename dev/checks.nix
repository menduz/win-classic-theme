# The checks of `nix flake check`.
#
# The build of the theme looks for a lost image and for a token. This file
# adds two more: the parser of GTK reads the style sheets of a built theme,
# and prettier reads the shape of the style sheets of the source.
{
  runCommand,
  runCommandCC,
  pkg-config,
  gtk3,
  gtk4,
  prettier,
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
{
  # The parser of GTK reads the two style sheets of a built theme.
  css =
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
        # GTK4 reads the style sheet of GTK3, which holds the style properties
        # of GTK3.
        ${gtk4Checker}/bin/check-css --ignore-unknown-property "$dir/gtk-4.0/gtk.css"
        touch "$out"
      '';

  # `nix fmt` gives each style sheet the shape that prettier makes.
  css-fmt = runCommand "win-classic-check-css-fmt" { nativeBuildInputs = [ prettier ]; } ''
    mkdir -p sheets/gtk-3.0 sheets/gtk-4.0
    cp ${../gtk-3.0}/*.css sheets/gtk-3.0/
    cp ${../gtk-4.0}/*.css sheets/gtk-4.0/
    prettier --parser css --check sheets/gtk-3.0/*.css sheets/gtk-4.0/*.css
    touch "$out"
  '';
}
