{
  self,
  bun2nix-overlay,
  pkgs,
  ...
}:
pkgs.testers.nixosTest {
  name = "copilot-api-module";

  nodes.machine = {config, pkgs, ...}: {
    imports = [self.nixosModules.copilot-api];

    nixpkgs.overlays = [bun2nix-overlay self.overlays.default];

    environment.etc."copilot-api-token".text = "ghp_dummy";

    environment.systemPackages = [config.services.copilot-api.package];

    services.copilot-api = {
      enable = true;
      githubTokenFile = "/etc/copilot-api-token";
      settings.apiConfig = {
        apiKeys = ["test-key-1" "test-key-2"];
        smallModel = "gpt-5-mini";
        modelReasoningEfforts = {"gpt-5-mini" = "low";};
      };
    };
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Binary is present and prints help
    help = machine.succeed("copilot-api --help 2>&1")
    assert "USAGE" in help, f"Expected help output, got: {help}"

    # Service is enabled
    machine.succeed("systemctl is-enabled copilot-api.service")

    # GitHub token credential is wired in the unit
    machine.succeed("systemctl cat copilot-api.service | grep 'github-token'")
    # Store config path is embedded in the wrapper script
    machine.succeed("grep -r 'copilot-api-config.json' /nix/store/*copilot-api-start*")

    # Listen address is set in the unit file and effective environment
    machine.succeed("systemctl cat copilot-api.service | grep 'HOST=127.0.0.1'")
    machine.succeed("systemctl show copilot-api.service --property=Environment | grep 'HOST=127.0.0.1'")

    # COPILOT_API_HOME points to the state directory
    machine.succeed("systemctl show copilot-api.service --property=Environment | grep 'COPILOT_API_HOME'")

    # ExecStartPre wrote config.json into the state directory
    cfg = machine.succeed("cat /var/lib/copilot-api/config.json")
    assert "test-key-1" in cfg, f"Expected apiKeys in config.json, got: {cfg}"
    assert "gpt-5-mini" in cfg, f"Expected smallModel in config.json, got: {cfg}"

    # Service attempted to start and failed at token exchange, not at filesystem/config errors
    machine.succeed("journalctl -u copilot-api.service | grep -i 'github\\|token\\|fetch'")
    machine.fail("journalctl -u copilot-api.service | grep -i 'ENOENT\\|no such file'")
  '';
}
