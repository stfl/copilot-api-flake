{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.copilot-api;

  # Generic helper: recursively remove null values from an attrset so that
  # unset optional fields are omitted from the generated JSON.
  removeNulls = attrs:
    lib.mapAttrs (_: v: if lib.isAttrs v then removeNulls v else v)
    (lib.filterAttrs (_: v: v != null) attrs);

  # Build the config.json written to $COPILOT_API_HOME on service start.
  # Fields that are null (unset) or empty attrsets are omitted entirely so the
  # app falls back to its own defaults.
  configFile = pkgs.writeText "copilot-api-config.json" (builtins.toJSON (removeNulls {
    auth.apiKeys = cfg.settings.apiConfig.apiKeys;
    smallModel = cfg.settings.apiConfig.smallModel;
    modelReasoningEfforts =
      if cfg.settings.apiConfig.modelReasoningEfforts != {}
      then cfg.settings.apiConfig.modelReasoningEfforts
      else null;
    useFunctionApplyPatch = cfg.settings.apiConfig.useFunctionApplyPatch;
    compactUseSmallModel = cfg.settings.apiConfig.compactUseSmallModel;
    extraPrompts =
      if cfg.settings.apiConfig.extraPrompts != {}
      then cfg.settings.apiConfig.extraPrompts
      else null;
  }));

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
      listenAddress = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "Address to listen on. Defaults to localhost only.";
      };

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

      # Options that map to the JSON config file read by the application.
      # These are distinct from CLI flags: the app merges both sources.
      apiConfig = {
        apiKeys = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "API keys clients must supply via x-api-key or Authorization: Bearer. Empty list disables authentication.";
        };

        smallModel = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Model used for small/fast tasks. Defaults to gpt-5-mini.";
        };

        modelReasoningEfforts = lib.mkOption {
          type = lib.types.attrsOf (lib.types.enum ["low" "medium" "high"]);
          default = {};
          description = "Reasoning effort level per model ID.";
          example = {"gpt-5-mini" = "low";};
        };

        useFunctionApplyPatch = lib.mkOption {
          type = lib.types.nullOr lib.types.bool;
          default = null;
          description = "Use function apply patch. Defaults to true.";
        };

        compactUseSmallModel = lib.mkOption {
          type = lib.types.nullOr lib.types.bool;
          default = null;
          description = "Use small model for compact operations. Defaults to true.";
        };

        extraPrompts = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = {};
          description = "Extra system prompts per model ID, merged with the application defaults.";
        };
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

        LoadCredential = lib.optional (cfg.githubTokenFile != null)
          "github-token:${cfg.githubTokenFile}";

        ExecStart = let
          escapedArgs = lib.escapeShellArgs args;
        in
          toString (pkgs.writeShellScript "copilot-api-start" ''
            cp ${configFile} "$COPILOT_API_HOME/config.json"
            exec ${lib.getExe cfg.package} ${escapedArgs} \
              ${lib.optionalString (cfg.githubTokenFile != null) ''--github-token "$(cat "$CREDENTIALS_DIRECTORY/github-token")"''}
          '');

        StateDirectory = "copilot-api";
        Environment = [
          "HOME=%S/copilot-api"
          "HOST=${cfg.settings.listenAddress}"
          "COPILOT_API_HOME=%S/copilot-api"
        ];

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
