# The user part of win-classic-theme. It writes the GTK files of the user, the
# cursor and the GSettings keys that a running session reads. The system part
# is in nixos-module.nix.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.win-classic-theme;

  patchedQtStyles =
    let
      styles = pkgs.callPackage ./qt { };
    in
    [
      styles.qt5
      styles.qt6
    ];

  qtPackageSettings = lib.optionalAttrs cfg.patchQt {
    package = patchedQtStyles;
  };

  themeAttrs = {
    inherit (cfg.theme) name package;
  };
in
{
  imports = [ ./options.nix ];

  options.programs.win-classic-theme = {
    installPackages = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether the schemes go into the profile of the user. Set this to false
        when the NixOS module already puts them in the system profile.
      '';
    };

    qt.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether a Qt program takes the GTK2 style. The style reads the theme of
        GTK2, so a Qt window then looks like a GTK window. It works on X11 and
        on XWayland, so a Qt program that runs on Wayland keeps the Qt look.
      '';
    };
  };

  config = lib.mkIf cfg.enabled {
    home.packages = lib.mkIf cfg.installPackages (lib.attrValues cfg.packages);

    gtk = {
      enable = true;

      font = {
        inherit (cfg.font) name size package;
      };
      iconTheme = {
        inherit (cfg.iconTheme) name package;
      };
      cursorTheme = {
        inherit (cfg.cursorTheme) name package size;
      };
      colorScheme = if cfg.theme.dark then "dark" else "light";

      # The Qt style of GTK2 reads ~/.gtkrc-2.0, so a Qt program needs this file.
      gtk2.theme = themeAttrs;

      gtk3 = {
        theme = themeAttrs;
        extraConfig = cfg.settings.gtk3;
        extraCss = cfg.css;
      };

      # GTK4 reads no theme by name from this file. Home Manager writes an
      # `@import` of the style sheet of the theme instead.
      gtk4 = {
        theme = themeAttrs;
        extraConfig = cfg.settings.gtk4;
        extraCss = cfg.css;
      };
    };

    home.pointerCursor = {
      inherit (cfg.cursorTheme) name package size;
      gtk.enable = true;
      dotIcons.enable = true;
      x11.enable = true;
    };

    # A program that libadwaita draws reads this variable, and no settings file.
    home.sessionVariables.GTK_THEME = cfg.theme.name;

    dconf.settings = {
      "org/gnome/desktop/interface" = {
        color-scheme = if cfg.theme.dark then "prefer-dark" else "prefer-light";
      };
      # The same button order as the theme.
      "org/gnome/desktop/wm/preferences" = {
        button-layout = cfg.windowManagerButtonLayout;
      };
    };

    qt = lib.mkIf cfg.qt.enable {
      enable = true;
      platformTheme = {
        name = "gtk2";
      }
      // qtPackageSettings;
      style = {
        name = "gtk2";
      }
      // qtPackageSettings;
    };
  };
}
