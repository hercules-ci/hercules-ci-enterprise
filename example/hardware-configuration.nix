{
  nixpkgs.system = "x86_64-linux";
  fileSystems."/".device = "bogus";
  boot.loader.grub.enable = false;
}