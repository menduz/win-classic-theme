{
  lib,
  stdenv,
  imagemagick,

  name ? "win-classic-theme",

  preset ? null,

  colors ? { },

  titlebarButtons ? {
    minimize = true;
    maximize = true;
  },
}:
let
  presets = import ./presets.nix;

  presetColors =
    if preset == null then
      { }
    else
      presets.${preset} or (throw ''
        win-classic-theme: the preset "${preset}" does not exist. The presets are:
        ${lib.concatStringsSep " " (lib.attrNames presets)}'');

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

    # The 3D edges and the disabled text are calculated from bgcolor. A scheme
    # that gives `highlight`, `shadow` or `disabledfg` stops the calculation of
    # that color.
    highlightMultiplier = 1.3;
    shadowMultiplier = 0.7;
    disabledFgMultiplier = 0.8;

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
  // presetColors
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
  disabledfg =
    cfg.disabledfg or (toColor (map (ch: cap (trunc (ch * cfg.disabledFgMultiplier))) bgRgb));

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
      ;
    inherit highlight shadow disabledfg;
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
    "Background"="${wine cfg.selectedbg}"
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
in
stdenv.mkDerivation {
  pname = name;
  version = "20260803";

  # The theme is the images, the style sheets and the metadata. The files of
  # the development environment are not part of it. Thus a new screenshot or a
  # new line in the README does not build the theme again.
  src = builtins.path {
    name = "win-classic-theme";
    path = ./.;
    filter =
      path: type:
      !(builtins.elem (baseNameOf path) [
        ".git"
        ".gitignore"
        "DEVELOPMENT.md"
        "demos"
        "dev"
        "flake.lock"
        "flake.nix"
        "README.md"
        "result"
        "screenshots"
      ]);
  };

  nativeBuildInputs = [ imagemagick ];

  postPatch = ''
    find . -xtype l -delete
    for file in gtk-2.0/gtkrc gtk-3.0/gtk.css gtk-3.0/settings.ini gtk-4.0/settings.ini \
                index.theme xfwm4/themerc xfwm4/*.xpm; do
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
    cp -r gtk-2.0 gtk-3.0 gtk-4.0 xfwm4 index.theme LICENSE "$theme"/
    cp ${builtins.toFile "theme.reg" wineReg} "$theme"/wine/${name}.reg

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

  passthru = { inherit decorationLayout presets; };

  meta = {
    description = "Nostalgic windows theme for NixOS.";
    homepage = "https://github.com/menduz/win-classic-theme";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    maintainers = [ "github@menduz.com" ];
  };
}
