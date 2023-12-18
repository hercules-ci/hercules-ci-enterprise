
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

By installing Hercules CI Enterprise, you agree with [End User License Agreement](./EULA.md).

Get a `tokens.json` ([info@hercules-ci.com](info@hercules-ci.com)).

Create a directory for your deployment. Put `tokens.json` into this directory.

```console
$ nix shell nixpkgs#jq

$ CACHIX_AUTH_TOKEN=$(jq -r .cacheToken <tokens.json) cachix use hercules-ci-enterprise
Configured private read access credentials in /home/user/.config/nix/netrc
Configured https://hercules-ci-enterprise.cachix.org binary cache in /home/user/.config/nix/nix.conf

$ nix develop github:hercules-ci/hercules-ci-enterprise --impure
Welcome to the Hercules CI Enterprise setup shell!

$ hercules-generate-config

$ ls hercules-config
```

Complete the generated configuration files in the generated `hercules-config` directory and integrate it into your NixOS deployment.
 - Domain and TLS settings
 - SMTP settings

Create the secrets with agenix. The generated config uses the following `secrets.nix` entries:

```nix
#                acquire and enter the public keys before proceeding
let herculesCI = [ "<hercules CI host key>" "<user key 1>" ..... ];
in {
  "hercules-ci/keys.json.age".publicKeys = herculesCI;
  "hercules-ci/rabbitmq-config.key.age".publicKeys = herculesCI;
  "hercules-ci/minio-rootCredentialsFile.key.age".publicKeys = herculesCI;
}
```

Paste the generated secrets into agenix:

```console
mkdir hercules-ci
agenix -e hercules-ci/keys.json.age
agenix -e hercules-ci/rabbitmq-config.key.age
agenix -e hercules-ci/minio-rootCredentialsFile.key.age
```

Remove the unencrypted generated secrets.

```
rm hercules-config/hercules-ci-enterprise-keys.json
rm hercules-config/minio-rootCredentialsFile.key
rm hercules-config/rabbitmq-config.key
```

Integrate the config file and modules. E.g.

`flake.nix`
```
{
  inputs.hercules-ci-enterprise.url = "github:hercules-ci/hercules-ci-enterprise";

  outputs = { nixpkgs, hercules-ci-enterprise, ... }:
  # .....
  {
    nixosConfigurations.hercules-ci = nixosSystem {
      modules = [
        ./configuration-hercules.nix
        hercules-ci-enterprise.nixosModules.single-machine-age
      ];
    }
  };
}
```

Deploy and make sure Hercules CI Enterprise starts up without authentication errors relating to S3 and RabbitMQ.

Open your Hercules CI Enterprise in the browser: `https://${services.hercules-backend.domain}`.

Click _Install GitLab_ and follow the steps.

Navigate to a GitLab Group's _Settings_ to enable the integration for the group.

Configure an agent for the group and set `settings.apiBaseUrl` to your instance, to the value of `https://${services.hercules-backend.domain}`.

# How do I update it?

### Configure the private cache

Get a `tokens.json` ([info@hercules-ci.com](info@hercules-ci.com)).
This may already be stored in your deployment directory.

```console
$ nix shell nixpkgs#jq

$ CACHIX_AUTH_TOKEN=$(jq -r .cacheToken <tokens.json) cachix use hercules-ci-enterprise
Configured private read access credentials in /home/user/.config/nix/netrc
Configured https://hercules-ci-enterprise.cachix.org binary cache in /home/user/.config/nix/nix.conf
```

### Start the shell

```
$ nix develop github:hercules-ci/hercules-ci-enterprise --impure
Welcome to the Hercules CI Enterprise setup shell!
```

### Perform the update

```console
nix flake lock --recreate-lock-file

# invoke deployment command, such as nixops deploy
```

# How do I get support?

Use [support@hercules-ci.com](mailto:support@hercules-ci.com) or your company's Slack Connect channel.

# How do I enable profiling?

To the NixOS configuration, add:

```nix
  services.hercules-backend.profiling.heap.enable = true;
```

This creates `/var/log/hercules-server/hercules-server.hp` on the host.
You may compress the file and send it to [support@hercules-ci.com](mailto:support@hercules-ci.com), using a file sharing service if necessary.

Do not enable profiling for a prolonged time period, as the heap profile file will grow indefinitely.

# Release Notes

## 2023-12-17

If you upgrade to NixOS 23.11 while deploying the update, note that rabbitmq may fail to upgrade. It may help to run **before the update**:

```
sudo -u rabbitmq rabbitmqctl enable_feature_flag all
```

If, after the update, rabbitmq does not start, you may reset its state. Usually rabbitmq holds no in-flight messages, so no loss occurs:

```
# not needed if rabbitmq operates normally after the update
systemctl stop rabbitmq.service rabbitmq.socket
cp -a /var/lib/rabbitmq/ /var/lib/rabbitmq.old
rm -rf /var/lib/rabbitmq/*
rm -rf /var/lib/rabbitmq/.erlang.cookie
systemctl start rabbitmq.socket rabbitmq.service
systemctl restart hercules-initialize.service
systemctl restart hercules-server.service
```

### Highlights

* Many dependency updates
* Agent 0.10 support
* Evaluate the Hercules CI Enterprise deployment itself in pure mode
* Fix error when repositories has no default branch
