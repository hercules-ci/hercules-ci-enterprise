#!@bash@/bin/bash
set -euo pipefail

oldPwd="$PWD"
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

MINIO_ROOT_USER="root"
MINIO_ROOT_PASSWORD="$(head -c $[256/8] </dev/urandom | base64)"

hercules-jwkgen
echo -n $(head -c $[256/8] </dev/urandom | base64) >./storage-encryption.key

echo null | @jq@/bin/jq >hercules-ci-enterprise-keys.json '{
  "smtp": {
    "username": ".....",
    "password": "....."
  },
  "s3": {
    "accessKey": $minioRootUser,
    "secretKey": $minioRootPassword
  },
  "queuesConfig": {
    "password": $rabbitmqPassword,
  },
  "auth": {
    "privateJWK": $privateJWK,
    "publicJWK": $publicJWK
  },
  "storageEncryptionKey": $storageEncryptionKey,
  "licenseKey": $licenseKey,
}' \
  --arg rabbitmqPassword "$RABBITMQ_PASSWORD" \
  --rawfile privateJWK ./private-jwk.json \
  --rawfile publicJWK ./public-jwk.json \
  --rawfile storageEncryptionKey ./storage-encryption.key \
  --arg licenseKey "$(jq -r <"$oldPwd/tokens.json" .licenseKey)" \
  --arg minioRootPassword "$MINIO_ROOT_PASSWORD" \
  --arg minioRootUser "$MINIO_ROOT_USER" \
  ;


echo $RABBITMQ_CONFIG_KEY >./rabbitmq-config.key

(
  echo "MINIO_ROOT_USER=$MINIO_ROOT_USER"
  echo "MINIO_ROOT_PASSWORD=$MINIO_ROOT_PASSWORD"
) >./minio-rootCredentialsFile.key

rm storage-encryption.key private-jwk.json public-jwk.json

cat >"configuration-hercules.nix" <<EOF
{ config, lib, pkgs, ... }:
{
  config = {

    age.secrets."hercules-ci-keys.json".file =
      ../secrets/hercules-ci/keys.json.age;
    age.secrets."rabbitmq-config.key".file =
      ../secrets/hercules-ci/rabbitmq-config.key.age;
    age.secrets."minio-rootCredentialsFile.key".file =
      ../secrets/hercules-ci/minio-rootCredentialsFile.key.age;

    services.hercules-backend = {
      # domain = ".....";

      # s3.buckets.state = "hercules-ci-state"; # name of the bucket for state files
      # s3.buckets.logs = "hercules-ci-logs"; # name of the bucket for logs
      
      # notificationEmailSender = "notification@......";
      # smtp = {
      #  server = "localhost";
      #  port = 587;
      #};
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
            , [ {passphrase, {file, <<"${config.age.secrets."rabbitmq-config.key".path}">>}}
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
