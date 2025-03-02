{
  description = "Defined Networks' dnclient application";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

  outputs = { self, nixpkgs }: let 
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
    dnclientPkg = pkgs.callPackage ./dnclient.nix { };
  in {
    packages.x86_64-linux.default = dnclientPkg;

    nixosModules.default = { config, lib, dnclient, ... }: let
      cfg = config.services.dnclient;
    in {
      options.services.dnclient = with lib; {
        enable = mkEnableOption "Defined Networks dnclient server";

        environmentFile = mkOption rec {
          type = types.nullOr types.str;
          default = null;
          example = "/var/lib/defined/my-env";
          description = "Systemd environment file for dnclient server";
        };
      };

      config = lib.mkIf cfg.enable {
        environment.systemPackages = [ dnclientPkg ];

        systemd.services.dnclient = {
          enable = true;
          description = "Defined Networks' dnclient network configuration tool";
          after = [ "network.target" ];

          preStart = ''
            mkdir -p /var/lib/defined
          '';

          startLimitIntervalSec = 5;
          serviceConfig = {
            StartLimitBurst = 10;
            Type = "notify";
            NotifyAccess = "main";
            ExecStart = "${dnclientPkg}/bin/dnclient run -config /var/lib/defined -server https://api.defined.net";
            Restart = "always";
            RestartSec = 120;
            EnvironmentFile = lib.mkIf (cfg.environmentFile != null) cfg.environmentFile;
          };

          wantedBy = [ "multi-user.target" ];
        };
      };
    };
  };
}
