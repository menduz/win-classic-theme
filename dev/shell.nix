# The development shell. `nix develop` gives the commands that build the theme,
# look at it and take the screenshots.
{
  mkShell,
  writeShellApplication,
  imagemagick,
  nixfmt-rfc-style,
  gtk3,
  screenshot,
  showcase,
  update-screenshots,
}:
let
  # Build one preset and open the showcase window with it, on the display of
  # the user. A command after the name of the preset replaces the showcase, for
  # example `preview-theme luna gtk3-widget-factory`.
  preview = writeShellApplication {
    name = "preview-theme";
    runtimeInputs = [
      showcase
      gtk3.dev # gtk3-widget-factory
    ];
    text = ''
      preset=''${1:-dark}
      shift || true

      theme=$(nix build --no-link --print-out-paths ".#$preset")
      name=$(basename "$theme"/share/themes/*)

      export XDG_DATA_DIRS="$theme/share''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
      export GTK_THEME=$name
      export GTK2_RC_FILES="$theme/share/themes/$name/gtk-2.0/gtkrc"

      echo "preview-theme: $name from the preset $preset"
      if [ $# -gt 0 ]; then
        exec "$@"
      else
        exec showcase
      fi
    '';
  };
in
mkShell {
  packages = [
    imagemagick # the theme build paints the images with it
    nixfmt-rfc-style
    gtk3.dev # gtk3-widget-factory, gtk3-demo, gtk-builder-tool
    preview
    screenshot
    showcase
    update-screenshots
  ];

  shellHook = ''
    cat <<'EOF'
    win-classic-theme

      nix build .#<preset>      build one scheme, for example .#luna
      nix build .#screenshots   make the screenshots in the sandbox
      update-screenshots        make them and copy them to screenshots/
      preview-theme <preset>    open the showcase window with a scheme
      win-classic-screenshot    the screenshot script, on a built theme
      nix fmt                   format the Nix files

    The presets are the attributes of presets.nix.
    EOF
  '';
}
