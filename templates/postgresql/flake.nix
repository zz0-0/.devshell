{
  description = "PostgreSQL project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    devshell.url = "github:zz0-0/devshell";
  };

  outputs =
    {
      self,
      nixpkgs,
      devshell,
    }:
    {
      # Supported systems: x86_64-linux, aarch64-linux
      devShells.x86_64-linux.default = devshell.lib.x86_64-linux.postgresql { };
    };
}
