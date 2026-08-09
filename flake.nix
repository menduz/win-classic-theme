{
  description = "win-classic-theme, a Windows 9x theme for GTK2, GTK3, GTK4 and Xfwm4";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forEachSystem = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

      presets = import ./presets.nix;

      # The name of the theme that a preset builds. The name below share/themes
      # is not the name of the Windows scheme.
      themeName =
        preset:
        {
          windows-classic = "win-classic-98";
          windows-standard = "win-classic-standard";
        }
        .${preset} or "win-classic-${preset}";

      # The schemes that the screenshots show.
      shown = [
        "windows-standard"
        "dark"
      ];
    in
    {
      # One package for each preset, plus the screenshots.
      packages = forEachSystem (
        pkgs:
        let
          themes = lib.mapAttrs (
            preset: _:
            pkgs.callPackage ./default.nix {
              inherit preset;
              name = themeName preset;
            }
          ) presets;

          shots = pkgs.callPackage ./dev/screenshots.nix {
            themes = lib.listToAttrs (
              map (preset: lib.nameValuePair (themeName preset) themes.${preset}) shown
            );
          };
        in
        themes
        // {
          default = themes.dark;
          inherit (shots) screenshots showcase;
        }
      );

      devShells = forEachSystem (
        pkgs:
        let
          shots = pkgs.callPackage ./dev/screenshots.nix {
            themes = { }; # the shell makes the screenshots with `nix build`
          };
        in
        {
          default = pkgs.callPackage ./dev/shell.nix {
            inherit (shots) screenshot showcase;
            update-screenshots = shots.update;
          };
        }
      );

      # `nix flake check` reads the style sheets with the parser of GTK.
      checks = forEachSystem (pkgs: {
        css = pkgs.callPackage ./dev/checks.nix {
          theme = self.packages.${pkgs.system}.windows-standard;
          themeName = themeName "windows-standard";
        };
      });

      formatter = forEachSystem (pkgs: pkgs.nixfmt-tree);

      # `pkgs.win-classic-theme` in another flake. See the README.
      overlays.default = final: prev: {
        win-classic-theme = final.callPackage ./default.nix { };
      };
    };
}
