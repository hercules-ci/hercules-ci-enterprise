{ config, lib, pkgs, ... }:
{
  config = {
    services.hercules-backend = {
      domain = "hercules.demo-business.org";

      # For AWS
      # s3.defaultRegion = ...; # e.g. "us-east-1"
      # For MinIO or other providers (optional)
      s3.hostOverride = "http://localhost:12345";

      s3.buckets.state = "hercules-state"; # name of the bucket for state files
      s3.buckets.logs = "hercules-logs"; # name of the bucket for logs

      smtp = {
        server = "mail.example.com";
        port = 587;
      };
      notificationEmailSender = "notifications@hercules-ci.example.com";

      # If not using e.g. single-machine-age, you can set this manually.
      secretsFile = "/var/keys/hercules-ci/hercules-ci.json";
    };

    # Either a directory containing ssl.crt and ssl.key
    #   services.hercules-web.certificateDirectory = "/var/lib/hercules/web/certs";
    # or
    #   services.hercules-web.enableACME = true;
    #   security.acme.email = ...;
    #   # For Let's Encrypt's ToS see https://letsencrypt.org/repository/
    #   security.acme.acceptTerms = ...;

    # This creates the hercules user. The password below is encrypted by
    # rabbitmq-config.key, so it can be committed.
    services.rabbitmq.config = ''
      [ { rabbit
        , [ {default_user, <<"hercules">>}
          , { default_pass
            , {encrypted,<<"1L0q0cqJsK3tlecbcDBhqsQZks7v5WUYm5HimsW+UKv93b4j9/mUja51XBo4S24td9OxU37QcwXvEqD8ec4aC4ZnTVchXEg=">>}
            }
          , {config_entry_decoder
            , [ {passphrase, {file, <<"/var/lib/hercules/rabbit/rabbitmq-config.key">>}}
              , {cipher, blowfish_cfb64}
              , {hash, sha256}
              , {iterations, 10000}
              ]
            }
          % , {rabbitmq_management, [{path_prefix, "/_queues"}]}
          ]
        }
      ].
    '';

  };
}
