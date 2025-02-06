{ config, pkgs, lib, nixpkgs, vars, ... }:
{
  # All options can be found: https://search.nixos.org/options?channel=unstable

  boot.kernelPackages = pkgs.linuxPackages_6_13;

  environment.systemPackages = [
    config.hardware.nvidia.package
  ] ++ (with pkgs; [
    nano curl iproute2 htop tmux pciutils ncdu
  ]);

  services.openssh.enable = true;

  users = {
    mutableUsers = false;
    allowNoPasswordLogin = true;
    users.root.password = vars.password;
    users."${vars.user}" = {
      isNormalUser = true;
      password = vars.password;
      openssh.authorizedKeys.keys = vars.authorizedKeys;
      extraGroups = [ "wheel" "docker" ];
    };
  };
  security.sudo.wheelNeedsPassword = false;
  nix = {
    channel.enable = false;
    settings = {
      nix-path = "nixpkgs=${nixpkgs}";
      experimental-features = [ "nix-command" "flakes" ];
      trusted-users = [ "@wheel" ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
    };
  };
  environment.variables.NIX_PATH = lib.mkForce "nixpkgs=${nixpkgs}";

  networking.firewall = {
    allowedTCPPorts = [
      22
    ];
  };

  # networking.nameservers = vars.nameservers;
  networking.hostName = vars.hostname;

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = false;
    package = config.boot.kernelPackages.nvidiaPackages.dc;
    nvidiaPersistenced = true;
    datacenter.enable = true;
  };
  systemd.services.nvidia-fabricmanager.serviceConfig.SuccessExitStatus = "0 1";

  hardware.graphics.enable = true;

  # services.ollama = {
  #   enable = true;
  #   acceleration = "cuda";
  #   host = "0.0.0.0";
  #   environmentVariables.OLLAMA_ORIGINS = "*";
  # };

  services.cron = let
    shutdownScript = pkgs.writeShellScript "shutdown-cron.sh" ''
      export PATH="${pkgs.gnugrep}/bin:${pkgs.coreutils-full}/bin:${pkgs.systemd}/bin"
      who -q | grep -q -E "users=0" && poweroff
    '';
  in {
    enable = true;
    systemCronJobs = [ "0,30 * * * * root ${shutdownScript}" ];
  };

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.nvidia.acceptLicense = true;

  hardware.nvidia-container-toolkit.enable = true;
  virtualisation.docker = {
    enable = true;
    daemon.settings.features.cdi = true;
  };

  system.stateVersion = "24.05";
}
