{ config, lib, ... }:
let
  cfg = config.programs.win-classic-theme;
in
{
  options.programs.win-classic-theme = {
    enabled = lib.mkEnableOption "global GTK4 font settings";

    gtk4ExtraSettings = lib.mkOption {
      type = lib.types.lines;
      default = "";
      example = ''
        gtk-font-name=Liberation Sans 9
      '';
      description = "Extra lines to add to the global GTK4 settings file.";
    };
  };

  config = lib.mkIf cfg.enabled {
    environment.etc."gtk-4.0/settings.ini".text = ''
      [Settings]
      gtk-font-rendering=manual
      gtk-hint-font-metrics=1
      gtk-xft-antialias=1
      gtk-xft-hinting=1
      gtk-xft-hintstyle=hintslight
      gtk-xft-rgba=none
      gtk-xft-dpi=98304
    ''
    + cfg.gtk4ExtraSettings;
  };
}
