{
  description = "Description for the project";

  inputs = {
    flake-parts.inputs.nixpkgs.follows = "nixpkgs";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.05";
    dist.url = "https://hercules-ci-enterprise.cachix.org/serve/96iwk990qm6f28wy9kqyxmvwlr1b6vm1/hercules-ci-enterprise.tar";
    dist.flake = false;
  };

  outputs = { self, flake-parts, dist, ... }:
    flake-parts.lib.mkFlake { inherit self; } ({ config, lib, ... }:
      let
        mkPackage = name: path: {
          inherit name;
          type = "derivation";
          outputs = [ "out" ];
          outPath = postulateStorePath path;
          drvPath = throw "hercules-ci-enterprise: ${path} is not buildable. It can only be substituted.";
        };
        postulateStorePath = path: builtins.appendContext path { "${path}" = { path = true; }; };
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
          packages = lib.mapAttrs mkPackage (lib.importJSON (dist + "/hercules-ci-dependencies.json")) // {
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
          nixosModules.single-machine-age = {
            imports = [
              self.nixosModules.single-machine
              "${dist}/enterprise/single-machine-age.nix"
            ];
          };
          nixosModules.single-machine = { pkgs, ... }: {
            imports = [
              self.nixosModules.application-plus-nginx
              "${dist}/enterprise/single-machine.nix"
            ];
          };

          # No infra services, such as postgresql, rabbitmq, etc.
          # You will have to configure your own.
          # This does enable nginx and configure it.
          nixosModules.application-plus-nginx = {
            imports = [
              self.nixosModules.packages
              "${dist}/web/module.nix"
              "${dist}/backend/module.nix"
              "${dist}/backend/secrets-from-file.nix"
            ];
          };
        };
      });
}
