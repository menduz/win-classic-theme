# The SE98 icon theme. It inherits Chicago95, Papirus symbolic icons, and
# Adwaita in that order. The build puts the Papirus icons in a separate theme
# so they do not replace icons from SE98 or Chicago95.
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  chicago95,
  papirus-icon-theme,
  adwaita-icon-theme,
}:
stdenvNoCC.mkDerivation rec {
  pname = "se98";
  version = "0.2.16.2";

  src = fetchFromGitHub {
    owner = "nestoris";
    repo = "Win98SE";
    rev = "v${version}";
    hash = "sha256-4X8VYZN9Ycy34VQkitdm9Vs9ZEtMZASdVZLNNSQ1pnk=";
  };

  propagatedUserEnvPkgs = [
    chicago95
    adwaita-icon-theme
  ];

  dontBuild = true;

  # Some links of upstream end their target with a newline, and the file of
  # the target is there. The build repairs these links. Other links point to
  # icons that upstream does not hold, and the build removes them: Chicago95
  # gives those names. The build stops if a broken link stays.
  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/icons
    cp -r SE98 $out/share/icons/
    cd $out/share/icons/SE98
    rm -rf README.md file.data icons.html.sh sharp_icons.awk smooth_icons.awk \
      table_grassmunk template upd.sh win2k_icons.awk win98_icons.awk icon-theme.cache

    repaired=0
    removed=0
    while IFS= read -r -d "" link; do
      # The substitution drops the newlines at the end of the target.
      target=$(readlink "$link")
      if [ -e "$(dirname "$link")/$target" ]; then
        ln -sfn "$target" "$link"
        repaired=$((repaired + 1))
      else
        rm "$link"
        removed=$((removed + 1))
      fi
    done < <(find . -xtype l -print0)
    echo "se98: repaired $repaired links, removed $removed links to missing icons"

    # Upstream inherits hicolor, Adwaita and Breeze.
    grep -q '^Inherits=hicolor,Adwaita,breeze$' index.theme
    sed -i 's/^Inherits=.*/Inherits=Chicago95,SE98-Papirus-Symbolic,Adwaita/' index.theme

    papirus=${papirus-icon-theme}/share/icons/Papirus
    fallback=$out/share/icons/SE98-Papirus-Symbolic
    mkdir -p "$fallback"
    cd "$papirus"
    find . \( -path '*/symbolic/*' -o -name '*-symbolic.*' \) \
      \( -type f -o -type l \) \
      -exec cp -L --parents --no-preserve=mode -t "$fallback" {} +
    cp index.theme "$fallback/index.theme"
    directories=$(find "$fallback" -type f -name '*.svg' -printf '%h\n' \
      | sed "s|^$fallback/||" | sort -u | paste -sd, -)
    sed -i \
      -e 's/^Name=.*/Name=SE98 Papirus Symbolic/' \
      -e 's/^Inherits=.*/Inherits=Adwaita/' \
      -e "s|^Directories=.*|Directories=$directories|" \
      -e '/^ScaledDirectories=/d' \
      "$fallback/index.theme"

    cd "$out/share/icons/SE98"

    if [ -n "$(find . -xtype l)" ]; then
      echo "se98: broken links stay:" >&2
      find . -xtype l >&2
      exit 1
    fi
    runHook postInstall
  '';

  meta = {
    description = "SE98 Icon theme";
    homepage = "https://github.com/nestoris/Win98SE";
    license = [
      lib.licenses.gpl2Only
      lib.licenses.gpl3Only
    ];
    platforms = lib.platforms.linux;
    maintainers = [ "chris@oboe.email" ];
  };
}
