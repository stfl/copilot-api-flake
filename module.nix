{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.copilot-api;

  args =
    ["start"]
    ++ ["--port" (toString cfg.settings.port)]
    ++ ["--account-type" cfg.settings.accountType]
    ++ lib.optionals cfg.settings.verbose ["--verbose"]
    ++ lib.optionals cfg.settings.manual ["--manual"]
    ++ lib.optionals (cfg.settings.rateLimit != null) ["--rate-limit" (toString cfg.settings.rateLimit)]
    ++ lib.optionals cfg.settings.wait ["--wait"]
    ++ lib.optionals cfg.settings.claudeCode ["--claude-code"]
    ++ lib.optionals cfg.settings.showToken ["--show-token"]
    ++ lib.optionals cfg.settings.proxyEnv ["--proxy-env"];
in {
  options.services.copilot-api = {
    enable = lib.mkEnableOption "copilot-api, a GitHub Copilot to OpenAI/Anthropic-compatible API server";

    package = lib.mkPackageOption pkgs "copilot-api" {};

    githubTokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to a file containing the GitHub token. Loaded via systemd LoadCredential.";
    };

    settings = {
      port = lib.mkOption {
        type = lib.types.port;
        default = 4141;
        description = "Port to listen on.";
      };

      verbose = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable verbose logging.";
      };

      accountType = lib.mkOption {
        type = lib.types.enum ["individual" "business" "enterprise"];
        default = "individual";
        description = "GitHub Copilot account type.";
      };

      manual = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable manual request approval.";
      };

      rateLimit = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.positive;
        default = null;
        description = "Rate limit in seconds.";
      };

      wait = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Wait on rate limit instead of returning an error.";
      };

      claudeCode = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Claude Code mode.";
      };

      showToken = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Show tokens on fetch/refresh.";
      };

      proxyEnv = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Initialize proxy from environment variables.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.copilot-api = {
      description = "GitHub Copilot API Server";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "simple";
        DynamicUser = true;

        LoadCredential = lib.mkIf (cfg.githubTokenFile != null)
          "github-token:${cfg.githubTokenFile}";

        ExecStart = let
          escapedArgs = lib.escapeShellArgs args;
        in
          toString (pkgs.writeShellScript "copilot-api-start" ''
            exec ${lib.getExe cfg.package} ${escapedArgs} \
              ${lib.optionalString (cfg.githubTokenFile != null) ''--github-token "$(cat "$CREDENTIALS_DIRECTORY/github-token")"''}
          '');

        Restart = "on-failure";
        RestartSec = 5;

        # Hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictNamespaces = true;
        RestrictSUIDSGID = true;
        MemoryDenyWriteExecute = false;
      };
    };
  };
}
