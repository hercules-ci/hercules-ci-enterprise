{ runCommandNoCC, bash, rabbitmq-server, jq, ... }:

runCommandNoCC "hercules-generate-config"
{
  inherit bash jq;
  rabbitmq = rabbitmq-server;
  meta.mainProgram = "hercules-generate-config";
} ''
  mkdir -p $out/bin
  substitute ${./generate-config.sh} $out/bin/hercules-generate-config \
    --replace @bash@ $bash \
    --replace @rabbitmq@ $rabbitmq \
    --replace @jq@ $jq \
    ;
  chmod a+x $out/bin/hercules-generate-config
''
