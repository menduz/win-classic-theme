# The icon theme of one color scheme: the action icons of SE98kde in the colors
# of the scheme, below share/icons/<name>. It inherits SE98.
#
# callPackage gives the build tools. The result is a function that takes the
# name and the two colors of the icons.
{
  lib,
  stdenvNoCC,
  callPackage,

  # The icon theme that this icon theme inherits. The build reads its links.
  se98 ? callPackage ./win98se.nix { },
}:
{
  name,
  # The color of the text: the paths of the class ColorScheme-Text and of the
  # other text classes.
  fgcolor,
  # The color of the selection: the paths of the class ColorScheme-Highlight.
  selectedbg,
}:
stdenvNoCC.mkDerivation {
  pname = "${name}-icons";
  version = "20260803";

  src = builtins.path {
    name = "win-classic-icons";
    path = ./icons/SE98kde;
  };

  # Each SVG icon of SE98kde holds the Breeze colors in a style sheet. KDE
  # replaces that style sheet at run time, GTK and Qt draw it as it is. Thus
  # the colors of the scheme go into it, the same colors that plasma.nix gives
  # to KDE. A symbolic icon gets the color of the text from GTK.
  buildPhase = ''
    runHook preBuild

    find . -name '*.svg' -type f -exec sed -z -E -i \
      -e 's/(\.ColorScheme-Highlight[[:space:]]*\{[[:space:]]*color:[[:space:]]*)#[0-9a-fA-F]{6}/\1${selectedbg}/g' \
      -e 's/(\.ColorScheme-[A-Za-z]*Text[[:space:]]*\{[[:space:]]*color:[[:space:]]*)#[0-9a-fA-F]{6}/\1${fgcolor}/g' \
      {} +
    sed -i 's/^Name=.*/Name=${name}/' index.theme

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    icons=$out/share/icons/${name}
    mkdir -p "$icons"
    # The copy follows the links, because some links point to an icon that the
    # next step removes.
    cp -rL actions index.theme "$icons"/

    # SE98 gives the icons of the window buttons. It draws them at more sizes,
    # and with smaller glyphs. GTK selects a size only in the first theme that
    # holds the icon, thus these icons must not be in this theme.
    find "$icons"/actions -name 'window-*.svg' -delete

    # SE98 gives some names as links to another icon, for example
    # gtk-media-pause links to media-playback-pause. GTK finds the name in SE98
    # and takes the icon of SE98, not the icon of this theme. Thus each link of
    # SE98 to an icon of this theme gets the same link here. A name stays out
    # when SE98 also holds it as a file, or when its links in SE98 point to
    # different icons. A link from a symbolic name to a name that is not
    # symbolic also stays out, because GTK paints the two kinds in different
    # ways. The loop also follows a link to a link.
    find ${se98}/share/icons/SE98 \( -type f -o -type l \) -printf '%y\t%f\t%l\n' |
      awk -F '\t' '
        $2 ~ /\.symbolic\.png$/ || $2 !~ /\.(png|svg|xpm)$/ { next }
        {
          alias = $2
          sub(/\.(png|svg|xpm)$/, "", alias)
          if ($1 == "f") { file[alias] = 1; next }
          target = $3
          sub(/.*\//, "", target)
          sub(/\.(png|svg|xpm)$/, "", target)
          if (!((alias, target) in seen)) {
            seen[alias, target] = 1
            count[alias]++
            only[alias] = target
          }
        }
        END {
          for (alias in count) {
            target = only[alias]
            if (alias in file || count[alias] != 1 || alias ~ /^window-/) continue
            if ((alias ~ /-symbolic$/) != (target ~ /-symbolic$/)) continue
            print alias "\t" target
          }
        }' | sort >se98-links
    while true; do
      find "$icons" -mindepth 3 -printf '%f\n' | sed 's/\.[^.]*$//' | sort -u >names
      awk -F '\t' 'NR == FNR { have[$1]; next } ($2 in have) && !($1 in have)' \
        names se98-links >new-links
      if [ ! -s new-links ]; then
        break
      fi
      while IFS=$'\t' read -r alias target; do
        for file in "$icons"/actions/*/"$target".*; do
          [ -e "$file" ] || continue
          dir=$(dirname "$file")
          if [ -z "$(find "$dir" -maxdepth 1 -name "$alias.*" -print -quit)" ]; then
            ln -s "$(basename "$file")" "$dir/$alias.''${file##*.}"
          fi
        done
      done <new-links
    done
    rm se98-links names new-links

    # SE98 links media-seek-backward-rtl and media-seek-forward-rtl to a
    # different icon at each size. In a text from right to left, backward
    # points to the right, as the icon of SE98 at 16 pixels shows.
    for dir in "$icons"/actions/*; do
      if [ -e "$dir/media-seek-forward.svg" ]; then
        ln -s media-seek-forward.svg "$dir/media-seek-backward-rtl.svg"
      fi
      if [ -e "$dir/media-seek-backward.svg" ]; then
        ln -s media-seek-backward.svg "$dir/media-seek-forward-rtl.svg"
      fi
    done

    runHook postInstall
  '';

  # Each color of the style sheet of an icon must be a color of the scheme.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    bad=0
    while read -r color; do
      case "$color" in
        '${fgcolor}' | '${selectedbg}') ;;
        *)
          echo "an icon holds the color $color, and the scheme does not" >&2
          bad=1
          ;;
      esac
    done < <(find $out/share/icons/${name} -name '*.svg' -exec cat {} + |
      grep -ozE '\.ColorScheme-[A-Za-z]+[[:space:]]*\{[[:space:]]*color:[[:space:]]*#[0-9a-fA-F]{6}' |
      tr '\0' '\n' | grep -oE '#[0-9a-fA-F]{6}$' | sort -u)
    if [ "$bad" -ne 0 ]; then
      exit 1
    fi

    runHook postInstallCheck
  '';

  meta = {
    description = "The SE98kde action icons in the colors of a win-classic-theme scheme";
    homepage = "https://github.com/menduz/win-classic-theme";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
  };
}
