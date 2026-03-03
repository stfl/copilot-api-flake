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
    };
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Binary is present and prints help
    help = machine.succeed("copilot-api --help 2>&1")
    assert "USAGE" in help, f"Expected help output, got: {help}"

    # Service is enabled
    machine.succeed("systemctl is-enabled copilot-api.service")

    # LoadCredential is wired in the unit
    machine.succeed("systemctl cat copilot-api.service | grep LoadCredential")

    # Token flag is present in the wrapper script
    machine.succeed("systemctl cat copilot-api.service | grep github-token")

    # Service attempted to start and failed at token exchange, not at filesystem/config errors
    machine.succeed("journalctl -u copilot-api.service | grep -i 'github\\|token\\|fetch'")
    machine.fail("journalctl -u copilot-api.service | grep -i 'ENOENT\\|no such file'")
  '';
}
