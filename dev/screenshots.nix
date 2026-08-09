# The screenshots of the theme.
#
# `themes` is a set of built themes. The name of an attribute is the name of
# the theme, the one below `share/themes`. The build takes two screenshots of
# each theme, on an X server that holds nothing but Xfwm4 and one application.
#
# The result is a directory of PNG files. `update-screenshots` copies them to
# `screenshots/` in the working tree.
{
  lib,
  runCommand,
  runCommandCC,
  writeShellApplication,
  makeFontsConf,
  pkg-config,
  glib,
  gtk3,
  dbus,
  xvfb,
  xfwm4,
  xfconf,
  xsetroot,
  xprop,
  xdotool,
  imagemagick,
  adwaita-icon-theme,
  liberation_ttf,
  themes,
}:
let
  # The window with one widget of each kind. The screenshot script starts it.
  showcase =
    runCommandCC "win-classic-showcase"
      {
        nativeBuildInputs = [ pkg-config ];
        buildInputs = [ gtk3 ];
        meta = {
          description = "Widget showcase window for the screenshots of win-classic-theme";
          mainProgram = "showcase";
        };
      }
      ''
        mkdir -p "$out/bin"
        $CC -O2 -Wall -o "$out/bin/showcase" ${./showcase.c} \
          $(pkg-config --cflags --libs gtk+-3.0)
      '';

  fontsConf = makeFontsConf { fontDirectories = [ liberation_ttf ]; };

  # The X server, the window manager and the applications, with an environment
  # that holds no setting of the user.
  screenshot = writeShellApplication {
    name = "win-classic-screenshot";
    runtimeInputs = [
      dbus
      xvfb
      xfwm4
      xfconf
      xsetroot
      xprop
      xdotool
      imagemagick
      showcase
      gtk3.dev # gtk3-widget-factory
    ];
    text = ''
      # Xfconf puts its D-Bus service file below share/, and GTK finds the
      # icons and the schemas the same way.
      export XDG_DATA_DIRS=${
        lib.concatStringsSep ":" [
          "${xfconf}/share"
          "${adwaita-icon-theme}/share"
          (glib.getSchemaDataDirPath gtk3)
        ]
      }
      export GSETTINGS_SCHEMA_DIR=${glib.getSchemaPath gtk3}
      export FONTCONFIG_FILE=${fontsConf}
      export DBUS_SESSION_CONF=${dbus}/share/dbus-1/session.conf
      exec bash ${./screenshot.sh} "$@"
    '';
  };

  shots = lib.mapAttrsToList (
    name: theme: ''win-classic-screenshot ${theme}/share/themes/${name} ${name} "$out"''
  ) themes;
in
{
  inherit showcase screenshot;

  screenshots =
    runCommand "win-classic-screenshots"
      {
        nativeBuildInputs = [ screenshot ];
        meta.description = "Screenshots of win-classic-theme";
      }
      ''
        mkdir -p "$out"
        ${lib.concatStringsSep "\n" shots}
      '';

  # `update-screenshots` in the development shell. It builds the screenshots
  # and puts them in the working tree.
  update = writeShellApplication {
    name = "update-screenshots";
    text = ''
      if [ ! -e ./default.nix ] || [ ! -e ./presets.nix ]; then
        echo "update-screenshots: run this in the directory of the theme" >&2
        exit 1
      fi
      if ! out=$(nix build --no-link --print-out-paths .#screenshots); then
        echo "update-screenshots: the build failed. Nix reads the files that" >&2
        echo "Git tracks, so a new file needs 'git add' first." >&2
        exit 1
      fi
      mkdir -p screenshots
      install -m 644 "$out"/*.png screenshots/
      echo "update-screenshots: wrote"
      ls -1 screenshots/
    '';
  };
}
