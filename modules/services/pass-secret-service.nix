{ pkgs, config, lib, ... }:

with lib;

let
  cfg = config.services.pass-secret-service;

  busName = "org.freedesktop.secrets";
in {
  meta.maintainers = with maintainers; [ cab404 cyntheticfox ];

  options.services.pass-secret-service = {
    enable = mkEnableOption "Pass libsecret service";

    package = mkPackageOption pkgs "pass-secret-service" { };

    storePath = mkOption {
      type = types.str;
      default = "";
      defaultText = "$HOME/.password-store";
      example = "/home/user/.local/share/password-store";
      description = ''
        Absolute path to password store.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      (hm.assertions.assertPlatform "services.pass-secret-service" pkgs
        platforms.linux)
      {
        assertion = !config.services.gnome-keyring.enable;
        message = "Only one secrets service per user can be enabled at a time";
      }
    ];

    systemd.user.services.pass-secret-service =
      let binPath = "${cfg.package}/bin/pass_secret_service";
      in {
        Unit = {
          AssertFileIsExecutable = "${binPath}";
          Description = "Pass libsecret service";
          Documentation = "https://github.com/mdellweg/pass_secret_service";
          PartOf = [ "default.target" ];
        };

        Service = {
          Type = "dbus";
          ExecStart = "${binPath} ${
              optionalString (cfg.storePath != "") "--path ${cfg.storePath}"
            }";
          BusName = busName;
        };

        Install.WantedBy = [ "default.target" ];
      };

    xdg.dataFile."dbus-1/services/${busName}.service".source =
      "${cfg.package}/share/dbus-1/services/${busName}.service";
  };
}
