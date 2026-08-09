# Color schemes for the win98 theme. Each value is a system color of Windows.
# The source of the colors is this gist:
# https://gist.github.com/zaxbux/64b5a88e2e390fb8f8d24eb1736f71e0
#
# Select a scheme with the `preset` argument of `default.nix`. The set is also
# available as `passthru.presets` on the built theme.
#
# This table shows the Windows name of each color of the theme:
#
# | Theme color         | Windows color           |
# | ------------------- | ----------------------- |
# | bgcolor             | Control                 |
# | fgcolor             | ControlText             |
# | border              | ControlDarkDark         |
# | selectedbg          | Highlight               |
# | selectedtext        | HighlightText           |
# | activetitle         | ActiveCaption           |
# | activetitle1        | GradientActiveCaption   |
# | activetitletext     | ActiveCaptionText       |
# | inactivetitle       | InactiveCaption         |
# | inactivetitletext   | InactiveCaptionText     |
# | basecolor           | Window                  |
# | basefg              | WindowText              |
# | buttonscolor        | ControlText             |
# | highlight           | ControlLightLight       |
# | shadow              | ControlDark             |
# | disabledfg          | GrayText                |
#
# Windows has more colors than the theme. The theme uses one color for the
# window frame and for the dark edge of a widget, so `border` takes
# ControlDarkDark. The theme has no second color for the inactive title bar, so
# GradientInactiveCaption is not in use. A preset does not give `tooltipbg` or
# `tooltipfg`, so every scheme keeps the same warm tool tip. Give these two
# colors in `colors` to use Info and InfoText.
#
# A preset gives `highlight`, `shadow` and `disabledfg`, because Windows gives
# these three colors. The build then does not calculate them from `bgcolor`.
{
  # The first two schemes of the Appearance dialog of Windows.
  # Windows XP "Classic (Classic)", the scheme of Windows 95 and of Windows 98.
  windows-classic = {
    bgcolor = "#c0c0c0";
    fgcolor = "#000000";
    border = "#000000";
    selectedbg = "#000080";
    selectedtext = "#ffffff";
    activetitle = "#000080";
    activetitle1 = "#1084d0";
    activetitletext = "#ffffff";
    inactivetitle = "#808080";
    inactivetitletext = "#c0c0c0";
    basecolor = "#ffffff";
    basefg = "#000000";
    buttonscolor = "#000000";
    highlight = "#ffffff";
    shadow = "#808080";
    disabledfg = "#808080";
  };
  # Windows XP "Classic (Standard)", the scheme of Windows 2000 and of Windows XP.
  windows-standard = {
    bgcolor = "#d4d0c8";
    fgcolor = "#000000";
    border = "#404040";
    selectedbg = "#0a246a";
    selectedtext = "#ffffff";
    activetitle = "#0a246a";
    activetitle1 = "#a6caf0";
    activetitletext = "#ffffff";
    inactivetitle = "#808080";
    inactivetitletext = "#d4d0c8";
    basecolor = "#ffffff";
    basefg = "#000000";
    buttonscolor = "#000000";
    highlight = "#ffffff";
    shadow = "#808080";
    disabledfg = "#808080";
  };

  # The dark scheme of this theme, the Redmond97 SE "Dusk Red" colors. It is
  # the scheme that `default.nix` builds without a preset. Windows has no dark
  # scheme, so this one gives no `highlight`, no `shadow` and no `disabledfg`:
  # the build calculates the three from `bgcolor`.
  dark = {
    bgcolor = "#303131";
    fgcolor = "#dddddd";
    border = "#060606";
    selectedbg = "#6c2525";
    selectedtext = "#dddddd";
    activetitle = "#6c2525";
    activetitle1 = "#6c2525";
    activetitletext = "#dddddd";
    inactivetitle = "#434444";
    inactivetitletext = "#8d8d8d";
    basecolor = "#1e2426";
    basefg = "#dddddd";
    buttonscolor = "#dddddd";
  };

  # The other classic schemes of Windows XP, in alphabetical order.
  # Windows XP "Brick".
  brick = {
    bgcolor = "#c2bfa5";
    fgcolor = "#000000";
    border = "#000000";
    selectedbg = "#8d8961";
    selectedtext = "#ffffff";
    activetitle = "#800000";
    activetitle1 = "#b07440";
    activetitletext = "#e1e0d2";
    inactivetitle = "#8d8961";
    inactivetitletext = "#e1e0d2";
    basecolor = "#ffffff";
    basefg = "#000000";
    buttonscolor = "#000000";
    highlight = "#e1e0d2";
    shadow = "#8d8961";
    disabledfg = "#8d8961";
  };
  # Windows XP "Desert".
  desert = {
    bgcolor = "#d5ccbb";
    fgcolor = "#000000";
    border = "#000000";
    selectedbg = "#008080";
    selectedtext = "#ffffff";
    activetitle = "#008080";
    activetitle1 = "#84bdaa";
    activetitletext = "#ffffff";
    inactivetitle = "#a28d68";
    inactivetitletext = "#ffffff";
    basecolor = "#ffffff";
    basefg = "#000000";
    buttonscolor = "#000000";
    highlight = "#eae6dd";
    shadow = "#a28d68";
    disabledfg = "#a28d68";
  };
  # Windows XP "Eggplant".
  eggplant = {
    bgcolor = "#90b0a8";
    fgcolor = "#000000";
    border = "#000000";
    selectedbg = "#588078";
    selectedtext = "#ffffff";
    activetitle = "#588078";
    activetitle1 = "#834b83";
    activetitletext = "#ffffff";
    inactivetitle = "#90b0a8";
    inactivetitletext = "#588078";
    basecolor = "#ffffff";
    basefg = "#000000";
    buttonscolor = "#000000";
    highlight = "#c8d8d8";
    shadow = "#588078";
    disabledfg = "#588078";
  };
  # Windows XP "Lilac".
  lilac = {
    bgcolor = "#aea8d9";
    fgcolor = "#000000";
    border = "#000000";
    selectedbg = "#5a4eb1";
    selectedtext = "#ffffff";
    activetitle = "#5a4eb1";
    activetitle1 = "#b68fcb";
    activetitletext = "#ffffff";
    inactivetitle = "#808080";
    inactivetitletext = "#ffffff";
    basecolor = "#ffffff";
    basefg = "#000000";
    buttonscolor = "#000000";
    highlight = "#d8d5ec";
    shadow = "#5a4eb1";
    disabledfg = "#5a4eb1";
  };
  # Windows XP "Maple".
  maple = {
    bgcolor = "#e6d8ae";
    fgcolor = "#000000";
    border = "#000000";
    selectedbg = "#c6a646";
    selectedtext = "#000000";
    activetitle = "#800000";
    activetitle1 = "#c09c38";
    activetitletext = "#ffffff";
    inactivetitle = "#c6a646";
    inactivetitletext = "#f2ecd7";
    basecolor = "#ffffff";
    basefg = "#000000";
    buttonscolor = "#000000";
    highlight = "#f2ecd7";
    shadow = "#c6a646";
    disabledfg = "#c6a646";
  };
  # Windows XP "Marine".
  marine = {
    bgcolor = "#88c0b8";
    fgcolor = "#000000";
    border = "#000000";
    selectedbg = "#000080";
    selectedtext = "#ffffff";
    activetitle = "#000080";
    activetitle1 = "#18b4c0";
    activetitletext = "#ffffff";
    inactivetitle = "#489088";
    inactivetitletext = "#c0c0c0";
    basecolor = "#c8e0d8";
    basefg = "#000000";
    buttonscolor = "#000000";
    highlight = "#c8e0d8";
    shadow = "#489088";
    disabledfg = "#489088";
  };
  # Windows XP "Plum".
  plum = {
    bgcolor = "#a89890";
    fgcolor = "#000000";
    border = "#000000";
    selectedbg = "#008080";
    selectedtext = "#d8d0c8";
    activetitle = "#484060";
    activetitle1 = "#a084b8";
    activetitletext = "#ffffff";
    inactivetitle = "#786058";
    inactivetitletext = "#a89890";
    basecolor = "#d8d0c8";
    basefg = "#000000";
    buttonscolor = "#000000";
    highlight = "#d8d0c8";
    shadow = "#786058";
    disabledfg = "#786058";
  };
  # Windows XP "Pumpkin".
  pumpkin = {
    bgcolor = "#ecd59d";
    fgcolor = "#000000";
    border = "#000000";
    selectedbg = "#800080";
    selectedtext = "#ffffff";
    activetitle = "#d7a52f";
    activetitle1 = "#e0cc88";
    activetitletext = "#ffffff";
    inactivetitle = "#a0a0a4";
    inactivetitletext = "#f5eacf";
    basecolor = "#ffffff";
    basefg = "#000000";
    buttonscolor = "#000000";
    highlight = "#f5eacf";
    shadow = "#d7a52f";
    disabledfg = "#d7a52f";
  };
  # Windows XP "Rainy Day".
  rainy-day = {
    bgcolor = "#8399b1";
    fgcolor = "#000000";
    border = "#000000";
    selectedbg = "#4f657d";
    selectedtext = "#ffffff";
    activetitle = "#4f657d";
    activetitle1 = "#80b4d0";
    activetitletext = "#ffffff";
    inactivetitle = "#808080";
    inactivetitletext = "#c1ccd9";
    basecolor = "#ffffff";
    basefg = "#000000";
    buttonscolor = "#000000";
    highlight = "#c1ccd9";
    shadow = "#4f657d";
    disabledfg = "#4f657d";
  };
  # Windows XP "Red White Blue".
  red-white-blue = {
    bgcolor = "#c0c0c0";
    fgcolor = "#000000";
    border = "#000000";
    selectedbg = "#800000";
    selectedtext = "#ffffff";
    activetitle = "#800000";
    activetitle1 = "#0010a8";
    activetitletext = "#ffffff";
    inactivetitle = "#808080";
    inactivetitletext = "#c0c0c0";
    basecolor = "#ffffff";
    basefg = "#000000";
    buttonscolor = "#000000";
    highlight = "#ffffff";
    shadow = "#808080";
    disabledfg = "#808080";
  };
  # Windows XP "Rose".
  rose = {
    bgcolor = "#cfafb7";
    fgcolor = "#000000";
    border = "#000000";
    selectedbg = "#9f6070";
    selectedtext = "#ffffff";
    activetitle = "#9f6070";
    activetitle1 = "#d8ccd0";
    activetitletext = "#ffffff";
    inactivetitle = "#a0a0a4";
    inactivetitletext = "#7d7d7d";
    basecolor = "#ffffff";
    basefg = "#000000";
    buttonscolor = "#000000";
    highlight = "#e7d8dc";
    shadow = "#9f6070";
    disabledfg = "#9f6070";
  };
  # Windows XP "Slate".
  slate = {
    bgcolor = "#9db9c8";
    fgcolor = "#000000";
    border = "#000000";
    selectedbg = "#558097";
    selectedtext = "#ffffff";
    activetitle = "#558097";
    activetitle1 = "#88b8d8";
    activetitletext = "#ffffff";
    inactivetitle = "#808080";
    inactivetitletext = "#c0c0c0";
    basecolor = "#ffffff";
    basefg = "#000000";
    buttonscolor = "#000000";
    highlight = "#cedce3";
    shadow = "#558097";
    disabledfg = "#558097";
  };
  # Windows XP "Spruce".
  spruce = {
    bgcolor = "#a2c8a9";
    fgcolor = "#000000";
    border = "#000000";
    selectedbg = "#599764";
    selectedtext = "#ffffff";
    activetitle = "#599764";
    activetitle1 = "#98c8e8";
    activetitletext = "#ffffff";
    inactivetitle = "#808080";
    inactivetitletext = "#d0e3d3";
    basecolor = "#ffffff";
    basefg = "#000000";
    buttonscolor = "#000000";
    highlight = "#d0e3d3";
    shadow = "#599764";
    disabledfg = "#599764";
  };
  # Windows XP "Storm".
  storm = {
    bgcolor = "#c0c0c0";
    fgcolor = "#000000";
    border = "#000000";
    selectedbg = "#800080";
    selectedtext = "#ffffff";
    activetitle = "#800080";
    activetitle1 = "#388cb0";
    activetitletext = "#ffffff";
    inactivetitle = "#808080";
    inactivetitletext = "#c0c0c0";
    basecolor = "#ffffff";
    basefg = "#000000";
    buttonscolor = "#000000";
    highlight = "#ffffff";
    shadow = "#808080";
    disabledfg = "#808080";
  };
  # Windows XP "Teal".
  teal = {
    bgcolor = "#c0c0c0";
    fgcolor = "#000000";
    border = "#000000";
    selectedbg = "#008080";
    selectedtext = "#ffffff";
    activetitle = "#008080";
    activetitle1 = "#00ccd8";
    activetitletext = "#ffffff";
    inactivetitle = "#808080";
    inactivetitletext = "#fffbf0";
    basecolor = "#ffffff";
    basefg = "#000000";
    buttonscolor = "#000000";
    highlight = "#ffffff";
    shadow = "#808080";
    disabledfg = "#808080";
  };
  # Windows XP "Wheat".
  wheat = {
    bgcolor = "#dedea0";
    fgcolor = "#000000";
    border = "#000000";
    selectedbg = "#808000";
    selectedtext = "#ffffff";
    activetitle = "#808000";
    activetitle1 = "#c8b048";
    activetitletext = "#ffffff";
    inactivetitle = "#bcbc41";
    inactivetitletext = "#ffffff";
    basecolor = "#ffffff";
    basefg = "#000000";
    buttonscolor = "#000000";
    highlight = "#eeeed0";
    shadow = "#bcbc41";
    disabledfg = "#bcbc41";
  };

  # The three Luna schemes of Windows XP.
  # Windows XP "Luna", the blue scheme.
  luna = {
    bgcolor = "#ece9d8";
    fgcolor = "#000000";
    border = "#716f64";
    selectedbg = "#316ac5";
    selectedtext = "#ffffff";
    activetitle = "#0054e3";
    activetitle1 = "#3d95ff";
    activetitletext = "#ffffff";
    inactivetitle = "#7a96df";
    inactivetitletext = "#d8e4f8";
    basecolor = "#ffffff";
    basefg = "#000000";
    buttonscolor = "#000000";
    highlight = "#ffffff";
    shadow = "#aca899";
    disabledfg = "#aca899";
  };
  # Windows XP "Luna (Silver)", the gray scheme.
  luna-silver = {
    bgcolor = "#e0dfe3";
    fgcolor = "#000000";
    border = "#716f64";
    selectedbg = "#b2b4bf";
    selectedtext = "#000000";
    activetitle = "#c0c0c0";
    activetitle1 = "#c8c8c8";
    activetitletext = "#0e1010";
    inactivetitle = "#ffffff";
    inactivetitletext = "#a2a1a1";
    basecolor = "#ffffff";
    basefg = "#000000";
    buttonscolor = "#000000";
    highlight = "#ffffff";
    shadow = "#9d9da1";
    disabledfg = "#aca899";
  };
  # Windows XP "Luna (Olive Green)", the green scheme.
  luna-olive = {
    bgcolor = "#ece9d8";
    fgcolor = "#000000";
    border = "#716f64";
    selectedbg = "#93a070";
    selectedtext = "#ffffff";
    activetitle = "#8ba169";
    activetitle1 = "#c6d2a2";
    activetitletext = "#ffffff";
    inactivetitle = "#d4d6ba";
    inactivetitletext = "#ffffff";
    basecolor = "#ffffff";
    basefg = "#000000";
    buttonscolor = "#000000";
    highlight = "#ffffff";
    shadow = "#aca899";
    disabledfg = "#aca899";
  };
}
