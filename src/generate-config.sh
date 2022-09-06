#!@bash@/bin/bash
set -euo pipefail

workDir="$PWD/hercules-config"
help="false"

log() {
  echo 1>&2 "$@"
}

while [[ 0 != $# ]]; do
  case "$1" in
    --help|-h)
      help="true"
      ;;
    *)
      workDir="$1"
      ;;
  esac
  shift
done
if $help; then
  log "Usage: hercules-generate-config DIR"
  log "  generate a new config in DIR"
  log "  DIR: directory where generated secrets and config file will be written"
  log "       default: ./hercules-config"
  exit 1
fi

mkdir -p "$(dirname "$workDir")"
if ! mkdir "$workDir"; then
  log "Directory $workDir already exists. Stopping."
  log "Note that a config contains uniquely generated secrets that are"
  log "necessary to decrypt the data of existing installations."
  exit 1
fi

cd "$workDir"

RABBITMQ_CONFIG_KEY="$(set +o pipefail; tr -cd a-zA-Z0-9 </dev/urandom | head -c 40)"
RABBITMQ_PASSWORD="$(set +o pipefail; tr -cd a-zA-Z0-9 </dev/urandom | head -c 40)"
RABBITMQ_ENCRYPTED_PASSWORD="$(@rabbitmq@/bin/rabbitmqctl --quiet encode --cipher blowfish_cfb64 --hash sha256 --iterations 10000 '<<"'"$RABBITMQ_PASSWORD"'">>' "$RABBITMQ_CONFIG_KEY")"

hercules-jwkgen
echo -n $(head -c $[256/8] </dev/urandom | base64) >./storage-encryption.key

echo null | @jq@/bin/jq >hercules-ci-enterprise-keys.json '{
  "smtp": {
    "username": ".....",
    "password": "....."
  },
  "s3": {
    "accessKey": ".....",
    "secretKey": "....."
  },
  "rabbitmq": {
    "password": $rabbitmqPassword,
  },
  "auth": {
    "privateJWK": $privateJWK,
    "publicJWK": $publicJWK
  },
  "storageEncryptionKey": $storageEncryptionKey,
}' \
  --arg rabbitmqPassword "$RABBITMQ_PASSWORD" \
  --rawfile privateJWK ./private-jwk.json \
  --rawfile publicJWK ./public-jwk.json \
  --rawfile storageEncryptionKey ./storage-encryption.key \
  ;


echo $RABBITMQ_CONFIG_KEY >./rabbitmq-config.key

rm storage-encryption.key private-jwk.json public-jwk.json

cat >"configuration-hercules.nix" <<EOF
{ config, lib, pkgs, ... }:
{
  config = {
    services.hercules-backend = {
      # domain = ...;

      # For AWS
      # s3.defaultRegion = ...; # e.g. "us-east-1"
      # For MinIO or other providers (optional)
      # s3.hostOverride = ...;

      # s3.buckets.state = ...; # name of the bucket for state files
      # s3.buckets.logs = ...; # name of the bucket for logs

      # smtp = {
      #   server = ...;
      #   port = ...;
      # };
      # notificationEmailSender = ...; # e.g. "noreply@hercules-ci.example.com"
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
            , $RABBITMQ_ENCRYPTED_PASSWORD
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
EOF
