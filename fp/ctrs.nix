# SPDX-FileCopyrightText: 2023 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ inputs, perSystem, ... }@top:
let
  lmd = top.self.lastModifiedDate;
  year = builtins.substring 0 4 lmd;
  month = builtins.substring 4 2 lmd;
  day = builtins.substring 6 2 lmd;
  hour = builtins.substring 8 2 lmd;
  minute = builtins.substring 10 2 lmd;
  second = builtins.substring 12 2 lmd;
  created = "${year}-${month}-${day}T${hour}:${minute}:${second}Z";
in
{
  perSystem = { lib, pkgs, ... }:
    let
      ctrs = {
        komga = pkgs.callPackage ../ctrs/komga {
          inherit created;
          komga = pkgs.callPackage "${inputs.unstable}/pkgs/servers/komga" { };
        };
        qbittorrent-nox = pkgs.callPackage ../ctrs/qbittorrent-nox {
          inherit created;
        };
      };

      manifest =
        let
          table = lib.mapAttrsToList
            (n: v: [ n v.imageName v.imageTag ])
            ctrs;
          flat = lib.foldr
            (a: b: a + "\n" + b)
            ""
            (builtins.map (lib.concatStringsSep "\t") table);
        in
        pkgs.writeText "manifest" flat;
    in
    {
      packages = ctrs // { inherit manifest; };
    };
}
