{ config, lib, ... }: {
  config = {
    services.hercules-web.domain = lib.mkDefault config.services.hercules-backend.domain;
    services.hercules-web.backend = "http://localhost:${toString config.services.hercules-backend.port}";
  };
}
