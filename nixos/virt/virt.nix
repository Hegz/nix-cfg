{ inputs, outputs, config, pkgs, lib, secrets, ... }:
{
  virtualisation.libvirtd = {
    enable = true;
    onShutdown = "shutdown";
    qemu = {
      # vhostUserPackages = [ pkgs.virtiofsd ];
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      swtpm.enable = true;
      ovmf = {
        enable = true;
        packages = [(pkgs.OVMF.override {
          secureBoot = true;
          tpmSupport = true;
        }).fd];
      };
    };
  };
}
