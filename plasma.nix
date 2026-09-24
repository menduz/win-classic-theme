# The Plasma style: the panel, its task buttons, the pop-up windows and the
# tool tips. KSvg draws each part as a frame of nine elements. pixelmap.nix
# writes the SVG files. These are the characters of the pixel maps:
#
#     " " no pixel      b  window color     h  highlight     s  shadow
#     k   border        c  selection        y  tool tip
{
  lib,
  name,
  colors,
}:
let
  inherit (import ./pixelmap.nix { inherit lib; }) svgFile;

  palette = {
    b = colors.bgcolor;
    h = colors.highlight;
    s = colors.shadow;
    k = colors.border;
    c = colors.selectedbg;
    y = colors.tooltipbg;
  };

  # The nine elements of a frame, with the prefix of KSvg. A margin hint makes
  # the space inside the frame larger than the edges.
  frame =
    prefix: parts: margins:
    let
      id = part: if prefix == "" then part else "${prefix}-${part}";
      hint = side: width: height: {
        id = id "hint-${side}-margin";
        rows = lib.replicate height (lib.fixedWidthString width " " "");
      };
    in
    lib.mapAttrsToList (part: rows: {
      id = id part;
      inherit rows;
    }) parts
    ++ lib.optionals (margins != null) [
      (hint "left" margins.left 1)
      (hint "right" margins.right 1)
      (hint "top" 1 margins.top)
      (hint "bottom" 1 margins.bottom)
    ];

  withPalette = map (e: e // { inherit palette; });

  # A raised button, as the buttons of the title bar.
  raised = {
    topleft = [
      "hh"
      "hb"
    ];
    top = [
      "h"
      "b"
    ];
    topright = [
      "hk"
      "sk"
    ];
    left = [ "hb" ];
    center = [ "b" ];
    right = [ "sk" ];
    bottomleft = [
      "hs"
      "kk"
    ];
    bottom = [
      "s"
      "k"
    ];
    bottomright = [
      "sk"
      "kk"
    ];
  };

  # A pressed button. Windows shows the button of the active window with a
  # pattern of highlight and window color.
  pressed = {
    topleft = [
      "kk"
      "ks"
    ];
    top = [
      "k"
      "s"
    ];
    topright = [
      "kk"
      "sh"
    ];
    left = [ "ks" ];
    center = [
      "hb"
      "bh"
    ];
    right = [ "bh" ];
    bottomleft = [
      "kh"
      "hh"
    ];
    bottom = [
      "b"
      "h"
    ];
    bottomright = [
      "bh"
      "hh"
    ];
  };

  # The edge of a window, as the two outer rows of the frame of xfwm4/.
  window = {
    topleft = [
      "bb"
      "bh"
    ];
    top = [
      "b"
      "h"
    ];
    topright = [
      "bk"
      "sk"
    ];
    left = [ "bh" ];
    center = [ "b" ];
    right = [ "sk" ];
    bottomleft = [
      "bs"
      "kk"
    ];
    bottom = [
      "s"
      "k"
    ];
    bottomright = [
      "sk"
      "kk"
    ];
  };

  # Empty pixels around a frame. The task manager fills the full height of the
  # panel, thus a task button keeps its gaps inside its own frame.
  padFrame =
    {
      top,
      bottom,
      right,
    }:
    lib.mapAttrs (
      part: rows:
      let
        blank = width: lib.fixedWidthString width " " "";
        wide = if lib.hasSuffix "right" part then map (row: row + blank right) rows else rows;
        width = lib.stringLength (lib.head wide);
      in
      lib.optionals (lib.hasPrefix "top" part) (lib.replicate top (blank width))
      ++ wide
      ++ lib.optionals (lib.hasPrefix "bottom" part) (lib.replicate bottom (blank width))
    );

  # A task button is 22 rows high in a panel of 28 rows: 4 rows of panel are
  # above it and 2 rows are below it. Three columns keep two buttons apart. The
  # icon is 16 pixels.
  taskPad = padFrame {
    top = 4;
    bottom = 2;
    right = 3;
  };

  taskMargins = {
    left = 4;
    right = 7;
    top = 7;
    bottom = 5;
  };

  tasks = svgFile (
    withPalette (
      lib.concatMap (prefix: frame prefix (taskPad raised) taskMargins) [
        ""
        "normal"
        "minimized"
        "attention"
      ]
      ++ frame "focus" (taskPad pressed) taskMargins
      ++ [
        {
          id = "focus-hint-tile-center";
          rows = [ " " ];
        }
      ]
    )
  );

  # The panel is a raised bar.
  panel = svgFile (
    withPalette (
      frame "" window {
        left = 2;
        right = 2;
        top = 4;
        bottom = 2;
      }
    )
  );

  dialog = svgFile (
    withPalette (
      frame "" window {
        left = 3;
        right = 3;
        top = 3;
        bottom = 3;
      }
    )
  );

  tooltip = svgFile (
    withPalette (
      frame ""
        {
          topleft = [ "k" ];
          top = [ "k" ];
          topright = [ "k" ];
          left = [ "k" ];
          center = [ "y" ];
          right = [ "k" ];
          bottomleft = [ "k" ];
          bottom = [ "k" ];
          bottomright = [ "k" ];
        }
        {
          left = 3;
          right = 3;
          top = 2;
          bottom = 2;
        }
    )
  );

  # The colors of the text and of the lists. Plasma reads the groups of a KDE
  # color scheme.
  colorGroup = group: background: foreground: ''
    [Colors:${group}]
    BackgroundNormal=${background}
    BackgroundAlternate=${background}
    ForegroundNormal=${foreground}
    ForegroundInactive=${colors.disabledfg}
    ForegroundActive=${foreground}
    ForegroundLink=${colors.selectedbg}
    ForegroundVisited=${colors.selectedbg}
    ForegroundNegative=${foreground}
    ForegroundNeutral=${foreground}
    ForegroundPositive=${foreground}
    DecorationFocus=${colors.selectedbg}
    DecorationHover=${colors.selectedbg}
  '';
in
{
  "metadata.json" = builtins.toJSON {
    KPlugin = {
      Id = name;
      Name = name;
      Description = "A Windows 9x panel";
      License = "GPL-3.0-only";
    };
    X-Plasma-API-Minimum-Version = "6.0";
  };

  colors = lib.concatStringsSep "\n" [
    (colorGroup "Window" colors.bgcolor colors.fgcolor)
    (colorGroup "Button" colors.bgcolor colors.fgcolor)
    (colorGroup "Header" colors.bgcolor colors.fgcolor)
    (colorGroup "Complementary" colors.bgcolor colors.fgcolor)
    (colorGroup "View" colors.basecolor colors.basefg)
    (colorGroup "Selection" colors.selectedbg colors.selectedtext)
    (colorGroup "Tooltip" colors.tooltipbg colors.tooltipfg)
  ];

  "widgets/panel-background.svg" = panel;
  "widgets/tasks.svg" = tasks;
  "widgets/tooltip.svg" = tooltip;
  "dialogs/background.svg" = dialog;
}
