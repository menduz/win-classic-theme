# The system part of win-classic-theme. It builds the schemes, puts them in
# the system profile and writes the settings that GTK reads before a user logs
# in. The user part is in home-manager-module.nix.
{
  config,
  lib,
  ...
}:
let
  cfg = config.programs.win-classic-theme;

  # GTK writes a boolean as 1 or 0 in this file.
  toValue = value: if lib.isBool value then (if value then "1" else "0") else toString value;

  toIni =
    settings:
    "[Settings]\n"
    + lib.concatStrings (lib.mapAttrsToList (key: value: "${key}=${toValue value}\n") settings);
in
{
  imports = [ ./options.nix ];

  options.programs.win-classic-theme = {
    installPackages = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether the schemes, the icon theme and the cursor theme go into the
        system profile. GTK finds a theme in `$XDG_DATA_DIRS/themes`, so a
        scheme that is in no profile is a scheme that GTK cannot select.
      '';
    };
  };

  config = lib.mkIf cfg.enabled {
    # GTK reads settings.ini from the directories of XDG_CONFIG_DIRS, and /etc/xdg
    # is one of them. It does not read /etc/gtk-3.0 or /etc/gtk-4.0: the system
    # directory of GTK is below its own store path.
    environment.etc = {
      "xdg/gtk-3.0/settings.ini".text = toIni cfg.settings.gtk3;
      "xdg/gtk-4.0/settings.ini".text = toIni cfg.settings.gtk4;
    };

    environment.systemPackages = lib.mkIf cfg.installPackages (
      lib.attrValues cfg.packages
      ++ lib.optional (cfg.iconTheme.package != null) cfg.iconTheme.package
      ++ lib.optional (cfg.cursorTheme.package != null) cfg.cursorTheme.package
    );

    fonts.packages = lib.optional (cfg.font.package != null) cfg.font.package;

    # A program that libadwaita draws reads this variable, and no settings file.
    # A session that changes the scheme replaces the value.
    environment.sessionVariables.GTK_THEME = cfg.theme.name;

    # The Home Manager module writes GSettings keys, and so does a session
    # that changes the scheme.
    programs.dconf.enable = true;
  };
}
