# A theme with three schemes: a light scheme, a dark scheme and a high
# contrast scheme in one package.
#
# share/themes/<name>-light, <name>-dark and <name>-contrast are the themes of
# the schemes. GTK2, GTK3, GTK4, Xfwm4, rofi and kwm select a scheme by its
# name.
#
# share/themes/<name> holds the three schemes in one GTK4 style sheet. A
# program with this theme (libadwaita: GTK_THEME) selects the scheme from the
# color scheme and the contrast of the desktop, also while it runs. The other
# files of this theme are the files of the light scheme. Its GTK3 style sheet
# gtk-dark.css holds the dark scheme.
#
# callPackage gives the build tools. The result is a function that takes the
# themes of scheme.nix. One theme can be in more than one place: the build
# copies it with the new name.
{
  lib,
  stdenvNoCC,
  python3,
}:
{
  name,
  light,
  dark,
  # Without a contrast scheme, <name>-contrast is a copy of the dark scheme,
  # and the GTK4 style sheet of <name> has no contrast block.
  contrast ? null,
}:
let
  hasContrast = contrast != null;

  schemes = {
    inherit light dark;
    contrast = if hasContrast then contrast else dark;
  };

  order = [
    "light"
    "dark"
    "contrast"
  ];

  themeName = scheme: "${name}-${scheme}";

  # The media query of each block of the GTK4 style sheet, in this order. A
  # later block wins, thus the contrast scheme wins over the dark one.
  blocks = [
    {
      scheme = "dark";
      query = "prefers-color-scheme: dark";
    }
  ]
  ++ lib.optional hasContrast {
    scheme = "contrast";
    query = "prefers-contrast: more";
  };

  copyScheme =
    scheme:
    let
      package = schemes.${scheme};
    in
    ''
      copy_scheme ${package} ${package.themeName} ${themeName scheme}
      ln -s ${package.icons}/share/icons/${package.themeName} "$out/share/icons/${themeName scheme}"
    '';
in
stdenvNoCC.mkDerivation {
  pname = name;
  inherit (light) version;

  dontUnpack = true;
  nativeBuildInputs = [ python3 ];

  installPhase = ''
    runHook preInstall

    # copy_scheme <package> <name in package> <new name>: the GTK theme and the
    # KDE themes. A new name replaces the old one in the files and in the
    # file names.
    copy_scheme() {
      local dir
      for dir in share/themes share/aurorae/themes share/plasma/desktoptheme; do
        [ -e "$1/$dir/$2" ] || continue
        mkdir -p "$out/$dir"
        cp -a "$1/$dir/$2" "$out/$dir/$3"
        chmod -R u+w "$out/$dir/$3"
        if [ "$2" != "$3" ]; then
          find "$out/$dir/$3" -depth -name "*$2*" -execdir sh -c \
            'mv "$1" "$(printf "%s" "$1" | sed "s|$2|$3|g")"' sh {} "$2" "$3" \;
          grep -rlF -- "$2" "$out/$dir/$3" | xargs -r sed -i "s|$2|$3|g"
        fi
      done
    }

    mkdir -p "$out/share/icons"
    ${lib.concatMapStrings copyScheme order}

    # The theme with all schemes: the files of the light scheme, and the GTK
    # files of the other schemes below it.
    theme=$out/share/themes/${name}
    cp -a "$out/share/themes/${themeName "light"}" "$theme"
    sed -i 's/^Name=.*/Name=${name}/' "$theme/index.theme"
    ln -s ${themeName "light"} "$out/share/icons/${name}"

    ${lib.concatMapStrings (b: ''
      mkdir -p "$theme/${b.scheme}"
      cp -a "$out/share/themes/${themeName b.scheme}/gtk-3.0" \
        "$out/share/themes/${themeName b.scheme}/gtk-4.0" "$theme/${b.scheme}/"
    '') blocks}

    python3 ${./merge-css.py} "$theme/gtk-4.0" "$theme/gtk-4.0/gtk.css" ${
      lib.concatMapStringsSep " " (
        b: ''"${b.query}" scheme_${b.scheme}_ "$theme/${b.scheme}/gtk-4.0/gtk.css"''
      ) blocks
    } >gtk.css
    mv gtk.css "$theme/gtk-4.0/gtk.css"

    # GTK3 reads gtk-dark.css for a program that asks for the dark variant.
    python3 ${./merge-css.py} "$theme/gtk-3.0" "$theme/dark/gtk-3.0/gtk.css" >"$theme/gtk-3.0/gtk-dark.css"

    runHook postInstall
  '';

  # Every `url()` of a style sheet must point to a file.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    bad=0
    while read -r css; do
      dir=$(dirname "$css")
      while read -r ref; do
        case "$ref" in
          "" | resource:* | http:* | https:* | file:*) continue ;;
        esac
        if [ ! -e "$dir/$ref" ]; then
          echo "$css: url(\"$ref\") points to no file" >&2
          bad=1
        fi
      done < <(grep -o 'url("[^"]*")' "$css" | sed 's|url("||; s|")$||')
    done < <(find "$out/share/themes" -name '*.css')
    if [ "$bad" -ne 0 ]; then
      exit 1
    fi

    runHook postInstallCheck
  '';

  passthru = {
    inherit (light) decorationLayout;
    inherit hasContrast schemes;
    # The name below share/themes of each scheme, and of the theme with all
    # schemes.
    names = lib.genAttrs order themeName // {
      all = name;
    };
    # Whether each scheme is dark. The contrast scheme is dark when its window
    # color is dark.
    dark = {
      light = false;
      dark = true;
      contrast = schemes.contrast.dark;
    };
  };

  meta = light.meta // {
    description = "Nostalgic windows theme for NixOS, with a light, a dark and a high contrast scheme.";
  };
}
