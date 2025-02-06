{
  inputs = {
    nixpkgs.url = "github:matejc/nixpkgs/latest";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { self, nixpkgs, nixos-generators, deploy-rs, ... }: let
    system = "x86_64-linux";
    vars = import ./vars.nix;

    nixosConfigurations = nixpkgs.lib.mapAttrs (n: v: nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ./hardware-configuration-${v.format}.nix
        ./configuration.nix
      ];
      specialArgs = { inherit nixpkgs; vars = v; };
    }) vars.machines;

    nodes = nixpkgs.lib.mapAttrs (n: v: {
      sshUser = "admin";
      user = "root";
      hostname = v.ip;
      remoteBuild = true;
      profiles.system = {
        path = deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations.${n};
      };
    }) vars.machines;

    images = nixpkgs.lib.mapAttrs (n: v: nixos-generators.nixosGenerate {
      inherit system;
      modules = [
        ./configuration.nix
        ({...}: { virtualisation.diskSize = 16 * 1024; })
      ];
      inherit (v) format;
      specialArgs = { inherit nixpkgs; vars = v; };
    }) vars.machines;
  in {
    inherit nixosConfigurations;
    deploy.nodes = nodes;
    checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;
    packages.${system} = { deploy-rs = deploy-rs.packages.${system}.deploy-rs; } // images;
  };
}
