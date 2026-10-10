# The functions that build win-classic-theme. The flake, the overlay and the
# modules call them:
#
#   mkScheme { name, colors, ... }          one scheme, from colors (scheme.nix)
#   mkIcons { name, fgcolor, selectedbg }   the icon theme of a scheme (icons.nix)
#   mkTheme { name, light, dark, contrast } three schemes in one theme (theme.nix)
#   mkThemeFrom { ... }                     a theme from presets and colors
#   presets                                 the color schemes of presets.nix
{
  lib,
  callPackage,
}:
let
  presets = import ./presets.nix;

  # `.override` on a result calls the function again with changed arguments.
  mkScheme = lib.makeOverridable (callPackage ./scheme.nix { });
  mkIcons = callPackage ./icons.nix { };
  mkTheme = lib.makeOverridable (callPackage ./theme.nix { });

  presetColors =
    preset:
    presets.${preset} or (throw ''
      win-classic-theme: the preset "${preset}" does not exist. The presets are:
      ${lib.concatStringsSep " " (lib.attrNames presets)}'');

  # The colors of `{ preset, colors }`. A color of `colors` wins over the same
  # color of the preset.
  colorsOf =
    scheme:
    (if scheme.preset or null == null then { } else presetColors scheme.preset) // scheme.colors or { };

  # A theme from three schemes. Each scheme is `{ preset, colors }` or null:
  #   - light and dark take each other, or the contrast scheme;
  #   - without a contrast scheme, the theme has none (refer to theme.nix).
  # `preset` and `colors` without `colorSchemes` give the light scheme, and
  # thus all three. Without any of these, the light scheme is
  # "windows-standard" and the dark scheme is "dark".
  #
  # Two schemes with the same colors are built one time.
  mkThemeFrom = lib.makeOverridable (
    {
      name ? "win-classic",
      colorSchemes ? { },
      preset ? null,
      colors ? { },
      titlebarButtons ? {
        minimize = true;
        maximize = true;
      },
      extraGtk3Css ? "",
    }:
    let
      given =
        if lib.any (s: s != null) (lib.attrValues colorSchemes) then
          {
            light = colorSchemes.light or null;
            dark = colorSchemes.dark or null;
            contrast = colorSchemes.contrast or null;
          }
        else if preset != null || colors != { } then
          {
            light = { inherit preset colors; };
            dark = null;
            contrast = null;
          }
        else
          {
            light.preset = "windows-standard";
            dark.preset = "dark";
            contrast = null;
          };

      givenColors = lib.mapAttrs (_: s: if s == null then null else colorsOf s) given;

      firstGiven = lib.findFirst (c: c != null) null;

      filled = {
        light = firstGiven [
          givenColors.light
          givenColors.dark
          givenColors.contrast
        ];
        dark = firstGiven [
          givenColors.dark
          givenColors.light
          givenColors.contrast
        ];
        contrast = givenColors.contrast;
      };

      order = lib.filter (s: filled.${s} != null) [
        "light"
        "dark"
        "contrast"
      ];

      # A scheme with the same colors as a scheme before it is not built again.
      firstWithSame = scheme: lib.findFirst (s: filled.${s} == filled.${scheme}) scheme order;

      build =
        scheme:
        mkScheme {
          inherit titlebarButtons extraGtk3Css;
          name = "${name}-${scheme}";
          colors = filled.${scheme};
        };

      builds = lib.genAttrs (lib.unique (map firstWithSame order)) build;

      schemeOf = scheme: builds.${firstWithSame scheme};
    in
    mkTheme {
      inherit name;
      light = schemeOf "light";
      dark = schemeOf "dark";
      contrast = if filled.contrast != null then schemeOf "contrast" else null;
    }
  );
in
{
  inherit
    presets
    mkScheme
    mkIcons
    mkTheme
    mkThemeFrom
    ;
}
