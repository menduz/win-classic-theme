# The options that the NixOS module and the Home Manager module share. A
# desktop session has a system part and a user part, so a configuration
# declares this block two times: one time in NixOS and one time in Home
# Manager. Both modules import this file, so both read the same values.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.win-classic-theme;

  # Home Manager gives the NixOS configuration in the special argument
  # `osConfig`. NixOS gives no such argument, and a standalone Home Manager
  # gives none either, so the value is an empty set in those two.
  osConfig = config._module.specialArgs.osConfig or { };

  presets = import ./presets.nix;

  # The theme names no font of its own. fontconfig holds the family for
  # `sans-serif`, and the theme reads that family, so a GTK program and a
  # program that asks fontconfig alone draw with the same font.
  #
  # The NixOS module reads the list of the system. The Home Manager module
  # reads the list of the user first, and the list of the system after it. The
  # last name is the family of fontconfig itself: a configuration that names no
  # font still gets the font that fontconfig selects.
  sansSerif =
    (config.fonts.fontconfig.defaultFonts.sansSerif or [ ])
    ++ (osConfig.fonts.fontconfig.defaultFonts.sansSerif or [ ])
    ++ [ "sans-serif" ];

  fontName = lib.head sansSerif;

  schemeType = lib.types.submodule (
    { name, ... }:
    {
      options = {
        name = lib.mkOption {
          type = lib.types.str;
          default = "win-classic-${name}";
          defaultText = lib.literalMD "`win-classic-` and the name of the scheme";
          description = ''
            The name of the theme below `share/themes`. GTK and Xfwm4 look up a
            theme by this name.
          '';
        };

        preset = lib.mkOption {
          type = lib.types.nullOr (lib.types.enum (lib.attrNames presets));
          default = null;
          example = "windows-standard";
          description = "The scheme of presets.nix that gives the colors.";
        };

        colors = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          example = lib.literalExpression ''{ bgcolor = "#c0c0c0"; }'';
          description = ''
            System colors of Windows. A color here wins over the same color of
            `preset`. The README lists the names.
          '';
        };

        dark = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Whether the scheme is a dark one. A program that reads the
            `color-scheme` key of `org.gnome.desktop.interface` follows this
            value.
          '';
        };
      };
    }
  );

  settingsValue = lib.types.oneOf [
    lib.types.bool
    lib.types.int
    lib.types.str
  ];

  # Build every scheme. A session can change to another one at run time, so
  # all of the schemes must be in the profile. GTK finds none of them otherwise.
  packages = lib.mapAttrs (
    _: scheme:
    pkgs.callPackage ./default.nix {
      inherit (scheme) name preset colors;
      inherit (cfg) titlebarButtons;
    }
  ) cfg.schemes;

  scheme =
    cfg.schemes.${cfg.variant} or (throw ''
      win-classic-theme: the scheme "${cfg.variant}" does not exist. The schemes are:
      ${lib.concatStringsSep " " (lib.attrNames cfg.schemes)}'');

  package = packages.${cfg.variant};

  # Keys that GTK3 and GTK4 both read.
  commonSettings = {
    gtk-theme-name = scheme.name;
    gtk-icon-theme-name = cfg.iconTheme.name;
    gtk-cursor-theme-name = cfg.cursorTheme.name;
    # 0 lets the cursor theme select the size.
    gtk-cursor-theme-size = 0;
    gtk-font-name = "${fontName} ${toString cfg.baseFontSize}";
    gtk-decoration-layout = cfg.decorationLayout;
    # A Windows 9x window has a title bar, not a header bar with widgets in it.
    gtk-dialogs-use-header = 0;
    gtk-application-prefer-dark-theme = if scheme.dark then 1 else 0;
    gtk-xft-antialias = if cfg.fontRendering.antialias then 1 else 0;
    gtk-xft-hinting = if cfg.fontRendering.hinting then 1 else 0;
    gtk-xft-hintstyle = cfg.fontRendering.hintstyle;
    gtk-xft-rgba = cfg.fontRendering.rgba;
  }
  // lib.optionalAttrs (cfg.fontRendering.dpi != null) {
    # GTK counts this one in 1024ths of a point.
    gtk-xft-dpi = cfg.fontRendering.dpi * 1024;
  };

  # The theme draws a flat 3D border around a widget. A round corner or a
  # shadow below a menu breaks that border, so GTK must not add one.
  gtk3Settings = commonSettings // {
    gtk-toolbar-style = "GTK_TOOLBAR_BOTH_HORIZ";
    gtk-toolbar-icon-size = "GTK_ICON_SIZE_LARGE_TOOLBAR";
    gtk-button-images = 0;
    gtk-menu-images = 1;
    gtk-enable-event-sounds = 0;
    gtk-enable-input-feedback-sounds = 1;
  };

  # GTK4 measures a font of its own unless `gtk-font-rendering` is manual. The
  # theme draws a 1px border, so a fractional font metric moves a widget by
  # half a pixel and the border becomes gray.
  gtk4Settings = commonSettings // {
    gtk-font-rendering = "manual";
    gtk-hint-font-metrics = 1;
  };

  # A GTK4 program that draws its own title bar gets a header bar, not the
  # title bar of the window manager. These rules give that header bar the size
  # and the font of a Windows 9x title bar.
  titlebarCss = ''
    headerbar button.titlebutton {
      margin: 0px;
      padding: 0px;
      /* remove the extra border */
      border-top: 0;
      border-left: 0;
    }
    headerbar button.titlebutton image {
      /* center the X on the button */
      margin: -1px -1px -2px;
    }
    headerbar {
      padding: 1px 2px 0px 2px;
      /* line below the header bar */
      margin-bottom: 1px;
    }
    headerbar label.title {
      font-size: ${toString cfg.baseFontSize}pt;
      background: transparent;
      margin-top: 0;
    }
  '';

  # GTK4 draws the scroll bar on top of the content, not beside it. The theme
  # paints the trough with the window color and a dither image, which then
  # hides the text below the bar. These rules show the slider alone. A program
  # loads this file above the theme, so it changes that program alone.
  scrollbarCss = pkgs.writeText "win-classic-scrollbar.css" ''
    scrollbar,
    scrollbar.overlay-indicator,
    scrollbar.horizontal,
    scrollbar.vertical,
    scrollbar > range,
    scrollbar > range > trough,
    scrollbar trough {
      background-color: transparent;
      background-image: none;
      border: none;
      box-shadow: none;
    }
  '';
in
{
  options.programs.win-classic-theme = {
    enabled = lib.mkEnableOption "the win-classic-theme desktop theme";

    schemes = lib.mkOption {
      type = lib.types.attrsOf schemeType;
      default = {
        dark = {
          preset = "dark";
          dark = true;
        };
        standard = {
          preset = "windows-standard";
        };
      };
      description = ''
        The color schemes to build. Every scheme goes into the profile, so that
        a session can change between them at run time.
      '';
    };

    variant = lib.mkOption {
      type = lib.types.str;
      default = "dark";
      example = "standard";
      description = "The scheme of `schemes` that the session starts with.";
    };

    titlebarButtons = lib.mkOption {
      type = lib.types.submodule {
        options = {
          minimize = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether a title bar has a minimize button.";
          };
          maximize = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether a title bar has a maximize button.";
          };
        };
      };
      default = { };
      description = ''
        The buttons of a title bar. A tiling window manager does not use these
        two buttons, so it can drop them.
      '';
    };

    baseFontSize = lib.mkOption {
      type = lib.types.int;
      default = 8;
      description = ''
        The size of the interface font, in points. Windows 9x draws its
        interface with MS Sans Serif at 8 points.

        The theme takes the family from
        `fonts.fontconfig.defaultFonts.sansSerif`. Put the font of `fonts/` in
        `fonts.packages` and that family name in the list to get the font of
        Windows 9x.

        The font of `fonts/` draws its glyphs on a grid of 11 pixels to the em,
        so it gives a whole pixel to each line of a glyph at 11 pixels to the
        em and at a whole multiple of that. A size of 8 points reaches 11
        pixels at 99 dots per inch, and 10.67 pixels at the 96 of
        `fontRendering.dpi`. Set that option to 99 to hold the grid.
      '';
    };

    iconTheme = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "SE98";
        description = "The name of the icon theme.";
      };
      package = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = pkgs.callPackage ./win98se.nix { };
        defaultText = lib.literalMD "SE98, with Chicago95 for the icons that SE98 does not hold";
        description = "The package that holds the icon theme.";
      };
    };

    cursorTheme = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "Adwaita";
        description = "The name of the cursor theme.";
      };
      package = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = pkgs.adwaita-icon-theme;
        defaultText = lib.literalExpression "pkgs.adwaita-icon-theme";
        description = "The package that holds the cursor theme.";
      };
      size = lib.mkOption {
        type = lib.types.int;
        default = 16;
        description = "The size of the cursor, in pixels.";
      };
    };

    fontRendering = {
      antialias = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether the text is antialiased.";
      };
      hinting = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether the text is hinted.";
      };
      hintstyle = lib.mkOption {
        type = lib.types.enum [
          "hintnone"
          "hintslight"
          "hintmedium"
          "hintfull"
        ];
        default = "hintslight";
        description = ''
          The strength of the hinting. The screenshots of the theme use
          `hintslight`.
        '';
      };
      rgba = lib.mkOption {
        type = lib.types.enum [
          "none"
          "rgb"
          "bgr"
          "vrgb"
          "vbgr"
        ];
        default = "none";
        description = ''
          The order of the subpixels. The theme draws 1px lines, and subpixel
          rendering gives such a line a color edge, so the default is `none`.
        '';
      };
      dpi = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = 96;
        description = ''
          The resolution of the text, in dots per inch. A Windows 9x metric is
          a value for 96 dpi. Set this to null to keep the value of the
          display.
        '';
      };
    };

    decorationLayout = lib.mkOption {
      type = lib.types.str;
      default = package.decorationLayout;
      defaultText = lib.literalMD "the layout of the built theme";
      example = ":menu";
      description = ''
        The value of `gtk-decoration-layout`. It gives the buttons of a header
        bar that a GTK program draws itself. A tiling window manager can set
        `":menu"` here, because it has no window buttons.
      '';
    };

    windowManagerButtonLayout = lib.mkOption {
      type = lib.types.str;
      default = package.decorationLayout;
      defaultText = lib.literalMD "the layout of the built theme";
      description = ''
        The value of the `button-layout` key of
        `org.gnome.desktop.wm.preferences`. It gives the buttons that the
        window manager draws.
      '';
    };

    gtk3Settings = lib.mkOption {
      type = lib.types.attrsOf settingsValue;
      default = { };
      example = lib.literalExpression "{ gtk-cursor-blink = 0; }";
      description = "Keys to add to the GTK3 settings, or to replace in them.";
    };

    gtk4Settings = lib.mkOption {
      type = lib.types.attrsOf settingsValue;
      default = { };
      example = lib.literalExpression "{ gtk-enable-animations = 0; }";
      description = "Keys to add to the GTK4 settings, or to replace in them.";
    };

    extraCss = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Style sheet rules to add below the theme.";
    };

    # Values that the two modules read. A configuration does not set these.
    packages = lib.mkOption {
      type = lib.types.attrsOf lib.types.package;
      internal = true;
      readOnly = true;
      default = packages;
      description = "The built theme of every scheme.";
    };

    theme = lib.mkOption {
      type = lib.types.attrs;
      internal = true;
      readOnly = true;
      default = {
        inherit (scheme) name dark;
        inherit package;
      };
      description = "The scheme that `variant` selects.";
    };

    fontName = lib.mkOption {
      type = lib.types.str;
      internal = true;
      readOnly = true;
      default = fontName;
      description = ''
        The family that `fonts.fontconfig.defaultFonts.sansSerif` gives, or
        `sans-serif` when that list is empty.
      '';
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      internal = true;
      readOnly = true;
      default = {
        gtk3 = gtk3Settings // cfg.gtk3Settings;
        gtk4 = gtk4Settings // cfg.gtk4Settings;
      };
      description = "The settings that GTK3 and GTK4 read.";
    };

    css = lib.mkOption {
      type = lib.types.lines;
      internal = true;
      readOnly = true;
      default = titlebarCss + cfg.extraCss;
      description = "The style sheet that goes below the theme.";
    };

    scrollbarCss = lib.mkOption {
      type = lib.types.path;
      internal = true;
      readOnly = true;
      default = scrollbarCss;
      description = ''
        A style sheet for a program that draws the scroll bar on top of the
        content. Give this file to such a program, for example with the
        `gtk-custom-css` key of Ghostty.
      '';
    };
  };

  config = lib.mkIf cfg.enabled {
    assertions = [
      {
        assertion = cfg.schemes ? ${cfg.variant};
        message = ''
          programs.win-classic-theme.variant is "${cfg.variant}", and that
          scheme is not in programs.win-classic-theme.schemes. The schemes are:
          ${lib.concatStringsSep " " (lib.attrNames cfg.schemes)}
        '';
      }
    ];
  };
}
