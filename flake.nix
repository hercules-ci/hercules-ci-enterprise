{
  description = "Description for the project";

  inputs = {
    flake-parts.inputs.nixpkgs.follows = "nixpkgs";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.05";
  };

  outputs = { self, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit self; } ({ config, lib, ... }:
      let
        mkPackage = name: path: {
          inherit name;
          type = "derivation";
          outputs = [ "out" ];
          /*
          Hercules CI Enterprise needs builtins.storePath to pull in
          the binaries. Please allow this with `--impure`. */ outPath = builtins.storePath path;

          drvPath = throw "hercules-ci-enterprise: ${path} is not buildable. It can only be substituted.";
        };
      in
      {
        imports = [
        ];
        systems = [ "x86_64-linux" ];
        perSystem = { config, self', inputs', pkgs, system, ... }: {
          devShells.default = pkgs.mkShell {
            nativeBuildInputs = [
              config.packages.hercules-jwkgen
              config.packages.hercules-generate-config
              pkgs.jq
            ];
            message = ''
              Welcome to the Hercules CI Enterprise setup shell!

              To generate a configuration, run
              
                  hercules-generate-config
            '';
            shellHook = ''
              echo "$message"
            '';
          };
          apps.hercules-generate-config.program = config.packages.hercules-generate-config;
          packages = lib.mapAttrs mkPackage (lib.importJSON ./hercules-ci-dependencies.json) // {
            hercules-generate-config = pkgs.callPackage ./src/generate-config.nix { };
          };
          checks.example = (lib.nixosSystem {
            modules = [ ./example/configuration.nix self.nixosModules.single-machine ];
          }).config.system.build.toplevel;
        };
        flake = {
          nixosModules.packages = { config, lib, pkgs, ... }: {
            key = "hercules-ci-enterprise-packages";
            config = {
              hercules.packages = self.packages.x86_64-linux;
              assertions = [
                {
                  assertion = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
                  message = ''
                    Hercules CI Enterprise can currently only run on x86_64-linux.
                  '';
                }
              ];
            };
          };
          nixosModules.single-machine = { pkgs, ... }: {
            imports = [
              ./single-machine.nix
              self.nixosModules.packages
              (self.packages.x86_64-linux.dist + "/web/module.nix")
              (self.packages.x86_64-linux.dist + "/backend/module.nix")
            ];
          };
        };
      });
}
