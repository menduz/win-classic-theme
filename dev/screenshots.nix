# The screenshots of the theme.
#
# `themes` is a set of built themes. The name of an attribute is the name of
# the theme, the one below `share/themes`. The build takes screenshots of each
# theme on an X server that holds only Xfwm4 and one application.
#
# The result is a directory of PNG files. `update-screenshots` copies them to
# `screenshots/` in the working tree.
{
  lib,
  callPackage,
  runCommand,
  runCommandCC,
  writeShellApplication,
  writeText,
  makeFontsConf,
  pkg-config,
  glib,
  gtk3,
  gtk4,
  libsForQt5,
  qt6Packages,
  dbus,
  xvfb,
  xfwm4,
  xfconf,
  xsetroot,
  xprop,
  xdotool,
  imagemagick,
  adwaita-icon-theme,
  chicago95,
  librsvg,
  liberation_ttf,
  opensnitch-ui,
  buildEnv,
  kdePackages,
  libfaketime,
  themes,

  # The scheme of the screenshots of the demos. AGENTS.md asks for this one.
  demoTheme ? "win-classic-standard",
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

  disableProgressPulse = runCommandCC "win-classic-disable-progress-pulse" { } ''
    mkdir -p "$out/lib"
    $CC -shared -fPIC -O2 -Wall -Wextra \
      -o "$out/lib/disable-progress-pulse.so" \
      ${./disable-progress-pulse.c}
  '';

  makeQtShowcase =
    {
      name,
      qtbase,
      stylePlugin,
      wrapQtAppsHook,
      pkgConfigName,
    }:
    runCommandCC name
      {
        nativeBuildInputs = [
          pkg-config
          wrapQtAppsHook
        ];
        buildInputs = [
          qtbase
          stylePlugin
        ];
        meta = {
          description = "Qt widget showcase window for the screenshots of win-classic-theme";
          mainProgram = name;
        };
      }
      ''
        mkdir -p "$out/bin"
        $CXX -std=c++17 -fPIC -O2 -Wall -Wextra -o "$out/bin/${name}" \
          ${./qt-showcase.cpp} $(pkg-config --cflags --libs ${pkgConfigName})
        wrapQtApp "$out/bin/${name}"
      '';

  qt5Showcase = makeQtShowcase {
    name = "qt5-showcase";
    inherit (libsForQt5) qtbase wrapQtAppsHook;
    stylePlugin = libsForQt5.qtstyleplugins;
    pkgConfigName = "Qt5Widgets";
  };

  qt6Showcase = makeQtShowcase {
    name = "qt6-showcase";
    inherit (qt6Packages) qtbase wrapQtAppsHook;
    stylePlugin = qt6Packages.qt6gtk2;
    pkgConfigName = "Qt6Widgets";
  };

  # The interface font of the theme. Liberation stays beside it, because the
  # pixel font holds no glyph for the arrows and the marks of a widget factory.
  msSansSerif = callPackage ../fonts { };

  baseFontsConf = makeFontsConf {
    fontDirectories = [
      msSansSerif
      liberation_ttf
    ];
  };

  # `makeFontsConf` reads the font directories of a package, and not its
  # `etc/fonts/conf.d`. The rule of the font package comes in here, so the
  # screenshots show the text of a session of a user.
  fontsConf = writeText "win-classic-fonts.conf" ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      <include>${baseFontsConf}</include>
      <include>${msSansSerif}/etc/fonts/conf.d/60-ms-sans-serif.conf</include>
    </fontconfig>
  '';

  # KWin and the Plasma shell for the Plasma screenshot. NixOS gives these
  # packages to a Plasma session in its profile, and plasmashell finds its QML
  # modules and its plugins there. This environment is that profile.
  plasma = buildEnv {
    name = "win-classic-plasma";
    paths = with kdePackages; [
      kwin-x11
      plasma-workspace
      plasma-desktop
      plasma-integration
      breeze
      breeze-icons
      libplasma
      plasma5support
      plasma-activities
      kactivitymanagerd
      kded
      kirigami
      kirigami-addons
      qqc2-desktop-style
      frameworkintegration
      kservice
      kio
      kcmutils
      ksvg
      kitemmodels
      kdeclarative
      kquickcharts
      libksysguard
      qtdeclarative
      qtsvg
      qt5compat
    ];
    pathsToLink = [
      "/bin"
      "/share"
      "/lib"
      # The menu file of the application launcher.
      "/etc/xdg/menus"
    ];
    ignoreCollisions = true;
  };

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
      qt5Showcase
      qt6Showcase
      opensnitch-ui
      gtk3.dev # gtk3-widget-factory
      gtk4.dev # gtk4-widget-factory
    ];
    text = ''
      # Xfconf puts its D-Bus service file below share/, and GTK finds the
      # icons and the schemas the same way.
      export XDG_DATA_DIRS=${
        lib.concatStringsSep ":" [
          "${xfconf}/share"
          # The icon theme of the modules. Adwaita stays behind it, as in the
          # profile of a user: the modules take the cursor from that package,
          # and a toolkit reads it for an icon that Chicago95 does not hold.
          "${chicago95}/share"
          "${adwaita-icon-theme}/share"
          (glib.getSchemaDataDirPath gtk3)
          (glib.getSchemaDataDirPath gtk4)
        ]
      }
      export GSETTINGS_SCHEMA_DIR=${glib.getSchemaPath gtk3}:${glib.getSchemaPath gtk4}
      # The icon of gtk4-widget-factory is an SVG file, and gdk-pixbuf reads
      # SVG with the loader of librsvg.
      export GDK_PIXBUF_MODULE_FILE=${librsvg}/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache
      export FONTCONFIG_FILE=${fontsConf}
      export DBUS_SESSION_CONF=${dbus}/share/dbus-1/session.conf
      # opensnitch-ui comes from the package set, and its wrapper knows the
      # plugins of Qt6 but not the style of this theme. Qt reads the style from
      # this variable, and the wrapper keeps the value.
      export QT_PLUGIN_PATH=${qt6Packages.qt6gtk2}/lib/qt-6/plugins
      export GTK_FACTORY_PULSE_BLOCKER=${disableProgressPulse}/lib/disable-progress-pulse.so
      export PLASMA_ENV=${plasma}
      # The clock of the Plasma panel shows this time on each build.
      export FAKETIME_LIB=${libfaketime}/lib/libfaketime.so.1
      exec bash ${./screenshot.sh} "$@"
    '';
  };

  shots = lib.mapAttrsToList (
    name: theme:
    ''win-classic-screenshot ${theme}/share/themes/${name} ${name} "$out"''
    + lib.optionalString (name == demoTheme) " \"$out/demos\""
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
      mkdir -p screenshots demos
      install -m 644 "$out"/*.png screenshots/
      install -m 644 "$out"/demos/*.png demos/
      echo "update-screenshots: wrote"
      ls -1 screenshots/ demos/
    '';
  };
}
