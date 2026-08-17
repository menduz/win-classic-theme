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
      # `callPackage` puts `override` beside the checks, and that one is no
      # derivation.
      checks = forEachSystem (
        pkgs:
        lib.filterAttrs (_: lib.isDerivation) (
          pkgs.callPackage ./dev/checks.nix {
            theme = self.packages.${pkgs.system}.windows-standard;
            themeName = themeName "windows-standard";
          }
        )
      );

      # `nix fmt` gives its shape to a Nix file and to a style sheet.
      formatter = forEachSystem (
        pkgs:
        pkgs.writeShellApplication {
          name = "win-classic-fmt";
          runtimeInputs = [
            pkgs.nixfmt-rfc-style
            pkgs.prettier
            pkgs.findutils
          ];
          text = ''
            if [ "$#" -eq 0 ]; then
              set -- .
            fi
            find "$@" -name '*.nix' -not -path '*/.git/*' -exec nixfmt {} +
            find "$@" -name '*.css' -not -path '*/.git/*' \
              -exec prettier --parser css --write {} +
          '';
        }
      );

      # The system part and the user part of a session. A configuration that
      # uses Home Manager imports both, and declares the same
      # `programs.win-classic-theme` block in each one.
      nixosModules.default = import ./nixos-module.nix;
      homeManagerModules.default = import ./home-manager-module.nix;

      # `pkgs.win-classic-theme` in another flake. See the README.
      overlays.default = final: prev: {
        win-classic-theme = final.callPackage ./default.nix { };
      };
    };
}
