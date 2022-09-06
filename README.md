
# Hercules CI Enterprise binaries

### What's here?

This repository's primary task is to reference the Hercules CI Enterprise binaries.

It furthermore provides installation instructions and a devshell for setting up
Hercules CI Enterprise.

For the open source Hercules CI Agent, see https://github.com/hercules-ci/hercules-ci-agent instead.

### What is Hercules CI Enterprise

Hercules CI Enterprise is a self-hosted (or "on premises") replacement for hercules-ci.com.

It's perfect for when rules and regulations require all parts of CI/CD system to be behind a firewall, or when you simply don't want any traffic between your GitHub Enterprise or GitLab instance and the public internet.

### How do I install it?

Get a `tokens.json` ([info@hercules-ci.com](info@hercules-ci.com)).

Save the provided `tokens.json` to the root of the repo.

```console
$ nix shell nixpkgs#jq

$ CACHIX_AUTH_TOKEN=$(jq -r .cacheToken <tokens.json) cachix use hercules-ci-enterprise
Configured private read access credentials in /home/user/.config/nix/netrc
Configured https://hercules-ci-enterprise.cachix.org binary cache in /home/user/.config/nix/nix.conf

$ nix develop --impure
Welcome to the Hercules CI Enterprise setup shell!

$ hercules-generate-config
```

Complete the generated configuration files in the generated `hercules-config` directory and integrate it into a NixOS configuration.

Make sure Hercules CI Enterprise starts up without authentication errors for S3 and RabbitMQ.

Start the GitLab by navigating to `https://<hercules-ci>/install/gitlab`. Complete the steps.

Navigate to a group's Settings to enable the integration for the group.

Configure an agent for the group and set `settings.apiBaseUrl` to your instance, previously referred to as `https://<hercules-ci>`.
