# One color scheme as a complete theme: share/themes/<name>, the KDE themes,
# and the icon theme share/icons/<name> of icons.nix.
#
# callPackage gives the build tools. The result is a function that takes the
# colors of the scheme. It knows no preset: lib.nix gives the colors of a
# preset.
{
  lib,
  stdenv,
  callPackage,
  imagemagick,
}:
let
  mkIcons = callPackage ./icons.nix { };
in
{
  name ? "win-classic-theme",

  # System colors of Windows. A color that is not here takes the value of the
  # default scheme below ("Dusk Red").
  colors ? { },

  titlebarButtons ? {
    minimize = true;
    maximize = true;
  },

  # Style sheet rules that go at the end of the GTK3 style sheet of the theme.
  extraGtk3Css ? "",
}:
let
  cfg = {
    # 3D objects
    bgcolor = "#303131";
    fgcolor = "#dddddd";
    border = "#060606";

    # Highlight
    selectedbg = "#6c2525";
    selectedtext = "#dddddd";

    # Active title bar
    activetitle = "#6c2525";
    activetitle1 = "#6c2525";
    activetitletext = "#dddddd";

    # Inactive title bar
    inactivetitle = "#434444";
    inactivetitletext = "#8d8d8d";

    # Text view boxes
    basecolor = "#1e2426";
    basefg = "#dddddd";

    # Tool tips. A tool tip is a light box in every scheme, as in Windows.
    tooltipbg = "#ffe0a8";
    tooltipfg = "#000000";

    # Window button glyphs
    buttonscolor = "#dddddd";

    # The desktop below the windows. Only a window manager that reads
    # xfwm4/themerc (kwm) and Wine use it.
    desktop = "#29272b";

    # The 3D edges and the disabled text are calculated from bgcolor. A scheme
    # that gives `highlight`, `shadow` or `disabledfg` stops the calculation of
    # that color.
    highlightMultiplier = 1.3;
    shadowMultiplier = 0.7;

    # Amount of each channel to add to the calculated edges. Range -1 to 1.
    highlightGain = [
      0.1
      0.1
      0.1
    ];
    shadowGain = [
      0.0
      0.0
      0.0
    ];
  }
  // colors;

  hexValue = {
    "0" = 0;
    "1" = 1;
    "2" = 2;
    "3" = 3;
    "4" = 4;
    "5" = 5;
    "6" = 6;
    "7" = 7;
    "8" = 8;
    "9" = 9;
    "a" = 10;
    "b" = 11;
    "c" = 12;
    "d" = 13;
    "e" = 14;
    "f" = 15;
    "A" = 10;
    "B" = 11;
    "C" = 12;
    "D" = 13;
    "E" = 14;
    "F" = 15;
  };

  toRgb =
    hex:
    let
      h = lib.removePrefix "#" hex;
      nibble = i: hexValue.${builtins.substring i 1 h};
    in
    [
      (nibble 0 * 16 + nibble 1)
      (nibble 2 * 16 + nibble 3)
      (nibble 4 * 16 + nibble 5)
    ];

  toHex =
    n:
    let
      digits = "0123456789abcdef";
    in
    builtins.substring (n / 16) 1 digits + builtins.substring (lib.mod n 16) 1 digits;

  toColor = rgb: "#" + lib.concatMapStrings toHex rgb;

  # Truncate towards zero.
  trunc = x: if x < 0 then 0 - builtins.floor (0 - x) else builtins.floor x;
  cap =
    n:
    if n > 255 then
      255
    else if n < 1 then
      0
    else
      n;

  bgRgb = toRgb cfg.bgcolor;

  # A 3D edge is the window color at a different brightness, plus a gain.
  edge =
    multiplier: gain:
    toColor (
      lib.zipListsWith (ch: g: cap (cap (trunc (ch * multiplier)) + trunc (255 * g))) bgRgb gain
    );

  # Windows gives these three colors, so a scheme can give them too. The build
  # calculates a color that the scheme does not give.
  highlight = cfg.highlight or (edge cfg.highlightMultiplier cfg.highlightGain);
  shadow = cfg.shadow or (edge cfg.shadowMultiplier cfg.shadowGain);
  # Disabled text sits between the text and the window, thus it stays legible
  # on a light window and on a dark one.
  disabledfg =
    cfg.disabledfg or (toColor (lib.zipListsWith (a: b: (a + b) / 2) (toRgb cfg.fgcolor) bgRgb));
  # Chromium draws its address bar with no 3D edge. A dark text box on a dark
  # window then looks the same as the tabs, so the address bar of a dark
  # scheme gets a darker box.
  sum = lib.foldl' builtins.add 0;
  darkBase = sum (toRgb cfg.basecolor) < sum bgRgb;
  chromiumbase =
    cfg.chromiumbase
      or (if darkBase then toColor (map (ch: trunc (ch * 0.4)) (toRgb cfg.basecolor)) else cfg.basecolor);
  # Brave paints the corners of its toolbar in the header color of its own
  # palette, and no theme can change that color. The tab strip gets the same
  # color, so that the corners do not show. These are the colors of Brave with
  # no theme color, in the dark mode and in the light mode.
  chromiumframe = cfg.chromiumframe or (if darkBase then "#1f1f23" else "#e4e4e5");

  buttons = {
    minimize = true;
    maximize = true;
  }
  // titlebarButtons;

  decorationLayout =
    "icon:"
    + lib.concatStringsSep "," (
      lib.optional buttons.minimize "minimize" ++ lib.optional buttons.maximize "maximize" ++ [ "close" ]
    );

  # Xfwm4 names the buttons with letters: O menu, H hide, M maximize, C close.
  xfwmButtons =
    "O|" + lib.optionalString buttons.minimize "H" + lib.optionalString buttons.maximize "M" + "C";

  # Every `@name@` token that the theme sources contain.
  tokens = {
    inherit (cfg)
      bgcolor
      fgcolor
      border
      selectedbg
      selectedtext
      activetitle
      activetitle1
      activetitletext
      inactivetitle
      inactivetitletext
      basecolor
      basefg
      tooltipbg
      tooltipfg
      buttonscolor
      desktop
      ;
    inherit
      highlight
      shadow
      disabledfg
      chromiumbase
      chromiumframe
      ;
    themename = name;
    decorationlayout = decorationLayout;
    xfwmbuttons = xfwmButtons;
  };

  substFlags = lib.concatStringsSep " " (
    lib.mapAttrsToList (token: value: "--subst-var-by ${token} '${value}'") tokens
  );

  # Wine wants decimal triplets.
  wine = hex: lib.concatMapStringsSep " " toString (toRgb hex);

  wineReg = ''
    Windows Registry Editor Version 5.00
    [HKEY_CURRENT_USER\Control Panel\Colors]
    "ActiveTitle"="${wine cfg.activetitle}"
    "Background"="${wine cfg.desktop}"
    "Hilight"="${wine cfg.selectedbg}"
    "HilightText"="${wine cfg.selectedtext}"
    "TitleText"="${wine cfg.activetitletext}"
    "Window"="${wine cfg.basecolor}"
    "WindowText"="${wine cfg.basefg}"
    "Scrollbar"="${wine shadow}"
    "InactiveTitle"="${wine cfg.inactivetitle}"
    "Menu"="${wine cfg.bgcolor}"
    "WindowFrame"="${wine cfg.border}"
    "MenuText"="${wine cfg.fgcolor}"
    "ActiveBorder"="${wine cfg.bgcolor}"
    "InactiveBorder"="${wine cfg.bgcolor}"
    "ButtonFace"="${wine cfg.bgcolor}"
    "ButtonShadow"="${wine shadow}"
    "GrayText"="${wine cfg.inactivetitletext}"
    "ButtonText"="${wine cfg.fgcolor}"
    "InactiveTitleText"="${wine cfg.inactivetitletext}"
    "ButtonHilight"="${wine highlight}"
    "ButtonDkShadow"="${wine shadow}"
    "ButtonLight"="${wine cfg.bgcolor}"
    "InfoText"="${wine cfg.tooltipfg}"
    "InfoWindow"="${wine cfg.tooltipbg}"
    "GradientActiveTitle"="${wine cfg.activetitle}"
    "GradientInactiveTitle"="${wine cfg.inactivetitle}"
  '';

  schemeColors = cfg // {
    inherit highlight shadow disabledfg;
  };

  aurorae = import ./aurorae.nix {
    inherit lib name;
    colors = schemeColors;
  };

  plasma = import ./plasma.nix {
    inherit lib name;
    colors = schemeColors;
  };

  icons = mkIcons {
    inherit name;
    inherit (cfg) fgcolor selectedbg;
  };

  # Write a set of generated files below a directory.
  installFiles =
    dir: files:
    lib.concatStrings (
      lib.mapAttrsToList (file: text: ''
        install -D -m 644 ${builtins.toFile (baseNameOf file) text} ${dir}/${lib.escapeShellArg file}
      '') files
    );
in
stdenv.mkDerivation {
  pname = name;
  version = "20260803";

  # The theme is the images, the style sheets and the metadata. Only these go
  # into the source. Thus a new screenshot, a new line in the README or a
  # change to the icons does not build the theme again.
  src = builtins.path {
    name = "win-classic-theme";
    path = ./.;
    filter =
      path: type:
      let
        top = lib.head (lib.splitString "/" (lib.removePrefix (toString ./. + "/") (toString path)));
      in
      builtins.elem top [
        "gtk-2.0"
        "gtk-3.0"
        "gtk-4.0"
        "images"
        "index.theme"
        "LICENSE"
        "rofi"
        "xfwm4"
      ];
  };

  nativeBuildInputs = [ imagemagick ];

  postPatch = ''
    find . -xtype l -delete
    for file in gtk-2.0/gtkrc gtk-3.0/gtk.css gtk-3.0/settings.ini gtk-4.0/settings.ini \
                index.theme xfwm4/themerc xfwm4/*.xpm rofi/win-classic.rasi; do
      substituteInPlace "$file" ${substFlags}
    done
  '';

  # Each widget in images/ is a stack of grayscale layers. Every layer uses
  # #ff00fa as the placeholder color, and gets one color of the scheme.
  buildPhase = ''
    runHook preBuild

    bgcolor='${cfg.bgcolor}'
    fgcolor='${cfg.fgcolor}'
    basecolor='${cfg.basecolor}'
    basefg='${cfg.basefg}'
    selectedbg='${cfg.selectedbg}'
    activetitle='${cfg.activetitle}'
    activetitle1='${cfg.activetitle1}'
    border='${cfg.border}'
    highlight='${highlight}'
    shadow='${shadow}'
    disabledfg='${disabledfg}'

    # paint <glob> <color> <output>. Does nothing if the layer is absent.
    paint() {
      local src="" candidate
      for candidate in $1; do
        if [ -e "$candidate" ]; then src=$candidate; break; fi
      done
      [ -n "$src" ] || return 0
      magick "$src" -fuzz 15% -fill "$2" -opaque '#ff00fa' "$3"
      layers+=(-page +0+0 "$3")
    }

    cd images
    for dir in */; do
      name=''${dir%/}
      # These three hold finished images, not layers.
      case "$name" in assets | progressbar | null) continue ;; esac

      cd "$name"
      layers=()
      # An `ins` widget is insensitive. It uses the window color, not the base color.
      case "$name" in
        *ins*) fillbase="$bgcolor" ;;
        *) fillbase="$basecolor" ;;
      esac
      # The call order is the stack order.
      paint '*background.png'     "$bgcolor"    background.png
      paint '*highlight.png'      "$highlight"  highlight.png
      paint '*shadow.png'         "$shadow"     shadow.png
      paint '*border.png'         "$border"     border.png
      paint '*base.png'           "$fillbase"   base.png
      paint '*check.png'          "$basefg"     check.png
      paint '*_aa.png'            "$bgcolor"    aa.png
      paint '*_text.png'          "$fgcolor"    text.png
      paint '*_text_disabled.png' "$disabledfg" text_disabled.png
      magick -background none "''${layers[@]}" -layers flatten "../assets/$name.png"
      cd ..
    done

    cd assets
    # The layers are grayscale. Make the results RGB to stop ImageMagick warnings.
    magick mogrify -colorspace sRGB -colors 256 *.png

    # One arrow gives the four directions.
    magick arrow.png       -rotate 90 arrow_right.png
    magick arrow_right.png -rotate 90 arrow_down.png
    magick arrow_down.png  -rotate 90 arrow_left.png
    magick arrow_left.png  -rotate 90 arrow_up.png
    rm arrow.png
    for arrow in arrow*.png; do
      magick "$arrow" -fuzz 15% -fill "$disabledfg" -opaque "$basefg" "''${arrow%.*}_ins.png"
    done

    # The caret of the drop down button. GTK draws an icon at the size of its
    # box, thus the image has the size of the box that gtk-arrows.css gives.
    magick arrow_down.png     -crop 15x17+1+0 +repage caret_down.png
    magick arrow_down_ins.png -crop 15x17+1+0 +repage caret_down_ins.png

    for direction in up right down left; do
      magick -background none -page +0+0 scrollbar_button.png \
        -page +0+0 "arrow_$direction.png" -layers flatten "scroll_''${direction}_button.png"
      magick -background none -page +0+0 scrollbar_button_active.png \
        -page +0+0 "arrow_$direction.png" -layers flatten "scroll_''${direction}_button_active.png"
    done

    # The top tab gives the other three sides.
    magick tab.png                -flip tab_left.png
    magick tab_checked.png        -flip tab_left_checked.png
    magick tab_gap.png            -flip tab_gap_left.png
    magick tab_left.png           -rotate 90 tab_left.png
    magick tab_left_checked.png   -rotate 90 tab_left_checked.png
    magick tab_gap_left.png       -rotate 90 tab_gap_left.png
    cp tab_gap_left.png tab_gap_right.png
    magick tab_bottom.png         -flip tab_right.png
    magick tab_bottom_checked.png -flip tab_right_checked.png
    magick tab_right.png          -rotate 90 tab_right.png
    magick tab_right_checked.png  -rotate 90 tab_right_checked.png
    mv tab.png tab_top.png
    mv tab_checked.png tab_top_checked.png
    cp tab_gap.png tab_gap_top.png
    mv tab_gap.png tab_gap_bottom.png

    magick -background none -page +0+0 switch_button.png     -page +0+0 switch_off.png -layers flatten switch.png
    magick -background none -page +0+0 switch_button_ins.png -page +0+0 switch_off.png -layers flatten switch_ins.png
    magick -background none -page +0+0 switch_button.png     -page +0+0 switch_on.png  -layers flatten switch_checked.png
    magick -background none -page +0+0 switch_button_ins.png -page +0+0 switch_on.png  -layers flatten switch_ins_checked.png
    rm switch_off.png switch_on.png switch_button.png switch_button_ins.png
    cd ..

    cp progressbar/*.png assets/
    cp assets/progressbar_horiz.png assets/menuitem.png
    cp null/null_image.png assets/null.png
    for selected in menuitem progressbar_horiz progressbar_vert; do
      magick "assets/$selected.png" -fuzz 15% -fill "$selectedbg" -opaque '#ff00fa' "assets/$selected.png"
    done

    # Side bar of the Xfce4 whisker menu.
    magick -size 27x1200 canvas:"$activetitle1" assets/side_canvas.png
    magick -size 27x600 gradient:"$activetitle"-"$activetitle1" assets/side_gradient.png
    magick -background none -page +0+0 assets/side_canvas.png -page +0+0 assets/side_gradient.png \
      -layers flatten assets/menu_side.png

    cd assets
    gtk3=../../gtk-3.0/assets
    mkdir -p "$gtk3" ../../gtk-2.0/assets
    cp tab*.png menu_side.png scrollbar_trough.png radio*.png c_box*.png arrow*.png \
       caret*.png switch*.png scroll_*_button.png warning.png "$gtk3"/
    cp menubar.png "$gtk3"/toolbar.png
    cp close_normal.png close_normal_small.png close_pressed.png close_pressed_small.png \
       maximize_normal.png maximize_pressed.png minimize_normal.png minimize_pressed.png \
       restore_normal.png restore_pressed.png "$gtk3"/
    mv scrollbar_button.png headerbox.png handle.png fm_toolbar.png "$gtk3"/

    # GTK2 takes everything that is left.
    mv *.png ../../gtk-2.0/assets/
    cd ../..
    rm -rf images

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    theme=$out/share/themes/${name}
    mkdir -p "$theme"/wine
    cp -r gtk-2.0 gtk-3.0 gtk-4.0 xfwm4 rofi index.theme LICENSE "$theme"/
    ${lib.optionalString (extraGtk3Css != "") ''
      cat ${builtins.toFile "extra-gtk3.css" extraGtk3Css} >>"$theme"/gtk-3.0/gtk.css
    ''}
    cp ${builtins.toFile "theme.reg" wineReg} "$theme"/wine/${name}.reg

    # The icon theme of the scheme has the name of the scheme. It inherits SE98.
    mkdir -p $out/share/icons
    ln -s ${icons}/share/icons/${name} $out/share/icons/${name}

    ${installFiles "$out/share/aurorae/themes/${name}" aurorae}
    ${installFiles "$out/share/plasma/desktoptheme/${name}" plasma}

    runHook postInstall
  '';

  # Every `url()` of a style sheet must point to a file, and no `@name@` token
  # may stay in the result. A relative URL takes the directory of its own
  # style sheet, thus a rule that moves from gtk-3.0/ to gtk-4.0/ loses its
  # images without a word.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    theme=$out/share/themes/${name}
    bad=0

    while read -r css; do
      dir=$(dirname "$css")
      while read -r ref; do
        case "$ref" in
          "" | resource:* | http:* | https:*) continue ;;
        esac
        if [ ! -e "$dir/$ref" ]; then
          echo "$css: url(\"$ref\") points to no file" >&2
          bad=1
        fi
      done < <(grep -o 'url("[^"]*")' "$css" | sed 's|url("||; s|")$||')
    done < <(find "$theme" -name '*.css')

    for token in ${lib.concatStringsSep " " (lib.attrNames tokens)}; do
      if grep -rln "@$token@" "$theme"; then
        echo "the token @$token@ stayed in the result" >&2
        bad=1
      fi
    done

    if [ "$bad" -ne 0 ]; then
      exit 1
    fi

    runHook postInstallCheck
  '';

  passthru = {
    inherit decorationLayout icons;
    # The name below share/themes. theme.nix reads it.
    themeName = name;
    # The colors of the scheme, with the calculated ones.
    colors = schemeColors;
    # A scheme is dark when its window color is dark.
    dark = lib.foldl' builtins.add 0 bgRgb < 384;
  };

  meta = {
    description = "Nostalgic windows theme for NixOS.";
    homepage = "https://github.com/menduz/win-classic-theme";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    maintainers = [ "github@menduz.com" ];
  };
}
